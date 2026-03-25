-module(dream_http_shim).

-export([request_stream/8, fetch_next/2, fetch_start_headers/2, request_stream_messages/8,
         cancel_stream/1, cancel_stream_by_string/1, receive_stream_message/1,
         decode_stream_message_for_selector/1, normalize_headers/1, request_sync/7,
         configure_transport/1,
         ets_table_exists/1, ets_new/2, ets_insert/7, ets_lookup/2, ets_delete/2]).

-define(REF_MAPPING_TABLE, dream_http_client_ref_mapping).
-define(MAX_REDIRECTS, 5).

%% ============================================================================
%% Synchronous (blocking) request
%% ============================================================================

request_sync(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect) ->
    NHeaders = maybe_add_accept_encoding(to_gun_headers(Headers)),
    request_sync_impl(Method, Url, NHeaders, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect, 0, 1).

request_sync_impl(_Method, _Url, _Headers, _Body, _TimeoutMs, _ConnectTimeoutMs, _AutoRedirect, Redirects, _RetriesLeft) when Redirects >= ?MAX_REDIRECTS ->
    {error, <<"too_many_redirects">>};
request_sync_impl(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect, Redirects, RetriesLeft) ->
    case parse_url(Url) of
        {ok, Scheme, Host, Port, PathQs} ->
            GunOpts = build_gun_opts(ConnectTimeoutMs),
            case get_or_open_connection(Scheme, Host, Port, GunOpts) of
                {ok, ConnPid, _Protocol} ->
                    MethodAtom = to_method_atom(Method),
                    StreamRef = send_request(ConnPid, MethodAtom, PathQs, Headers, Body),
                    case gun:await(ConnPid, StreamRef, TimeoutMs) of
                        {response, fin, Status, RespHeaders} ->
                            NormHeaders = normalize_headers(RespHeaders),
                            handle_sync_response(Status, NormHeaders, <<>>, AutoRedirect, Redirects,
                                                 Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, RespHeaders);
                        {response, nofin, Status, RespHeaders} ->
                            case gun:await_body(ConnPid, StreamRef, TimeoutMs) of
                                {ok, RespBody} ->
                                    {DecompBody, CleanHeaders} = maybe_decompress_response(RespBody, RespHeaders),
                                    NormHeaders = normalize_headers(CleanHeaders),
                                    handle_sync_response(Status, NormHeaders, DecompBody, AutoRedirect, Redirects,
                                                         Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, RespHeaders);
                                {ok, RespBody, _Trailers} ->
                                    {DecompBody, CleanHeaders} = maybe_decompress_response(RespBody, RespHeaders),
                                    NormHeaders = normalize_headers(CleanHeaders),
                                    handle_sync_response(Status, NormHeaders, DecompBody, AutoRedirect, Redirects,
                                                         Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, RespHeaders);
                                {error, timeout} ->
                                    {error, <<"timeout">>};
                                {error, Reason} ->
                                    {error, format_error(Reason)}
                            end;
                        {error, timeout} ->
                            {error, <<"timeout">>};
                        {error, {stream_error, Reason, _HumanReadable}} ->
                            case RetriesLeft > 0 andalso is_stale_connection_error({stream_error, Reason}) of
                                true ->
                                    gun:close(ConnPid),
                                    request_sync_impl(Method, Url, Headers, Body, TimeoutMs,
                                                      ConnectTimeoutMs, AutoRedirect, Redirects, RetriesLeft - 1);
                                false ->
                                    {error, format_error(Reason)}
                            end;
                        {error, Reason} ->
                            case RetriesLeft > 0 andalso is_stale_connection_error(Reason) of
                                true ->
                                    gun:close(ConnPid),
                                    request_sync_impl(Method, Url, Headers, Body, TimeoutMs,
                                                      ConnectTimeoutMs, AutoRedirect, Redirects, RetriesLeft - 1);
                                false ->
                                    {error, format_error(Reason)}
                            end
                    end;
                {error, Reason} ->
                    {error, format_connection_error(Reason)}
            end;
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

handle_sync_response(Status, NormHeaders, DecompBody, AutoRedirect, Redirects,
                     Method, Url, OrigHeaders, OrigBody, TimeoutMs, ConnectTimeoutMs, RawRespHeaders) ->
    case AutoRedirect andalso is_redirect(Status) of
        true ->
            case get_location(RawRespHeaders) of
                {ok, Location} ->
                    ResolvedUrl = resolve_redirect_url(Location, Url),
                    RedirectMethod = redirect_method(Status, Method),
                    RedirectBody = redirect_body(Status, OrigBody),
                    request_sync_impl(RedirectMethod, ResolvedUrl, OrigHeaders, RedirectBody,
                                      TimeoutMs, ConnectTimeoutMs, AutoRedirect, Redirects + 1, 1);
                error ->
                    {ok, {Status, NormHeaders, DecompBody}}
            end;
        false ->
            {ok, {Status, NormHeaders, DecompBody}}
    end.

