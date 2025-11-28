-module(dream_httpc_shim).

-export([request_stream/6, fetch_next/2, request_stream_messages/6, cancel_stream/1,
         receive_stream_message/1, decode_stream_message_for_selector/1, normalize_headers/1,
         request_sync/5]).

%% Start a streaming HTTP request
%%
%% Parameters:
%%   Method - HTTP method atom (get, post, put, delete, etc.)
%%   Url - Full URL as a string
%%   Headers - List of {Key, Value} tuples
%%   Body - Request body as binary
%%   Receiver - Pid that will receive messages (unused, kept for compatibility)
%%   TimeoutMs - Request timeout in milliseconds
%%
%% Returns: {ok, OwnerPid} where OwnerPid is the process handling the stream
%%
%% Note: This returns immediately. HTTP errors are detected asynchronously
%% and returned via fetch_next/2. The owner process will exit if the HTTP
%% request fails to start, which will cause fetch_next/2 to return an error.
request_stream(Method, Url, Headers, Body, _Receiver, TimeoutMs) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),
    Owner = spawn(fun() -> stream_owner_loop(Method, Req, NUrl, TimeoutMs) end),
    {ok, Owner}.

%% Fetch the next chunk from a streaming request
%%
%% Parameters:
%%   OwnerPid - The owner process PID returned from request_stream/6
%%   TimeoutMs - Timeout in milliseconds
%%
%% Returns:
%%   {chunk, Bin} - Next chunk of data
%%   {finished, Headers} - Stream completed with response headers
%%   {error, Reason} - Error occurred (including if owner process died)
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
            %% Owner process died - extract the real error
            {error, format_exit_reason(Reason)}
    after TimeoutMs ->
        erlang:demonitor(MonitorRef, [flush]),
        {error, timeout}
    end.

%% Stream owner process: starts httpc in continuous mode and services fetch_next requests
stream_owner_loop(Method, Req, _Url, TimeoutMs) ->
    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, 15000}, {autoredirect, true}],
    Opts = [{stream, self}, {sync, false}],
    case httpc:request(Method, Req, HttpOpts, Opts) of
        {ok, RequestId} ->
            stream_owner_wait(RequestId, []);
        Error ->
            %% HTTP request failed to start - exit with error
            %% fetch_next will detect the dead process and return an error
            exit({stream_start_failed, Error})
    end.

%% Wait for either a fetch_next request or internal http messages (buffered)
%% State:
%%   Buffer - queued {chunk, Bin}/{finished, Headers}/{error, Reason}
stream_owner_wait(RequestId, Buffer) ->
    receive
        {fetch_next, From} ->
            handle_fetch_next(From, RequestId, Buffer);
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

%% Handle a fetch_next request from the client
handle_fetch_next(From, RequestId, []) ->
    %% Buffer empty - fetch next message from stream
    case stream_owner_next_message(RequestId) of
        {start, _Hs} ->
            %% Got headers, skip and fetch actual data
            handle_fetch_next_after_start(From, RequestId);
        Msg ->
            %% Got chunk/finished/error - deliver it
            deliver_message(From, Msg, RequestId)
    end;
handle_fetch_next(From, RequestId, [Item | Rest]) ->
    %% Buffer has items - deliver first one
    deliver_message(From, Item, RequestId, Rest).

%% Handle fetch_next after receiving stream_start (headers)
handle_fetch_next_after_start(From, RequestId) ->
    case stream_owner_next_message(RequestId) of
        {chunk, Bin} ->
            From ! {stream_chunk, Bin},
            stream_owner_wait(RequestId, []);
        {finished, Headers} ->
            From ! {stream_end, Headers},
            ok;
        {error, Reason} ->
            From ! {stream_error, Reason},
            ok
    end.

%% Deliver a message to the client (from live stream)
deliver_message(From, {chunk, Bin}, RequestId) ->
    From ! {stream_chunk, Bin},
    stream_owner_wait(RequestId, []);
deliver_message(From, {finished, Headers}, _RequestId) ->
    From ! {stream_end, Headers},
    ok;
deliver_message(From, {error, Reason}, _RequestId) ->
    From ! {stream_error, Reason},
    ok.

%% Deliver a message to the client (from buffer)
deliver_message(From, {chunk, Bin}, RequestId, Rest) ->
    From ! {stream_chunk, Bin},
    stream_owner_wait(RequestId, Rest);
deliver_message(From, {finished, Headers}, _RequestId, _Rest) ->
    From ! {stream_end, Headers},
    ok;
deliver_message(From, {error, Reason}, _RequestId, _Rest) ->
    From ! {stream_error, Reason},
    ok.

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

%% ============================================================================
%% Message-Based Streaming (Thin Wrapper)
%% ============================================================================

