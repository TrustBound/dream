-module(dream_httpc_shim).

-export([request_stream/5, fetch_next/1]).

%% Start a streaming HTTP request
%%
%% Parameters:
%%   Method - HTTP method atom (get, post, put, delete, etc.)
%%   Url - Full URL as a string
%%   Headers - List of {Key, Value} tuples
%%   Body - Request body as binary
%%   Receiver - Pid that will receive messages (unused, kept for compatibility)
%%
%% Returns: {ok, OwnerPid} where OwnerPid is the process handling the stream
request_stream(Method, Url, Headers, Body, _Receiver) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),
    Owner =
        spawn(fun() ->
                 stream_owner_loop(Method, Req, NUrl)
              end),
    {ok, Owner}.

%% Fetch the next chunk from a streaming request
%%
%% Parameters:
%%   OwnerPid - The owner process PID returned from request_stream/5
%%
%% Returns:
%%   {chunk, Bin} - Next chunk of data
%%   {finished, Headers} - Stream completed with response headers
%%   {error, Reason} - Error occurred
fetch_next(OwnerPid) ->
    OwnerPid ! {fetch_next, self()},
    receive
        {stream_chunk, Bin} ->
            {chunk, Bin};
        {stream_end, Headers} ->
            {finished, Headers};
        {stream_error, Reason} ->
            {error, Reason}
    after 600000 ->
        {error, timeout}
    end.

%% Stream owner process: starts httpc in continuous mode and services fetch_next requests
stream_owner_loop(Method, Req, Url) ->
    HttpOpts = [{timeout, 600000}, {connect_timeout, 15000}, {autoredirect, true}],
    Opts = [{stream, self}, {sync, false}],
    case httpc:request(Method, Req, HttpOpts, Opts) of
        {ok, RequestId} ->
            stream_owner_wait(RequestId, []);
        Error ->
            exit({stream_start_failed, Error})
    end.

%% Wait for either a fetch_next request or internal http messages (buffered)
%% State:
%%   Buffer - queued {chunk, Bin}/{finished, Headers}/{error, Reason}
stream_owner_wait(RequestId, Buffer) ->
    receive
        {fetch_next, From} ->
            case Buffer of
                [] ->
                    case stream_owner_next_message(RequestId) of
                        {start, _Hs} ->
                            %% Fetch the next message after headers and deliver it
                            case stream_owner_next_message(RequestId) of
                                {chunk, Bin2} ->
                                    From ! {stream_chunk, Bin2},
                                    stream_owner_wait(RequestId, []);
                                {finished, Headers2} ->
                                    From ! {stream_end, Headers2},
                                    ok;
                                {error, Reason2} ->
                                    From ! {stream_error, Reason2},
                                    ok
                            end;
                        {chunk, Bin} ->
                            From ! {stream_chunk, Bin},
                            stream_owner_wait(RequestId, []);
                        {finished, Headers} ->
                            From ! {stream_end, Headers},
                            ok;
                        {error, Reason} ->
                            From ! {stream_error, Reason},
                            ok
                    end;
                [Item | Rest] ->
                    case Item of
                        {chunk, Bin} ->
                            From ! {stream_chunk, Bin},
                            stream_owner_wait(RequestId, Rest);
                        {finished, Headers} ->
                            From ! {stream_end, Headers},
                            ok;
                        {error, Reason} ->
                            From ! {stream_error, Reason},
                            ok
                    end
            end;
        {http, {RequestId, stream_start, _Headers}} ->
            %% Headers received
            stream_owner_wait(RequestId, Buffer);
        {http, {RequestId, stream_start, _Headers, _NewPid}} ->
            %% Some httpc versions send stream_start with an extra pid argument
            stream_owner_wait(RequestId, Buffer);
        {http, {RequestId, stream, Bin}} ->
            %% Buffer the chunk; we only emit on fetch_next to maintain pull model
            stream_owner_wait(RequestId, Buffer ++ [{chunk, Bin}]);
        {http, {RequestId, stream_end, Headers}} ->
            stream_owner_wait(RequestId, Buffer ++ [{finished, Headers}]);
        {http, {RequestId, {error, Reason}}} ->
            stream_owner_wait(RequestId, Buffer ++ [{error, Reason}]);
        _Other ->
            stream_owner_wait(RequestId, Buffer)
    end.

%% Wait for the next HTTP message from httpc
stream_owner_next_message(RequestId) ->
    receive
        {http, {RequestId, stream_start, Headers}} ->
            {start, Headers};
        {http, {RequestId, stream, Bin}} ->
            {chunk, Bin};
        {http, {RequestId, stream_end, Headers}} ->
            {finished, Headers};
        {http, {RequestId, {error, Reason}}} ->
            {error, Reason};
        _Other ->
            stream_owner_next_message(RequestId)
    end.

%% Ensure an Erlang application is started
ensure_started(App) ->
    case application:ensure_all_started(App) of
        {ok, _} ->
            ok;
        {error, {already_started, _}} ->
            ok;
        {error, _Reason} ->
            ok
    end.

%% Configure httpc with appropriate settings for streaming
configure_httpc() ->
    %% Increase parallelism and avoid head-of-line blocking with streaming
    %% - Disable HTTP pipelining so long-lived streams don't block queued requests
    %% - Raise session cap so concurrent streams can use separate connections
    %% - Keep-alive tuning to allow reuse for non-streaming while not limiting concurrency
    ok =
        httpc:set_options([{max_sessions, 100},
                           {max_pipeline_length, 0},
                           {keep_alive_timeout, 60000},
                           {max_keep_alive_length, 100}],
                          default),
    ok.

%% Convert various types to string lists
to_list(S) when is_binary(S) ->
    unicode:characters_to_list(S);
to_list(S) when is_list(S) ->
    S;
to_list(Other) ->
    io_lib:format("~p", [Other]).

%% Convert headers to the format expected by httpc
to_headers(Hs) when is_list(Hs) ->
    lists:map(fun({K, V}) -> {to_list(K), to_list(V)} end, Hs);
to_headers(Other) ->
    Other.

%% Build the request tuple for httpc
build_req(Url, Headers, Body) when is_binary(Body), byte_size(Body) =:= 0 ->
    {Url, Headers};
build_req(Url, Headers, Body) when Body =:= undefined; Body =:= <<>> ->
    {Url, Headers};
build_req(Url, Headers, Body) ->
    {Url, Headers, to_list("application/json"), Body}.