%% ============================================================================
%% Pull-based streaming
%% ============================================================================

request_stream(Method, Url, Headers, Body, _Receiver, TimeoutMs, ConnectTimeoutMs, AutoRedirect) ->
    NHeaders = maybe_add_accept_encoding(to_gun_headers(Headers)),
    Owner = spawn(fun() ->
        stream_owner_init(Method, Url, NHeaders, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect)
    end),
    {ok, Owner}.

stream_owner_init(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect) ->
    case start_gun_stream(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect, 0) of
        {ok, ConnPid, StreamRef, _Status, RespHeaders} ->
            ZlibCtx = maybe_init_stream_zlib(RespHeaders),
            NormHeaders = normalize_headers(RespHeaders),
            stream_owner_wait(ConnPid, StreamRef, [], NormHeaders, [], ZlibCtx, TimeoutMs);
        {error, Reason} ->
            exit({stream_start_failed, Reason})
    end.

%% Follows redirects, then returns {ok, ConnPid, StreamRef, Status, Headers} for a
%% streaming response (status 2xx), or {error, Reason} for non-2xx / failure.
start_gun_stream(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, _AutoRedirect, Redirects) when Redirects >= ?MAX_REDIRECTS ->
    start_gun_stream_final(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs);
start_gun_stream(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect, Redirects) ->
    case start_gun_stream_final(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs) of
        {ok, ConnPid, StreamRef, Status, RespHeaders} ->
            case AutoRedirect andalso is_redirect(Status) of
                true ->
                    %% Drain the body so the stream is clean
                    drain_stream(ConnPid, StreamRef),
                    case get_location(RespHeaders) of
                        {ok, Location} ->
                            ResolvedUrl = resolve_redirect_url(Location, Url),
                            RedirectMethod = redirect_method(Status, Method),
                            RedirectBody = redirect_body(Status, Body),
                            start_gun_stream(RedirectMethod, ResolvedUrl, Headers, RedirectBody,
                                             TimeoutMs, ConnectTimeoutMs, AutoRedirect, Redirects + 1);
                        error ->
                            {ok, ConnPid, StreamRef, Status, RespHeaders}
                    end;
                false ->
                    case Status >= 200 andalso Status < 300 of
                        true ->
                            {ok, ConnPid, StreamRef, Status, RespHeaders};
                        false ->
                            FullBody = collect_body(ConnPid, StreamRef, TimeoutMs),
                            StatusBin = integer_to_binary(Status),
                            ReasonPhrase = status_reason(Status),
                            SafeBody = ensure_utf8_binary(FullBody),
                            ErrorMsg = <<"HTTP ", StatusBin/binary, " ", ReasonPhrase/binary, ": ", SafeBody/binary>>,
                            {error, ErrorMsg}
                    end
            end;
        {error, Reason} ->
            {error, Reason}
    end.

start_gun_stream_final(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs) ->
    start_gun_stream_final(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, 1).

start_gun_stream_final(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, RetriesLeft) ->
    case parse_url(Url) of
        {ok, Scheme, Host, Port, PathQs} ->
            GunOpts = build_gun_opts(ConnectTimeoutMs),
            case get_or_open_connection(Scheme, Host, Port, GunOpts) of
                {ok, ConnPid, _Protocol} ->
                    MethodAtom = to_method_atom(Method),
                    StreamRef = send_request(ConnPid, MethodAtom, PathQs, Headers, Body),
                    case gun:await(ConnPid, StreamRef, TimeoutMs) of
                        {response, fin, Status, RespHeaders} ->
                            {ok, ConnPid, StreamRef, Status, RespHeaders};
                        {response, nofin, Status, RespHeaders} ->
                            {ok, ConnPid, StreamRef, Status, RespHeaders};
                        {error, timeout} ->
                            {error, <<"timeout">>};
                        {error, Reason} ->
                            case RetriesLeft > 0 andalso is_stale_connection_error(Reason) of
                                true ->
                                    gun:close(ConnPid),
                                    start_gun_stream_final(Method, Url, Headers, Body,
                                                           TimeoutMs, ConnectTimeoutMs, RetriesLeft - 1);
                                false ->
                                    {error, format_error(Reason)}
                            end
                    end;
                {error, Reason} ->
                    {error, format_connection_error(Reason)}
            end;
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

drain_stream(ConnPid, StreamRef) ->
    case gun:await_body(ConnPid, StreamRef, 5000) of
        {ok, _Body} -> ok;
        {ok, _Body, _Trailers} -> ok;
        _ -> ok
    end.

collect_body(ConnPid, StreamRef, Timeout) ->
    case gun:await_body(ConnPid, StreamRef, Timeout) of
        {ok, Body} -> Body;
        {ok, Body, _Trailers} -> Body;
        _ -> <<>>
    end.

