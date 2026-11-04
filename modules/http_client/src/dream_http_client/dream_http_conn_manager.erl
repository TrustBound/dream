-module(dream_http_conn_manager).
-behaviour(gen_server).

-export([start_link/0, get_connection/4, ensure_connection/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, dream_http_client_connections).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Hot path: lock-free ETS lookup with round-robin selection.
%% Returns {ok, ConnPid, Protocol} | none.
get_connection(Scheme, Host, Port, Protocols) ->
    case ets:lookup(?TABLE, {Scheme, Host, Port, Protocols}) of
        [] ->
            none;
        Entries ->
            Len = length(Entries),
            Idx = erlang:unique_integer([monotonic, positive]) rem Len,
            {_Key, ConnPid, _MonRef, Protocol, _LastUsed} = lists:nth(Idx + 1, Entries),
            case erlang:is_process_alive(ConnPid) of
                true ->
                    touch(ConnPid),
                    {ok, ConnPid, Protocol};
                false ->
                    %% Dead connection — try the others
                    Alive = [E || {_, Pid, _, _, _} = E <- Entries, erlang:is_process_alive(Pid)],
                    case Alive of
                        [] -> none;
                        _ ->
                            Idx2 = erlang:unique_integer([monotonic, positive]) rem length(Alive),
                            {_, Pid2, _, Proto2, _} = lists:nth(Idx2 + 1, Alive),
                            touch(Pid2),
                            {ok, Pid2, Proto2}
                    end
            end
    end.

%% Cold path: create or reuse a connection via the gen_server.
ensure_connection(Scheme, Host, Port, GunOpts) ->
    gen_server:call(?MODULE, {ensure_connection, Scheme, Host, Port, GunOpts}, 30000).

%% Update LastUsed for a connection entry.
%% bag tables don't support select_replace, so we delete+insert.
touch(ConnPid) ->
    Now = erlang:monotonic_time(millisecond),
    case ets:match_object(?TABLE, {'_', ConnPid, '_', '_', '_'}) of
        [{Key, _, MonRef, Protocol, _OldLastUsed}] ->
            ets:match_delete(?TABLE, {'_', ConnPid, '_', '_', '_'}),
            ets:insert(?TABLE, {Key, ConnPid, MonRef, Protocol, Now});
        [_ | _] = Entries ->
            ets:match_delete(?TABLE, {'_', ConnPid, '_', '_', '_'}),
            lists:foreach(fun({Key, _, MonRef, Protocol, _}) ->
                ets:insert(?TABLE, {Key, ConnPid, MonRef, Protocol, Now})
            end, Entries);
        [] ->
            ok
    end.

%% ============================================================================
%% gen_server callbacks
%% ============================================================================

init([]) ->
    %% Crash recovery: scan ETS for leftover entries from previous incarnation
    recover_connections(),
    schedule_idle_check(),
    {ok, #{}}.

handle_call({ensure_connection, Scheme, Host, Port, GunOpts}, _From, State) ->
    Transport = case Scheme of
        https -> tls;
        _ -> tcp
    end,
    Protocols = resolve_protocols(GunOpts, Transport),
    ResolvedOpts = GunOpts#{protocols => Protocols},
    Key = {Scheme, Host, Port, Protocols},
    Existing = ets:lookup(?TABLE, Key),
    %% Clean up dead connections first
    Alive = [E || {_, Pid, _, _, _} = E <- Existing, erlang:is_process_alive(Pid)],
    Dead = length(Existing) - length(Alive),
    case Dead > 0 of
        true ->
            lists:foreach(fun({_, Pid, _, _, _}) ->
                case erlang:is_process_alive(Pid) of
                    false -> ets:match_delete(?TABLE, {'_', Pid, '_', '_', '_'});
                    true -> ok
                end
            end, Existing);
        false -> ok
    end,
    MaxConns = maps:get(max_connections, GunOpts, 50),
    AliveCount = length(Alive),
    case AliveCount < MaxConns of
        true ->
            case open_connection(Scheme, Host, Port, ResolvedOpts) of
                {ok, ConnPid, Protocol} ->
                    MonRef = erlang:monitor(process, ConnPid),
                    Now = erlang:monotonic_time(millisecond),
                    ets:insert(?TABLE, {Key, ConnPid, MonRef, Protocol, Now}),
                    {reply, {ok, ConnPid, Protocol}, State};
                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;
        false ->
            %% At max — round-robin an existing one
            Idx = erlang:unique_integer([monotonic, positive]) rem AliveCount,
            {_, Pid, _, Proto, _} = lists:nth(Idx + 1, Alive),
            touch(Pid),
            {reply, {ok, Pid, Proto}, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', _MonRef, process, ConnPid, _Reason}, State) ->
    ets:match_delete(?TABLE, {'_', ConnPid, '_', '_', '_'}),
    {noreply, State};

handle_info(check_idle, State) ->
    reap_idle_connections(),
    schedule_idle_check(),
    {noreply, State};

handle_info({gun_up, _ConnPid, _Protocol}, State) ->
    {noreply, State};

handle_info({gun_down, ConnPid, Protocol, Reason, KilledStreams}, State) ->
    Killed = length(KilledStreams),
    log_gun_down(ConnPid, Protocol, Reason, Killed, 0),
    {noreply, State};

handle_info({gun_down, ConnPid, Protocol, Reason, KilledStreams, UnprocessedStreams}, State) ->
    Killed = length(KilledStreams),
    Unprocessed = length(UnprocessedStreams),
    log_gun_down(ConnPid, Protocol, Reason, Killed, Unprocessed),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% ============================================================================
%% Internal
%% ============================================================================

open_connection(Scheme, Host, Port, GunOpts) ->
    Transport = case Scheme of
        https -> tls;
        _ -> tcp
    end,
    ConnectTimeout = maps:get(connect_timeout, GunOpts, 15000),
    HostStr = case is_binary(Host) of
        true -> binary_to_list(Host);
        false -> Host
    end,
    Protocols = maps:get(protocols, GunOpts, case Transport of
        tls -> [http2, http];
        tcp -> [http]
    end),
    BaseOpts = #{
        transport => Transport,
        connect_timeout => ConnectTimeout,
        protocols => Protocols,
        retry => maps:get(retry, GunOpts, 3),
        retry_timeout => maps:get(retry_timeout, GunOpts, 1000),
        domain_lookup_timeout => maps:get(domain_lookup_timeout, GunOpts, 5000),
        tls_handshake_timeout => maps:get(tls_handshake_timeout, GunOpts, 10000)
    },
    Http2Opts = build_http2_opts(GunOpts),
    Opts = case maps:size(Http2Opts) of
        0 -> BaseOpts;
        _ -> BaseOpts#{http2_opts => Http2Opts}
    end,
    TlsOpts = case Transport of
        tls ->
            AlpnProtocols = resolve_alpn(Protocols),
            Opts#{tls_opts => [
                {verify, verify_peer},
                {cacerts, public_key:cacerts_get()},
                {depth, 3},
                {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]},
                {alpn_advertised_protocols, AlpnProtocols}
            ]};
        tcp -> Opts
    end,
    case gun:open(HostStr, Port, TlsOpts) of
        {ok, ConnPid} ->
            case gun:await_up(ConnPid, ConnectTimeout) of
                {ok, Protocol} ->
                    {ok, ConnPid, Protocol};
                {error, {down, {shutdown, Reason}}} ->
                    {error, Reason};
                {error, timeout} ->
                    gun:close(ConnPid),
                    {error, connect_timeout};
                {error, Reason} ->
                    gun:close(ConnPid),
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