%% Start a streaming HTTP request with direct message delivery
%%
%% This is a thin wrapper around httpc that lets it send messages directly
%% to the ReceiverPid. No owner process, no buffering, no complexity.
%%
%% Parameters:
%%   Method - HTTP method atom (get, post, put, delete, etc.)
%%   Url - Full URL as a string
%%   Headers - List of {Key, Value} tuples
%%   Body - Request body as binary
%%   ReceiverPid - Pid that will receive httpc messages directly
%%
%% Returns: {ok, RequestId} where RequestId is httpc's request identifier
%%
%% Messages sent to ReceiverPid by httpc:
%%   {http, {RequestId, stream_start, Headers}}
%%   {http, {RequestId, stream, BinaryChunk}}
%%   {http, {RequestId, stream_end, Headers}}
%%   {http, {RequestId, {error, Reason}}}
request_stream_messages(Method, Url, Headers, Body, _ReceiverPid, TimeoutMs) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),

    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, 15000}, {autoredirect, true}],
    StreamOpts = [{stream, self}, {sync, false}],

    httpc:request(Method, Req, HttpOpts, StreamOpts).

%% Cancel a streaming request
%%
%% Parameters:
%%   RequestId - The request ID returned from request_stream_messages/5
%%
%% Returns: ok
cancel_stream(RequestId) ->
    httpc:cancel_request(RequestId),
    ok.

%% Receive and decode the next stream message
%%
%% This is a helper for non-selector use cases. It blocks waiting for
%% an httpc stream message and returns a clean tuple that Gleam can decode.
%%
%% Parameters:
%%   TimeoutMs - Timeout in milliseconds
%%
%% Returns:
%%   {stream_start, RequestId, Headers} - Stream started
%%   {chunk, RequestId, Data} - Data chunk
%%   {stream_end, RequestId, Headers} - Stream completed
%%   {stream_error, RequestId, Reason} - Stream failed
%%   timeout - No message received within timeout
receive_stream_message(TimeoutMs) ->
    receive
        {http, {RequestId, stream_start, Headers}} ->
            {stream_start, RequestId, Headers};
        {http, {RequestId, stream_start, Headers, _Pid}} ->
            %% Some httpc versions include pid
            {stream_start, RequestId, Headers};
        {http, {RequestId, stream, Data}} ->
            {chunk, RequestId, Data};
        {http, {RequestId, stream_end, Headers}} ->
            {stream_end, RequestId, Headers};
        {http, {RequestId, {error, Reason}}} ->
            {stream_error, RequestId, format_error(Reason)}
    after TimeoutMs ->
        timeout
    end.

%% Decode an httpc stream message for selector integration
%%
%% Erlang does ALL the heavy lifting:
%% - Receives FULL {http, InnerTuple} messages from selector
%% - Pattern matches on all httpc message variants
%% - Normalizes headers (charlist -> binary)
%% - Returns simple {Tag, RequestId, Data} tuple
%%
%% Gleam just decodes the simple tuple - no raw httpc knowledge needed.
decode_stream_message_for_selector({http, InnerMessage}) ->
    case InnerMessage of
        {RequestId, stream_start, Headers} ->
            {stream_start, RequestId, normalize_headers(Headers)};
        {RequestId, stream_start, Headers, _Pid} ->
            {stream_start, RequestId, normalize_headers(Headers)};
        {RequestId, stream, Data} ->
            {chunk, RequestId, Data};
        {RequestId, stream_end, Headers} ->
            {stream_end, RequestId, normalize_headers(Headers)};
        {RequestId, {error, Reason}} ->
            {stream_error, RequestId, format_error(Reason)};
        _ ->
            error(badarg)
    end.

%% Normalize headers to always be string tuples for easy Gleam decoding
normalize_headers(Headers) when is_list(Headers) ->
    lists:map(fun normalize_header_tuple/1, Headers);
normalize_headers(_) ->
    [].

normalize_header_tuple({Name, Value}) ->
    {to_binary(Name), to_binary(Value)};
normalize_header_tuple(_) ->
    {<<"">>, <<"">>}.

to_binary(Bin) when is_binary(Bin) ->
    Bin;
to_binary(List) when is_list(List) ->
    unicode:characters_to_binary(List);
to_binary(Other) ->
    iolist_to_binary(io_lib:format("~p", [Other])).

%% Synchronous HTTP request - for blocking send() calls
%%
%% This is the RIGHT way to do synchronous HTTP requests.
%% Don't use streaming mode for non-streaming use cases.
%%
%% Parameters:
%%   Method - HTTP method atom (get, post, put, delete, etc.)
%%   Url - Full URL as a string
%%   Headers - List of {Key, Value} tuples
%%   Body - Request body as binary
%%
%% Returns:
%%   {ok, Body} - Response body as binary
%%   {error, Reason} - Error string
request_sync(Method, Url, Headers, Body, TimeoutMs) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),

    %% Use synchronous mode WITHOUT streaming - this is what send() should use
    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, 15000}, {autoredirect, true}],
    Opts = [{sync, true}, {body_format, binary}],

    case httpc:request(Method, Req, HttpOpts, Opts) of
        {ok, {{_Version, _StatusCode, _ReasonPhrase}, _Headers, ResponseBody}} ->
            {ok, ResponseBody};
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% Format exit reason from owner process death
%%
%% When the owner process dies, we extract the exit reason and format it
%% into a meaningful error message for the user.
format_exit_reason({stream_start_failed, Error}) ->
    %% HTTP request failed to start - return the actual httpc error
    format_error(Error);
format_exit_reason(normal) ->
    %% Normal exit - shouldn't happen in middle of stream
    <<"Stream process exited normally">>;
format_exit_reason(Reason) ->
    %% Some other exit reason - format it for debugging
    iolist_to_binary(io_lib:format("Stream process died: ~p", [Reason])).