%% Stream owner loop: services fetch_next requests using gun messages
stream_owner_wait(ConnPid, StreamRef, Buffer, StartHeaders, StartWaiters, ZlibCtx, TimeoutMs) ->
    receive
        {fetch_next, From} ->
            handle_fetch_next(From, ConnPid, StreamRef, Buffer, StartHeaders, StartWaiters, ZlibCtx, TimeoutMs);
        {fetch_start_headers, From} ->
            case StartHeaders of
                undefined ->
                    stream_owner_wait(ConnPid, StreamRef, Buffer, StartHeaders, [From | StartWaiters], ZlibCtx, TimeoutMs);
                _ ->
                    From ! {stream_start_headers, normalize_headers_default(StartHeaders)},
                    stream_owner_wait(ConnPid, StreamRef, Buffer, StartHeaders, StartWaiters, ZlibCtx, TimeoutMs)
            end;
        {gun_data, ConnPid, StreamRef, nofin, Data} ->
            DecompData = case ZlibCtx of
                undefined -> Data;
                _ -> decompress_chunk(ZlibCtx, Data)
            end,
            stream_owner_wait(ConnPid, StreamRef, Buffer ++ [{chunk, DecompData}], StartHeaders, StartWaiters, ZlibCtx, TimeoutMs);
        {gun_data, ConnPid, StreamRef, fin, Data} ->
            DecompData = case ZlibCtx of
                undefined -> Data;
                _ -> decompress_chunk(ZlibCtx, Data)
            end,
            cleanup_zlib(ZlibCtx),
            FinalBuffer = case byte_size(DecompData) > 0 of
                true -> Buffer ++ [{chunk, DecompData}, {finished, []}];
                false -> Buffer ++ [{finished, []}]
            end,
            stream_owner_wait(ConnPid, StreamRef, FinalBuffer, StartHeaders, StartWaiters, undefined, TimeoutMs);
        {gun_trailers, ConnPid, StreamRef, Trailers} ->
            cleanup_zlib(ZlibCtx),
            stream_owner_wait(ConnPid, StreamRef, Buffer ++ [{finished, normalize_headers(Trailers)}],
                              StartHeaders, StartWaiters, undefined, TimeoutMs);
        {gun_error, ConnPid, StreamRef, Reason} ->
            cleanup_zlib(ZlibCtx),
            stream_owner_wait(ConnPid, StreamRef, Buffer ++ [{error, format_error(Reason)}],
                              StartHeaders, StartWaiters, undefined, TimeoutMs);
        {gun_error, ConnPid, Reason} ->
            cleanup_zlib(ZlibCtx),
            stream_owner_wait(ConnPid, StreamRef, Buffer ++ [{error, format_error(Reason)}],
                              StartHeaders, StartWaiters, undefined, TimeoutMs);
        _Other ->
            stream_owner_wait(ConnPid, StreamRef, Buffer, StartHeaders, StartWaiters, ZlibCtx, TimeoutMs)
    end.

handle_fetch_next(From, ConnPid, StreamRef, [], StartHeaders, StartWaiters, ZlibCtx, TimeoutMs) ->
    %% Buffer empty — wait for next gun message
    receive
        {gun_data, ConnPid, StreamRef, nofin, Data} ->
            DecompData = case ZlibCtx of
                undefined -> Data;
                _ -> decompress_chunk(ZlibCtx, Data)
            end,
            From ! {stream_chunk, DecompData},
            stream_owner_wait(ConnPid, StreamRef, [], StartHeaders, StartWaiters, ZlibCtx, TimeoutMs);
        {gun_data, ConnPid, StreamRef, fin, Data} ->
            DecompData = case ZlibCtx of
                undefined -> Data;
                _ -> decompress_chunk(ZlibCtx, Data)
            end,
            cleanup_zlib(ZlibCtx),
            case byte_size(DecompData) > 0 of
                true ->
                    From ! {stream_chunk, DecompData},
                    stream_owner_wait(ConnPid, StreamRef, [{finished, []}], StartHeaders, StartWaiters, undefined, TimeoutMs);
                false ->
                    From ! {stream_end, []},
                    ok
            end;
        {gun_trailers, ConnPid, StreamRef, Trailers} ->
            cleanup_zlib(ZlibCtx),
            From ! {stream_end, normalize_headers(Trailers)},
            ok;
        {gun_error, ConnPid, StreamRef, Reason} ->
            cleanup_zlib(ZlibCtx),
            From ! {stream_error, format_error(Reason)},
            ok;
        {gun_error, ConnPid, Reason} ->
            cleanup_zlib(ZlibCtx),
            From ! {stream_error, format_error(Reason)},
            ok
    after TimeoutMs ->
        From ! {stream_error, timeout},
        stream_owner_wait(ConnPid, StreamRef, [], StartHeaders, StartWaiters, ZlibCtx, TimeoutMs)
    end;