build_http2_opts(GunOpts) ->
    Pairs = [
        {keepalive, maps:get(keepalive, GunOpts, undefined)},
        {keepalive_tolerance, maps:get(keepalive_tolerance, GunOpts, undefined)},
        {max_concurrent_streams, maps:get(max_concurrent_streams, GunOpts, undefined)},
        {initial_connection_window_size, maps:get(initial_connection_window_size, GunOpts, undefined)},
        {initial_stream_window_size, maps:get(initial_stream_window_size, GunOpts, undefined)},
        {closing_timeout, maps:get(closing_timeout, GunOpts, undefined)}
    ],
    maps:from_list([{K, V} || {K, V} <- Pairs, V =/= undefined]).

recover_connections() ->
    try
        All = ets:tab2list(?TABLE),
        lists:foreach(fun({Key, ConnPid, OldMonRef, Protocol, LastUsed}) ->
            catch erlang:demonitor(OldMonRef, [flush]),
            case erlang:is_process_alive(ConnPid) of
                true ->
                    NewMonRef = erlang:monitor(process, ConnPid),
                    ets:match_delete(?TABLE, {Key, ConnPid, '_', '_', '_'}),
                    ets:insert(?TABLE, {Key, ConnPid, NewMonRef, Protocol, LastUsed});
                false ->
                    ets:match_delete(?TABLE, {Key, ConnPid, '_', '_', '_'})
            end
        end, All)
    catch
        error:badarg -> ok
    end.

schedule_idle_check() ->
    IdleTimeout = get_idle_timeout(),
    erlang:send_after(IdleTimeout, self(), check_idle).

reap_idle_connections() ->
    IdleTimeout = get_idle_timeout(),
    Now = erlang:monotonic_time(millisecond),
    try
        All = ets:tab2list(?TABLE),
        lists:foreach(fun({_Key, ConnPid, _MonRef, _Protocol, LastUsed}) ->
            case Now - LastUsed > IdleTimeout of
                true ->
                    gun:close(ConnPid),
                    ets:match_delete(?TABLE, {'_', ConnPid, '_', '_', '_'});
                false ->
                    ok
            end
        end, All)
    catch
        error:badarg -> ok
    end.

log_gun_down(ConnPid, Protocol, Reason, Killed, Unprocessed) ->
    case is_expected_disconnect(Reason, Killed) of
        true ->
            logger:info(
                "[dream_http] connection closed: pid=~p protocol=~p reason=~p",
                [ConnPid, Protocol, Reason]);
        false when Unprocessed > 0 ->
            logger:warning(
                "[dream_http] connection down: pid=~p protocol=~p reason=~p killed=~p unprocessed=~p",
                [ConnPid, Protocol, Reason, Killed, Unprocessed]);
        false ->
            logger:warning(
                "[dream_http] connection down: pid=~p protocol=~p reason=~p killed_streams=~p",
                [ConnPid, Protocol, Reason, Killed])
    end.

is_expected_disconnect(closed, 0) -> true;
is_expected_disconnect(normal, 0) -> true;
is_expected_disconnect(_, _) -> false.

resolve_protocols(GunOpts, Transport) ->
    case maps:get(protocols, GunOpts, default) of
        default ->
            case Transport of
                tls -> [http2, http];
                tcp -> [http]
            end;
        http1_only -> [http];
        http2_only -> [http2];
        http2_preferred -> [http2, http]
    end.

resolve_alpn(Protocols) ->
    lists:filtermap(fun
        (http2) -> {true, <<"h2">>};
        (http) -> {true, <<"http/1.1">>};
        (_) -> false
    end, Protocols).

get_idle_timeout() ->
    case ets:lookup(dream_http_client_transport_config, config) of
        [{config, Config}] ->
            element(3, Config);  % idle_timeout is the 3rd field (after tag + max_connections)
        [] ->
            60000
    end.