handle_fetch_next(From, ConnPid, StreamRef, [Item | Rest], StartHeaders, StartWaiters, ZlibCtx, TimeoutMs) ->
    deliver_message(From, Item),
    case Item of
        {finished, _} -> ok;
        {error, _} -> ok;
        _ -> stream_owner_wait(ConnPid, StreamRef, Rest, StartHeaders, StartWaiters, ZlibCtx, TimeoutMs)
    end.

deliver_message(From, {chunk, Bin}) ->
    From ! {stream_chunk, Bin};
deliver_message(From, {finished, Headers}) ->
    From ! {stream_end, Headers};
deliver_message(From, {error, Reason}) ->
    From ! {stream_error, Reason}.

fetch_next(OwnerPid, TimeoutMs) ->
    MonitorRef = erlang:monitor(process, OwnerPid),
    OwnerPid ! {fetch_next, self()},
    receive
        {stream_chunk, Bin} ->
            erlang:demonitor(MonitorRef, [flush]),
            {chunk, Bin};
        {stream_end, Headers} ->
            erlang:demonitor(MonitorRef, [flush]),
            {finished, Headers};
        {stream_error, Reason} ->
            erlang:demonitor(MonitorRef, [flush]),
            {error, Reason};
        {'DOWN', MonitorRef, process, OwnerPid, Reason} ->
            {error, format_exit_reason(Reason)}
    after TimeoutMs ->
        erlang:demonitor(MonitorRef, [flush]),
        {error, timeout}
    end.

fetch_start_headers(OwnerPid, TimeoutMs) ->
    MonitorRef = erlang:monitor(process, OwnerPid),
    OwnerPid ! {fetch_start_headers, self()},
    receive
        {stream_start_headers, Headers} ->
            erlang:demonitor(MonitorRef, [flush]),
            {ok, Headers};
        {'DOWN', MonitorRef, process, OwnerPid, Reason} ->
            {error, format_exit_reason(Reason)}
    after TimeoutMs ->
        erlang:demonitor(MonitorRef, [flush]),
        {error, timeout}
    end.

normalize_headers_default(undefined) -> [];
normalize_headers_default(Headers) -> Headers.

%% ============================================================================
%% Message-based streaming
%% ============================================================================

request_stream_messages(Method, Url, Headers, Body, _ReceiverPid, TimeoutMs,
                        ConnectTimeoutMs, AutoRedirect) ->
    NHeaders = maybe_add_accept_encoding(to_gun_headers(Headers)),
    CallerPid = self(),
    TranslatorPid = spawn(fun() ->
        translator_init(Method, Url, NHeaders, Body, CallerPid, TimeoutMs, ConnectTimeoutMs, AutoRedirect)
    end),
    %% Generate a unique string ID for this stream
    StringId = translator_ref_to_string(TranslatorPid),
    store_ref_mapping(StringId, TranslatorPid),
    {ok, StringId}.

translator_init(Method, Url, Headers, Body, CallerPid, TimeoutMs, ConnectTimeoutMs, AutoRedirect) ->
    case start_gun_stream(Method, Url, Headers, Body, TimeoutMs, ConnectTimeoutMs, AutoRedirect, 0) of
        {ok, ConnPid, StreamRef, _Status, RespHeaders} ->
            StringId = get_my_string_id(),
            %% Store ConnPid and StreamRef for cancellation
            store_cancel_info(StringId, ConnPid, StreamRef),
            NormHeaders = normalize_headers(RespHeaders),
            CallerPid ! {http, {StringId, stream_start, NormHeaders}},
            ZlibCtx = maybe_init_stream_zlib(RespHeaders),
            translator_loop(ConnPid, StreamRef, CallerPid, StringId, ZlibCtx, TimeoutMs);
        {error, Reason} ->
            StringId = get_my_string_id(),
            CallerPid ! {http, {StringId, {error, Reason}}},
            ok
    end.

translator_loop(ConnPid, StreamRef, CallerPid, StringId, ZlibCtx, TimeoutMs) ->
    receive
        {gun_data, ConnPid, StreamRef, nofin, Data} ->
            DecompData = case ZlibCtx of
                undefined -> Data;
                _ -> decompress_chunk(ZlibCtx, Data)
            end,
            CallerPid ! {http, {StringId, stream, DecompData}},
            translator_loop(ConnPid, StreamRef, CallerPid, StringId, ZlibCtx, TimeoutMs);
        {gun_data, ConnPid, StreamRef, fin, Data} ->
            case byte_size(Data) > 0 of
                true ->
                    DecompData = case ZlibCtx of
                        undefined -> Data;
                        _ -> decompress_chunk(ZlibCtx, Data)
                    end,
                    CallerPid ! {http, {StringId, stream, DecompData}};
                false -> ok
            end,
            cleanup_zlib(ZlibCtx),
            CallerPid ! {http, {StringId, stream_end, []}},
            ok;
        {gun_trailers, ConnPid, StreamRef, Trailers} ->
            cleanup_zlib(ZlibCtx),
            CallerPid ! {http, {StringId, stream_end, normalize_headers(Trailers)}},
            ok;
        {gun_error, ConnPid, StreamRef, Reason} ->
            cleanup_zlib(ZlibCtx),
            CallerPid ! {http, {StringId, {error, format_error(Reason)}}},
            ok;
        {gun_error, ConnPid, Reason} ->
            cleanup_zlib(ZlibCtx),
            CallerPid ! {http, {StringId, {error, format_error(Reason)}}},
            ok;
        cancel ->
            cleanup_zlib(ZlibCtx),
            gun:cancel(ConnPid, StreamRef),
            ok;
        _Other ->
            translator_loop(ConnPid, StreamRef, CallerPid, StringId, ZlibCtx, TimeoutMs)
    after TimeoutMs ->
        cleanup_zlib(ZlibCtx),
        CallerPid ! {http, {StringId, {error, <<"timeout">>}}},
        ok
    end.

get_my_string_id() ->
    translator_ref_to_string(self()).

translator_ref_to_string(Pid) ->
    ensure_utf8_binary(io_lib:format("~p", [Pid])).

store_cancel_info(StringId, ConnPid, StreamRef) ->
    ets:insert(?REF_MAPPING_TABLE, {{cancel, StringId}, {ConnPid, StreamRef}}).

%% ============================================================================
%% Cancellation
%% ============================================================================

cancel_stream(RequestId) ->
    case ets:lookup(?REF_MAPPING_TABLE, {cancel, RequestId}) of
        [{{cancel, _}, {ConnPid, StreamRef}}] ->
            gun:cancel(ConnPid, StreamRef),
            ok;
        [] ->
            ok
    end.

cancel_stream_by_string(StringId) ->
    case lookup_ref_by_string(StringId) of
        {some, TranslatorPid} when is_pid(TranslatorPid) ->
            TranslatorPid ! cancel,
            remove_ref_mapping(StringId),
            nil;
        _ ->
            %% Try direct cancel via stored info
            case ets:lookup(?REF_MAPPING_TABLE, {cancel, StringId}) of
                [{{cancel, _}, {ConnPid, StreamRef}}] ->
                    gun:cancel(ConnPid, StreamRef),
                    ets:delete(?REF_MAPPING_TABLE, {cancel, StringId}),
                    remove_ref_mapping(StringId),
                    nil;
                [] ->
                    nil
            end
    end.

%% ============================================================================
%% Message decoding for selectors
%% ============================================================================

receive_stream_message(TimeoutMs) ->
    receive
        {http, {StringId, stream_start, Headers}} ->
            {stream_start, StringId, Headers};
        {http, {StringId, stream, Data}} ->
            {chunk, StringId, Data};
        {http, {StringId, stream_end, Headers}} ->
            {stream_end, StringId, Headers};
        {http, {StringId, {error, Reason}}} ->
            {stream_error, StringId, ensure_binary(Reason)}
    after TimeoutMs ->
        timeout
    end.

decode_stream_message_for_selector({http, InnerMessage}) ->
    case InnerMessage of
        {StringId, stream_start, Headers} ->
            {stream_start, StringId, Headers};
        {StringId, stream, Data} ->
            {chunk, StringId, Data};
        {StringId, stream_end, Headers} ->
            remove_ref_mapping(StringId),
            {stream_end, StringId, Headers};
        {StringId, {error, Reason}} ->
            remove_ref_mapping(StringId),
            {stream_error, StringId, ensure_binary(Reason)};
        _ ->
            error(badarg)
    end.

ensure_binary(Bin) when is_binary(Bin) -> Bin;
ensure_binary(Other) -> ensure_utf8_binary(io_lib:format("~p", [Other])).

%% ============================================================================
%% Header normalization
%% ============================================================================

normalize_headers(Headers) when is_list(Headers) ->
    lists:map(fun normalize_header_tuple/1, Headers);
normalize_headers(_) ->
    [].

normalize_header_tuple({Name, Value}) ->
    {to_binary(Name), to_binary(Value)};
normalize_header_tuple(_) ->
    {<<"">>, <<"">>}.

%% ============================================================================
%% Transport configuration
%% ============================================================================

configure_transport(Config) ->
    %% Config is a Gleam opaque type = Erlang tuple {transport_config, F1, F2, ...}
    ets:insert(dream_http_client_transport_config, {config, Config}),
    nil.

get_transport_config() ->
    case ets:lookup(dream_http_client_transport_config, config) of
        [{config, Config}] ->
            %% Gleam TransportConfig tuple: {transport_config, MaxConn, IdleTimeout, DefaultConnTimeout,
            %%   DomainLookupTimeout, TlsHandshakeTimeout, Retry, RetryTimeout, Keepalive,
            %%   KeepaliveTolerance, MaxConcurrentStreams, InitConnWindowSize, InitStreamWindowSize,
            %%   ClosingTimeout}
            #{max_connections => element(2, Config),
              idle_timeout => element(3, Config),
              connect_timeout => element(4, Config),
              domain_lookup_timeout => element(5, Config),
              tls_handshake_timeout => element(6, Config),
              retry => element(7, Config),
              retry_timeout => element(8, Config),
              keepalive => element(9, Config),
              keepalive_tolerance => element(10, Config),
              max_concurrent_streams => element(11, Config),
              initial_connection_window_size => element(12, Config),
              initial_stream_window_size => element(13, Config),
              closing_timeout => element(14, Config)};
        [] ->
            #{max_connections => 50,
              idle_timeout => 60000,
              connect_timeout => 15000,
              domain_lookup_timeout => 5000,
              tls_handshake_timeout => 10000,
              retry => 3,
              retry_timeout => 1000,
              keepalive => 30000,
              keepalive_tolerance => 3,
              max_concurrent_streams => 100,
              initial_connection_window_size => 65535,
              initial_stream_window_size => 65535,
              closing_timeout => 15000}
    end.

%% ============================================================================
%% Connection management helpers
%% ============================================================================

get_or_open_connection(Scheme, Host, Port, GunOpts) ->
    TransportConfig = get_transport_config(),
    FullOpts = maps:merge(TransportConfig, GunOpts),
    dream_http_conn_manager:ensure_connection(Scheme, Host, Port, FullOpts).

build_gun_opts(ConnectTimeoutMs) ->
    #{connect_timeout => ConnectTimeoutMs}.

send_request(ConnPid, Method, PathQs, Headers, Body) when Body =:= <<>>; Body =:= undefined ->
    gun:Method(ConnPid, PathQs, Headers);
send_request(ConnPid, Method, PathQs, Headers, Body) ->
    gun:Method(ConnPid, PathQs, Headers, Body).

%% ============================================================================
%% URL parsing
%% ============================================================================

parse_url(Url) when is_binary(Url) ->
    parse_url(binary_to_list(Url));
parse_url(Url) when is_list(Url) ->
    case uri_string:parse(Url) of
        #{scheme := SchemeStr, host := Host} = Parsed ->
            Scheme = case SchemeStr of
                "https" -> https;
                "http" -> http;
                <<"https">> -> https;
                <<"http">> -> http;
                _ -> http
            end,
            Port = case maps:get(port, Parsed, undefined) of
                undefined ->
                    case Scheme of
                        https -> 443;
                        http -> 80
                    end;
                P -> P
            end,
            Path = case maps:get(path, Parsed, "/") of
                "" -> "/";
                <<>> -> "/";
                P2 -> to_list(P2)
            end,
            Query = case maps:get(query, Parsed, undefined) of
                undefined -> "";
                Q -> to_list(Q)
            end,
            PathQs = case Query of
                "" -> Path;
                _ -> Path ++ "?" ++ Query
            end,
            HostStr = to_list(Host),
            {ok, Scheme, HostStr, Port, to_binary(PathQs)};
        {error, Reason, _} ->
            {error, Reason};
        _ ->
            {error, invalid_url}
    end.

%% ============================================================================
%% Redirect helpers
%% ============================================================================

is_redirect(301) -> true;
is_redirect(302) -> true;
is_redirect(303) -> true;
is_redirect(307) -> true;
is_redirect(308) -> true;
is_redirect(_) -> false.

get_location(Headers) ->
    case lists:keyfind(<<"location">>, 1, Headers) of
        {_, Location} -> {ok, Location};
        false ->
            %% Try case-insensitive
            Result = lists:foldl(fun({K, V}, Acc) ->
                case Acc of
                    error ->
                        case string:lowercase(to_list(K)) of
                            "location" -> {ok, V};
                            _ -> error
                        end;
                    Found -> Found
                end
            end, error, Headers),
            Result
    end.

redirect_method(303, _) -> <<"GET">>;
redirect_method(301, _) -> <<"GET">>;
redirect_method(302, _) -> <<"GET">>;
redirect_method(_, Method) -> Method.

redirect_body(303, _) -> <<>>;
redirect_body(301, _) -> <<>>;
redirect_body(302, _) -> <<>>;
redirect_body(_, Body) -> Body.

resolve_redirect_url(Location, OriginalUrl) ->
    LocStr = to_list(Location),
    case uri_string:parse(LocStr) of
        #{scheme := _} ->
            Location;
        _ ->
            OrigStr = to_list(OriginalUrl),
            case uri_string:parse(OrigStr) of
                #{scheme := S, host := H} = Parsed ->
                    Port = maps:get(port, Parsed, undefined),
                    Base = case Port of
                        undefined -> io_lib:format("~s://~s", [S, H]);
                        _ -> io_lib:format("~s://~s:~B", [S, H, Port])
                    end,
                    iolist_to_binary([Base, LocStr]);
                _ ->
                    Location
            end
    end.

status_reason(200) -> <<"OK">>;
status_reason(201) -> <<"Created">>;
status_reason(204) -> <<"No Content">>;
status_reason(301) -> <<"Moved Permanently">>;
status_reason(302) -> <<"Found">>;
status_reason(303) -> <<"See Other">>;
status_reason(307) -> <<"Temporary Redirect">>;
status_reason(308) -> <<"Permanent Redirect">>;
status_reason(400) -> <<"Bad Request">>;
status_reason(401) -> <<"Unauthorized">>;
status_reason(403) -> <<"Forbidden">>;
status_reason(404) -> <<"Not Found">>;
status_reason(422) -> <<"Unprocessable Entity">>;
status_reason(429) -> <<"Too Many Requests">>;
status_reason(500) -> <<"Internal Server Error">>;
status_reason(502) -> <<"Bad Gateway">>;
status_reason(503) -> <<"Service Unavailable">>;
status_reason(_) -> <<"Unknown">>.

%% ============================================================================
%% Method conversion
%% ============================================================================

to_method_atom(Method) when is_atom(Method) -> Method;
to_method_atom(Method) when is_binary(Method) ->
    case string:lowercase(binary_to_list(Method)) of
        "get" -> get;
        "post" -> post;
        "put" -> put;
        "delete" -> delete;
        "patch" -> patch;
        "head" -> head;
        "options" -> options;
        Other -> list_to_atom(Other)
    end.

%% ============================================================================
%% Header conversion
%% ============================================================================

to_gun_headers(Hs) when is_list(Hs) ->
    lists:map(fun({K, V}) -> {to_binary(K), to_binary(V)} end, Hs);
to_gun_headers(Other) ->
    Other.

maybe_add_accept_encoding(Headers) ->
    HasAcceptEncoding = lists:any(
        fun({K, _V}) ->
            string:lowercase(binary_to_list(K)) =:= "accept-encoding"
        end, Headers),
    case HasAcceptEncoding of
        true -> Headers;
        false -> Headers ++ [{<<"accept-encoding">>, <<"gzip, deflate">>}]
    end.

%% ============================================================================
%% Decompression
%% ============================================================================

get_content_encoding(Headers) ->
    Val = lists:foldl(
        fun({K, V}, Acc) ->
            case string:lowercase(to_list(K)) of
                "content-encoding" -> string:trim(string:lowercase(to_list(V)));
                _ -> Acc
            end
        end, "", Headers),
    Val.

remove_header(Name, Headers) ->
    NormName = string:lowercase(to_list(Name)),
    lists:filter(
        fun({K, _V}) -> string:lowercase(to_list(K)) =/= NormName end,
        Headers).

maybe_decompress_response(Body, Headers) ->
    Encoding = get_content_encoding(Headers),
    case Encoding of
        "gzip" ->
            try_decompress(fun() -> zlib:gunzip(iolist_to_binary(Body)) end,
                           Body, Headers);
        "deflate" ->
            try_decompress(fun() -> zlib:uncompress(iolist_to_binary(Body)) end,
                           Body, Headers);
        "identity" -> {Body, Headers};
        "" -> {Body, Headers};
        Other ->
            io:format("WARNING: unrecognized Content-Encoding, passing through raw bytes: ~s~n",
                      [to_binary(Other)]),
            {Body, Headers}
    end.

try_decompress(DecompressFn, OrigBody, Headers) ->
    try
        Decompressed = DecompressFn(),
        {Decompressed, remove_header("content-encoding", Headers)}
    catch
        _:_ ->
            io:format("WARNING: decompression failed, passing through raw bytes~n"),
            {OrigBody, Headers}
    end.

detect_stream_encoding(Headers) ->
    Encoding = get_content_encoding(Headers),
    case Encoding of
        "gzip" -> {gzip, 31};
        "deflate" -> {deflate, 15};
        "" -> none;
        "identity" -> none;
        Other ->
            io:format("WARNING: unrecognized Content-Encoding for stream, passing through raw bytes: ~s~n",
                      [to_binary(Other)]),
            none
    end.

init_zlib_context(WindowBits) ->
    Z = zlib:open(),
    ok = zlib:inflateInit(Z, WindowBits),
    Z.

maybe_init_stream_zlib(Headers) ->
    case detect_stream_encoding(Headers) of
        {_Enc, WindowBits} -> init_zlib_context(WindowBits);
        none -> undefined
    end.

decompress_chunk(ZlibCtx, Chunk) ->
    iolist_to_binary(zlib:inflate(ZlibCtx, Chunk)).

cleanup_zlib(undefined) -> ok;
cleanup_zlib(ZlibCtx) ->
    try zlib:inflateEnd(ZlibCtx) catch _:_ -> ok end,
    try zlib:close(ZlibCtx) catch _:_ -> ok end,
    ok.

%% ============================================================================
%% Stale connection detection
%% ============================================================================

is_stale_connection_error({stream_error, closed}) -> true;
is_stale_connection_error({stream_error, {goaway, _, _, _}}) -> true;
is_stale_connection_error({closed, _}) -> true;
is_stale_connection_error(closed) -> true;
is_stale_connection_error(_) -> false.

%% ============================================================================
%% Error formatting
%% ============================================================================

format_error(Reason) ->
    ensure_utf8_binary(io_lib:format("~p", [Reason])).

format_connection_error(econnrefused) -> <<"econnrefused">>;
format_connection_error(connect_timeout) -> <<"connect_timeout">>;
format_connection_error(timeout) -> <<"connect_timeout">>;
format_connection_error(nxdomain) -> <<"nxdomain">>;
format_connection_error(Reason) ->
    ensure_utf8_binary(io_lib:format("~p", [Reason])).

format_exit_reason({stream_start_failed, Error}) ->
    ensure_binary(Error);
format_exit_reason(normal) ->
    <<"Stream process exited normally">>;
format_exit_reason(Reason) ->
    ensure_utf8_binary(io_lib:format("Stream process died: ~p", [Reason])).

%% ============================================================================
%% Binary/string conversion
%% ============================================================================

to_binary(Bin) when is_binary(Bin) -> Bin;
to_binary(List) when is_list(List) ->
    unicode:characters_to_binary(List);
to_binary(Other) ->
    ensure_utf8_binary(io_lib:format("~p", [Other])).

to_list(S) when is_binary(S) -> unicode:characters_to_list(S);
to_list(S) when is_list(S) -> S;
to_list(Other) -> io_lib:format("~p", [Other]).

ensure_utf8_binary(Bin) when is_binary(Bin) ->
    case unicode:characters_to_binary(Bin, utf8, utf8) of
        Result when is_binary(Result) -> Result;
        _ ->
            case unicode:characters_to_binary(Bin, latin1, utf8) of
                Result2 when is_binary(Result2) -> Result2;
                _ -> iolist_to_binary(io_lib:format("~w", [Bin]))
            end
    end;
ensure_utf8_binary(List) when is_list(List) ->
    case unicode:characters_to_binary(List) of
        Result when is_binary(Result) -> Result;
        _ -> iolist_to_binary(io_lib:format("~w", [List]))
    end;
ensure_utf8_binary(Other) ->
    iolist_to_binary(io_lib:format("~w", [Other])).

%% ============================================================================
%% ETS Functions
%% ============================================================================

ets_table_exists(Name) ->
    try
        NameAtom = binary_to_atom(Name, utf8),
        case ets:info(NameAtom) of
            undefined -> false;
            _ -> true
        end
    catch
        error:badarg -> false
    end.

ets_new(Name, Options) ->
    NameAtom = binary_to_atom(Name, utf8),
    ets:new(NameAtom, Options).

ets_insert(TableName, Key, Recorder, RecordedRequest, Headers, Chunks, LastChunkTime) ->
    TableAtom = binary_to_atom(TableName, utf8),
    Value = {Recorder, RecordedRequest, Headers, Chunks, LastChunkTime},
    ets:insert(TableAtom, {Key, Value}),
    nil.

ets_lookup(TableName, Key) ->
    try
        TableAtom = binary_to_atom(TableName, utf8),
        case ets:lookup(TableAtom, Key) of
            [{Key, {Recorder, RecordedRequest, Headers, Chunks, LastChunkTime}}] ->
                State = {message_stream_recorder_state,
                         Recorder, RecordedRequest, Headers, Chunks, LastChunkTime},
                {some, State};
            [] -> none
        end
    catch
        error:badarg -> none
    end.

ets_delete(TableName, Key) ->
    try
        TableAtom = binary_to_atom(TableName, utf8),
        ets:delete(TableAtom, Key)
    catch
        error:badarg -> false
    end.

%% ============================================================================
%% Request ID Mapping
%% ============================================================================

store_ref_mapping(StringId, Ref) ->
    ets:insert(?REF_MAPPING_TABLE, {StringId, Ref}),
    ets:insert(?REF_MAPPING_TABLE, {Ref, StringId}),
    ok.

lookup_ref_by_string(StringId) ->
    case ets:lookup(?REF_MAPPING_TABLE, StringId) of
        [{StringId, Ref}] -> {some, Ref};
        [] -> none
    end.

remove_ref_mapping(StringId) ->
    case lookup_ref_by_string(StringId) of
        {some, Ref} ->
            ets:delete(?REF_MAPPING_TABLE, StringId),
            ets:delete(?REF_MAPPING_TABLE, Ref),
            ets:delete(?REF_MAPPING_TABLE, {cancel, StringId}),
            ok;
        none ->
            ok
    end.

