-module(dream_httpc_shim).

-export([request_stream/6, fetch_next/2, fetch_start_headers/2, request_stream_messages/6,
         cancel_stream/1, cancel_stream_by_string/1, receive_stream_message/1,
         decode_stream_message_for_selector/1, normalize_headers/1, request_sync/5,
         ets_table_exists/1, ets_new/2, ets_insert/7, ets_lookup/2, ets_delete/2,
         ensure_ref_mapping_table/0]).

%% @doc Start a streaming HTTP request with pull-based chunk retrieval
%%
%% Initiates a streaming HTTP request using Erlang's `httpc` library in continuous
%% streaming mode. Creates an owner process that manages the stream and services
%% `fetch_next` requests. This function returns immediately; chunks are retrieved
%% by calling `fetch_next` with the returned owner PID.
%%
%% ## Parameters
%%
%% - `Method`: HTTP method atom (`get`, `post`, `put`, `delete`, `patch`, `head`, etc.)
%% - `Url`: Full request URL as a string (e.g., `"https://api.example.com/path"`)
%% - `Headers`: List of `{Key, Value}` tuples where both are strings or binaries
%% - `Body`: Request body as a binary (empty binary `<<>>` for requests without body)
%% - `Receiver`: Process ID (unused, kept for API compatibility)
%% - `TimeoutMs`: Request timeout in milliseconds
%%
%% ## Returns
%%
%% `{ok, OwnerPid}` where `OwnerPid` is the process handling the stream. Use this
%% PID with `fetch_next` to retrieve chunks.
%%
%% ## Examples
%%
%% ```erlang
%% {ok, Owner} = request_stream(get, "https://api.example.com/data", [], <<>>, self(), 30000),
%% {chunk, Data} = fetch_next(Owner, 5000),
%% ```
%%
%% ## Notes
%%
%% - Returns immediately; HTTP errors are detected asynchronously via `fetch_next`
%% - The owner process will exit if the HTTP request fails to start
%% - `fetch_next` will detect the dead process and return an error
%% - Ensures `ssl` and `inets` applications are started before making requests
%% - Configures httpc with streaming-optimized settings (no pipelining, high session cap)
request_stream(Method, Url, Headers, Body, _Receiver, TimeoutMs) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),
    Owner = spawn(fun() -> stream_owner_loop(Method, Req, NUrl, TimeoutMs) end),
    {ok, Owner}.

%% @doc Fetch the next chunk from a streaming HTTP request
%%
%% Retrieves the next chunk of data from an active streaming request. This function
%% implements a pull-based model where chunks are requested on-demand rather than
%% being pushed to a mailbox. The owner process buffers chunks internally and delivers
%% them when requested.
%%
%% ## Parameters
%%
%% - `OwnerPid`: The owner process PID returned from `request_stream`
%% - `TimeoutMs`: Timeout in milliseconds (0 for non-blocking, -1 for infinite wait)
%%
%% ## Returns
%%
%% - `{chunk, Bin}`: Next chunk of response data as a binary
%% - `{finished, Headers}`: Stream completed successfully with trailing headers
%% - `{error, Reason}`: Error occurred (connection failure, timeout, owner process died, etc.)
%%
%% ## Examples
%%
%% ```erlang
%% {ok, Owner} = request_stream(get, "https://api.example.com/stream", [], <<>>, self(), 30000),
%% case fetch_next(Owner, 5000) of
%%     {chunk, Data} -> process_chunk(Data);
%%     {finished, Headers} -> process_complete(Headers);
%%     {error, Reason} -> handle_error(Reason)
%% end.
%% ```
%%
%% ## Notes
%%
%% - Blocks until a chunk is available, timeout expires, or an error occurs
%% - Monitors the owner process; returns error if owner dies
%% - Owner process buffers chunks internally for efficient delivery
%% - After `{finished, Headers}` or `{error, Reason}`, the stream is complete
%% - Timeout errors are returned as `{error, timeout}`
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

%% @doc Fetch the response headers from stream_start
%%
%% Returns the normalized headers received in the initial `stream_start` message.
%% This is used by the recorder to persist response headers for streaming recordings.
%%
%% Note: httpc's streamed response status code is not included in stream_start.
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

%% Stream owner process: starts httpc in continuous mode and services fetch_next requests
stream_owner_loop(Method, Req, _Url, TimeoutMs) ->
    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, 15000}, {autoredirect, true}],
    Opts = [{stream, self}, {sync, false}],
    case httpc:request(Method, Req, HttpOpts, Opts) of
        {ok, RequestId} ->
            stream_owner_wait(RequestId, [], undefined, []);
        Error ->
            %% HTTP request failed to start - exit with error
            %% fetch_next will detect the dead process and return an error
            exit({stream_start_failed, Error})
    end.

%% Wait for either a fetch_next request or internal http messages (buffered)
%% State:
%%   Buffer - queued {chunk, Bin}/{finished, Headers}/{error, Reason}
%%   StartHeaders - normalized headers from stream_start (or undefined)
%%   StartWaiters - callers waiting for stream_start headers
stream_owner_wait(RequestId, Buffer, StartHeaders, StartWaiters) ->
    receive
        {fetch_next, From} ->
            handle_fetch_next(From, RequestId, Buffer, StartHeaders, StartWaiters);
        {fetch_start_headers, From} ->
            case StartHeaders of
                undefined ->
                    %% Don't respond until we actually have stream_start headers.
                    %% This makes fetch_start_headers a reliable way to capture
                    %% response headers for recording.
                    stream_owner_wait(RequestId, Buffer, StartHeaders, [From | StartWaiters]);
                _ ->
                    From ! {stream_start_headers, normalize_headers_default(StartHeaders)},
                    stream_owner_wait(RequestId, Buffer, StartHeaders, StartWaiters)
            end;
        {http, {RequestId, stream, Bin}} ->
            %% Buffer the chunk; we only emit on fetch_next to maintain pull model
            stream_owner_wait(RequestId, Buffer ++ [{chunk, Bin}], StartHeaders, StartWaiters);
        {http, {RequestId, stream_start, Headers}} ->
            %% Record initial headers (normalized) for recorder usage
            Norm = normalize_headers(Headers),
            lists:foreach(fun(W) -> W ! {stream_start_headers, Norm} end, StartWaiters),
            stream_owner_wait(RequestId, Buffer, Norm, []);
        {http, {RequestId, stream_start, Headers, _Pid}} ->
            %% Some httpc versions include pid
            Norm = normalize_headers(Headers),
            lists:foreach(fun(W) -> W ! {stream_start_headers, Norm} end, StartWaiters),
            stream_owner_wait(RequestId, Buffer, Norm, []);
        {http, {RequestId, stream_end, Headers}} ->
            stream_owner_wait(RequestId,
                              Buffer ++ [{finished, normalize_headers(Headers)}],
                              StartHeaders,
                              StartWaiters);
        {http, {RequestId, {error, Reason}}} ->
            stream_owner_wait(RequestId, Buffer ++ [{error, Reason}], StartHeaders, StartWaiters);
        _Other ->
            stream_owner_wait(RequestId, Buffer, StartHeaders, StartWaiters)
    end.

%% Handle a fetch_next request from the client
handle_fetch_next(From, RequestId, [], StartHeaders, StartWaiters) ->
    %% Buffer empty - fetch next message from stream
    case stream_owner_next_message(RequestId) of
        {start, _Hs} ->
            %% Got headers, skip and fetch actual data
            %% Ensure StartHeaders is set even when stream_start is consumed here.
            Norm = normalize_headers(_Hs),
            lists:foreach(fun(W) -> W ! {stream_start_headers, Norm} end, StartWaiters),
            handle_fetch_next_after_start(From, RequestId, Norm, []);
        Msg ->
            %% Got chunk/finished/error - deliver it
            deliver_message(From, Msg, RequestId, StartHeaders, StartWaiters)
    end;
handle_fetch_next(From, RequestId, [Item | Rest], StartHeaders, StartWaiters) ->
    %% Buffer has items - deliver first one
    deliver_message(From, Item, RequestId, Rest, StartHeaders, StartWaiters).

%% Handle fetch_next after receiving stream_start (headers)
handle_fetch_next_after_start(From, RequestId, StartHeaders, StartWaiters) ->
    case stream_owner_next_message(RequestId) of
        {chunk, Bin} ->
            From ! {stream_chunk, Bin},
            stream_owner_wait(RequestId, [], StartHeaders, StartWaiters);
        {finished, Headers} ->
            From ! {stream_end, Headers},
            ok;
        {error, Reason} ->
            From ! {stream_error, Reason},
            ok
    end.

%% Deliver a message to the client (from live stream)
deliver_message(From, {chunk, Bin}, RequestId, StartHeaders, StartWaiters) ->
    From ! {stream_chunk, Bin},
    stream_owner_wait(RequestId, [], StartHeaders, StartWaiters);
deliver_message(From, {finished, Headers}, _RequestId, _StartHeaders, _StartWaiters) ->
    From ! {stream_end, Headers},
    ok;
deliver_message(From, {error, Reason}, _RequestId, _StartHeaders, _StartWaiters) ->
    From ! {stream_error, Reason},
    ok.

%% Deliver a message to the client (from buffer)
deliver_message(From, {chunk, Bin}, RequestId, Rest, StartHeaders, StartWaiters) ->
    From ! {stream_chunk, Bin},
    stream_owner_wait(RequestId, Rest, StartHeaders, StartWaiters);
deliver_message(From,
                {finished, Headers},
                _RequestId,
                _Rest,
                _StartHeaders,
                _StartWaiters) ->
    From ! {stream_end, Headers},
    ok;
deliver_message(From, {error, Reason}, _RequestId, _Rest, _StartHeaders, _StartWaiters) ->
    From ! {stream_error, Reason},
    ok.

normalize_headers_default(undefined) ->
    [];
normalize_headers_default(Headers) ->
    Headers.

%% Wait for the next HTTP message from httpc
stream_owner_next_message(RequestId) ->
    receive
        {http, {RequestId, stream_start, Headers}} ->
            {start, Headers};
        {http, {RequestId, stream_start, Headers, _Pid}} ->
            %% Some httpc versions include pid
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

%% @doc Start a message-based streaming HTTP request
%%
%% Initiates a streaming HTTP request where messages are sent directly to the caller's
%% process mailbox. This is used for OTP actor integration where messages arrive
%% asynchronously without needing to call `fetch_next`. The request ID is returned
%% as a string for type-safe handling in Gleam.
%%
%% ## Parameters
%%
%% - `Method`: HTTP method atom (`get`, `post`, `put`, `delete`, etc.)
%% - `Url`: Full request URL as a string
%% - `Headers`: List of `{Key, Value}` tuples (both strings or binaries)
%% - `Body`: Request body as a binary
%% - `ReceiverPid`: Process ID that will receive stream messages (unused, kept for compatibility)
%% - `TimeoutMs`: Request timeout in milliseconds
%%
%% ## Returns
%%
%% - `{ok, StringId}`: Stream started successfully, `StringId` is a string representation
%%   of the httpc request ID (use with `cancel_stream_by_string`)
%% - `{error, Reason}`: Failed to start stream (connection error, invalid URL, etc.)
%%
%% ## Examples
%%
%% ```erlang
%% {ok, ReqId} = request_stream_messages(get, "https://api.example.com/stream", [], <<>>, self(), 30000),
%% %% Messages will arrive as {http, {HttpcRef, stream_start, Headers}}, etc.
%% ```
%%
%% ## Notes
%%
%% - Messages arrive as `{http, {HttpcRef, Tag, Data}}` tuples in the process mailbox
%% - Use `decode_stream_message_for_selector` for OTP selector integration
%% - Stores bidirectional mapping: `StringId <-> HttpcRef` for cancellation
%% - String ID is derived from httpc ref's string representation (guaranteed unique)
%% - Ensures `ssl` and `inets` applications are started before making requests
request_stream_messages(Method, Url, Headers, Body, _ReceiverPid, TimeoutMs) ->
    ok = ensure_started(ssl),
    ok = ensure_started(inets),
    ok = configure_httpc(),

    ensure_ref_mapping_table(),

    NUrl = to_list(Url),
    NHeaders = to_headers(Headers),
    Req = build_req(NUrl, NHeaders, Body),

    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, 15000}, {autoredirect, true}],
    StreamOpts = [{stream, self}, {sync, false}],

    case httpc:request(Method, Req, HttpOpts, StreamOpts) of
        {ok, HttpcRef} ->
            %% Convert ref to string for type-safe Gleam API
            RefString = ref_to_string(HttpcRef),
            %% Store mapping for cancellation
            store_ref_mapping(RefString, HttpcRef),
            {ok, RefString};
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

%% @doc Cancel a streaming request using httpc ref directly
%%
%% Cancels an active streaming HTTP request using the httpc request reference directly.
%% This is a legacy function that takes the raw httpc ref. For new code, use
%% `cancel_stream_by_string` which works with the type-safe string IDs.
%%
%% ## Parameters
%%
%% - `RequestId`: The httpc request reference (returned from `httpc:request/4`)
%%
%% ## Returns
%%
%% `ok` - Always returns successfully (even if request doesn't exist)
%%
%% ## Notes
%%
%% - This function is kept for backward compatibility
%% - Prefer `cancel_stream_by_string` for type-safe cancellation
%% - After cancellation, no more messages will be sent to the receiver process
%% - Safe to call multiple times on the same request ID
cancel_stream(RequestId) ->
    httpc:cancel_request(RequestId),
    ok.

%% @doc Cancel a streaming request by string ID
%%
%% Cancels an active streaming HTTP request using the string ID returned from
%% `request_stream_messages`. Looks up the corresponding httpc reference from
%% the internal mapping table and cancels the request.
%%
%% ## Parameters
%%
%% - `StringId`: The string request ID returned from `request_stream_messages`
%%
%% ## Returns
%%
%% `nil` - Always returns successfully (even if request doesn't exist or already ended)
%%
%% ## Examples
%%
%% ```erlang
%% {ok, ReqId} = request_stream_messages(get, "https://api.example.com/stream", [], <<>>, self(), 30000),
%% %% Later, cancel the stream
%% cancel_stream_by_string(ReqId).
%% ```
%%
%% ## Notes
%%
%% - Uses internal ETS table to map string IDs to httpc refs
%% - Returns `nil` if the request ID is not found (stream already ended or never existed)
%% - After cancellation, no more messages will be sent to the receiver process
%% - Safe to call multiple times on the same request ID
%% - Mapping is cleaned up automatically when stream ends normally or errors
cancel_stream_by_string(StringId) ->
    case lookup_ref_by_string(StringId) of
        {some, HttpcRef} ->
            httpc:cancel_request(HttpcRef),
            remove_ref_mapping(StringId),
            nil;
        none ->
            %% Ref not found - stream already ended or never existed
            nil
    end.

%% @doc Receive and decode the next stream message from process mailbox
%%
%% Blocks waiting for an httpc stream message in the process mailbox and returns
%% a normalized tuple format that Gleam can easily decode. This is a helper function
%% for non-selector use cases where you want to receive messages directly from the
%% mailbox rather than using OTP selectors.
%%
%% ## Parameters
%%
%% - `TimeoutMs`: Timeout in milliseconds (0 for non-blocking, -1 for infinite wait)
%%
%% ## Returns
%%
%% - `{stream_start, RequestId, Headers}`: Stream started, initial headers received
%% - `{chunk, RequestId, Data}`: Data chunk received (binary)
%% - `{stream_end, RequestId, Headers}`: Stream completed successfully with trailing headers
%% - `{stream_error, RequestId, Reason}`: Stream failed with error (binary error message)
%% - `timeout`: No message received within the timeout period
%%
%% ## Examples
%%
%% ```erlang
%% {ok, _ReqId} = request_stream_messages(get, "https://api.example.com/stream", [], <<>>, self(), 30000),
%% case receive_stream_message(5000) of
%%     {stream_start, ReqId, Headers} -> process_start(ReqId, Headers);
%%     {chunk, ReqId, Data} -> process_chunk(ReqId, Data);
%%     {stream_end, ReqId, Headers} -> process_end(ReqId, Headers);
%%     {stream_error, ReqId, Reason} -> handle_error(ReqId, Reason);
%%     timeout -> handle_timeout()
%% end.
%% ```
%%
%% ## Notes
%%
%% - Blocks until a message arrives or timeout expires
%% - Headers are normalized to binary tuples for consistent Gleam decoding
%% - RequestId is the httpc reference (use `decode_stream_message_for_selector` for string IDs)
%% - Handles both `{http, {Ref, stream_start, Headers}}` and `{http, {Ref, stream_start, Headers, Pid}}` formats
%% - Error reasons are formatted as binaries for Gleam compatibility
receive_stream_message(TimeoutMs) ->
    receive
        {http, {RequestId, stream_start, Headers}} ->
            {stream_start, RequestId, normalize_headers(Headers)};
        {http, {RequestId, stream_start, Headers, _Pid}} ->
            %% Some httpc versions include pid
            {stream_start, RequestId, normalize_headers(Headers)};
        {http, {RequestId, stream, Data}} ->
            {chunk, RequestId, Data};
        {http, {RequestId, stream_end, Headers}} ->
            {stream_end, RequestId, normalize_headers(Headers)};
        {http, {RequestId, {error, Reason}}} ->
            {stream_error, RequestId, format_error(Reason)}
    after TimeoutMs ->
        timeout
    end.

%% @doc Decode an httpc stream message for OTP selector integration
%%
%% Processes raw httpc stream messages extracted by OTP selectors and converts them
%% to a normalized format suitable for Gleam decoding. Converts httpc references to
%% string IDs for type-safe handling in Gleam, normalizes headers to binary tuples,
%% and formats error messages as binaries.
%%
%% ## Parameters
%%
%% - `{http, InnerMessage}`: The message tuple extracted by `process:select_record/4`
%%   where `InnerMessage` is the inner tuple from httpc (e.g., `{Ref, stream_start, Headers}`)
%%
%% ## Returns
%%
%% A normalized tuple `{Tag, StringId, Data}` where:
%% - `Tag`: Atom (`stream_start`, `chunk`, `stream_end`, `stream_error`)
%% - `StringId`: String representation of the httpc request ID (for type-safe Gleam API)
%% - `Data`: Varies by tag:
%%   - `stream_start`: Normalized headers (list of `{Binary, Binary}` tuples)
%%   - `chunk`: Binary data
%%   - `stream_end`: Normalized trailing headers
%%   - `stream_error`: Binary error message
%%
%% ## Examples
%%
%% ```erlang
%% %% In selector callback
%% case decode_stream_message_for_selector({http, {Ref, stream_start, Headers}}) of
%%     {stream_start, StringId, NormalizedHeaders} -> process_start(StringId, NormalizedHeaders);
%%     {chunk, StringId, Data} -> process_chunk(StringId, Data);
%%     {stream_end, StringId, Headers} -> process_end(StringId, Headers);
%%     {stream_error, StringId, Reason} -> handle_error(StringId, Reason)
%% end.
%% ```
%%
%% ## Notes
%%
%% - Used internally by `client.select_stream_messages()` for selector integration
%% - Creates string ID mapping if it doesn't exist (handles messages arriving before mapping stored)
%% - Cleans up ref mapping when stream ends (`stream_end`) or errors (`stream_error`)
%% - Headers are normalized to binary tuples for consistent Gleam decoding
%% - Handles both `{Ref, stream_start, Headers}` and `{Ref, stream_start, Headers, Pid}` formats
%% - Error reasons are formatted as binaries for Gleam compatibility
decode_stream_message_for_selector({http, InnerMessage}) ->
    case InnerMessage of
        {HttpcRef, stream_start, Headers} ->
            StringId = get_or_create_string_id(HttpcRef),
            {stream_start, StringId, normalize_headers(Headers)};
        {HttpcRef, stream_start, Headers, _Pid} ->
            StringId = get_or_create_string_id(HttpcRef),
            {stream_start, StringId, normalize_headers(Headers)};
        {HttpcRef, stream, Data} ->
            StringId = get_or_create_string_id(HttpcRef),
            {chunk, StringId, Data};
        {HttpcRef, stream_end, Headers} ->
            StringId = get_or_create_string_id(HttpcRef),
            %% Stream ended - clean up ref mapping
            remove_ref_mapping(StringId),
            {stream_end, StringId, normalize_headers(Headers)};
        {HttpcRef, {error, Reason}} ->
            StringId = get_or_create_string_id(HttpcRef),
            %% Stream errored - clean up ref mapping
            remove_ref_mapping(StringId),
            {stream_error, StringId, format_error(Reason)};
        _ ->
            error(badarg)
    end.

%% Get string ID for httpc ref, creating mapping if needed
%% This handles the case where selector receives messages before we stored the mapping
get_or_create_string_id(HttpcRef) ->
    case lookup_string_by_ref(HttpcRef) of
        {some, StringId} ->
            StringId;
        none ->
            %% First time seeing this ref - create mapping
            StringId = ref_to_string(HttpcRef),
            store_ref_mapping(StringId, HttpcRef),
            StringId
    end.

%% @doc Normalize HTTP headers to binary tuples for Gleam decoding
%%
%% Converts HTTP headers from various formats (charlists, binaries, mixed types)
%% to a consistent format of `{Binary, Binary}` tuples that Gleam can easily decode.
%% This ensures type safety and consistent handling regardless of how httpc returns headers.
%%
%% ## Parameters
%%
%% - `Headers`: List of header tuples in any format (charlists, binaries, mixed)
%%
%% ## Returns
%%
%% List of `{Binary, Binary}` tuples where both name and value are binaries.
%%
%% ## Examples
%%
%% ```erlang
%% Headers = [{"content-type", "application/json"}, {"authorization", <<"Bearer token">>}],
%% Normalized = normalize_headers(Headers),
%% %% Returns: [{<<"content-type">>, <<"application/json">>}, {<<"authorization">>, <<"Bearer token">>}]
%% ```
%%
%% ## Notes
%%
%% - Converts charlists to binaries using `unicode:characters_to_binary/1`
%% - Leaves binaries unchanged
%% - Converts other types to binaries using `io_lib:format/2`
%% - Returns empty list `[]` if input is not a list
%% - Invalid header tuples are converted to `{<<"">>, <<"">>}`
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

%% @doc Make a synchronous (blocking) HTTP request
%%
%% Sends an HTTP request and waits for the complete response body. This is the
%% correct way to make non-streaming HTTP requests - it uses httpc's synchronous
%% mode without streaming, which is more efficient than streaming mode for complete
%% responses.
%%
%% ## Parameters
%%
%% - `Method`: HTTP method atom (`get`, `post`, `put`, `delete`, `patch`, `head`, etc.)
%% - `Url`: Full request URL as a string (e.g., `"https://api.example.com/users"`)
%% - `Headers`: List of `{Key, Value}` tuples where both are strings or binaries
%% - `Body`: Request body as a binary (empty binary `<<>>` for requests without body)
%% - `TimeoutMs`: Request timeout in milliseconds
%%
%% ## Returns
%%
%% - `{ok, {StatusCode, ResponseHeaders, Body}}`:
%%     - `StatusCode` is an integer HTTP status code (e.g. 200, 404)
%%     - `ResponseHeaders` is a list of `{Name, Value}` tuples as binaries
%%     - `Body` is the complete response body as a binary
%% - `{error, Reason}`: Error occurred (connection failure, timeout, etc.)
%%   where `Reason` is a binary error message
%%
%% ## Examples
%%
%% ```erlang
%% {ok, {Status, Headers, Body}} = request_sync(get, "https://api.example.com/users", [], <<>>, 30000),
%% ```
%%
%% ## Notes
%%
%% - Uses httpc's synchronous mode (`{sync, true}`) - blocks until complete response received
%% - Uses `{body_format, binary}` to get response as binary (not parsed)
%% - More efficient than streaming mode for non-streaming use cases
%% - Ensures `ssl` and `inets` applications are started before making requests
%% - Configures httpc with appropriate timeout and redirect settings
%% - Error reasons are formatted as binaries for Gleam compatibility
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
        {ok, {{_Version, StatusCode, _ReasonPhrase}, ResponseHeaders, ResponseBody}} ->
            {ok, {StatusCode, normalize_headers(ResponseHeaders), ResponseBody}};
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

%% =============================================================================
%% ETS Functions for Stream Recorder State Management
%% =============================================================================

%% @doc Check if an ETS table exists
%%
%% Determines whether a named ETS table exists by attempting to get its info.
%% Used internally to check if tables need to be created before use.
%%
%% ## Parameters
%%
%% - `Name`: Table name as a binary (will be converted to atom)
%%
%% ## Returns
%%
%% - `true`: Table exists
%% - `false`: Table does not exist or name is invalid
%%
%% ## Notes
%%
%% - Converts binary name to atom using `binary_to_atom`
%% - Returns `false` if conversion fails or table doesn't exist
%% - Used internally for idempotent table creation
ets_table_exists(Name) ->
    try
        NameAtom = binary_to_atom(Name, utf8),
        case ets:info(NameAtom) of
            undefined ->
                false;
            _ ->
                true
        end
    catch
        error:badarg ->
            false
    end.

%% @doc Create a new ETS table
%%
%% Creates a new ETS (Erlang Term Storage) table with the specified name and options.
%% Used internally for storing stream recorder state and request ID mappings.
%%
%% ## Parameters
%%
%% - `Name`: Table name as a binary (will be converted to atom)
%% - `Options`: List of ETS table options (e.g., `[set, public, named_table]`)
%%
%% ## Returns
%%
%% The table reference (atom or integer) returned by `ets:new/2`.
%%
%% ## Examples
%%
%% ```erlang
%% TableRef = ets_new(<<"my_table">>, [set, public, named_table]).
%% ```
%%
%% ## Notes
%%
%% - Converts binary name to atom using `binary_to_atom`
%% - Options should include `named_table` if you want to reference by name later
%% - Used internally for creating recorder and ref mapping tables
ets_new(Name, Options) ->
    NameAtom = binary_to_atom(Name, utf8),
    ets:new(NameAtom, Options).

%% @doc Insert recorder state into ETS table
%%
%% Stores stream recorder state in an ETS table for message-based streaming recording.
%% The state includes the recorder handle, recorded request, accumulated chunks, and
%% timing information for recreating streaming behavior during playback.
%%
%% ## Parameters
%%
%% - `TableName`: Table name as a binary (will be converted to atom)
%% - `Key`: String key identifying the stream (typically the request ID string)
%% - `Recorder`: Gleam recorder handle (opaque term)
%% - `RecordedRequest`: The recorded HTTP request structure
%% - `Chunks`: List of accumulated chunks (in reverse order, will be reversed on completion)
%% - `LastChunkTime`: Optional timestamp of the last chunk (for delay calculation)
%%
%% ## Returns
%%
%% `nil` - Always returns successfully
%%
%% ## Notes
%%
%% - Stores as `{Key, {Recorder, RecordedRequest, Chunks, LastChunkTime}}`
%% - Overwrites existing entry if key already exists
%% - Used internally by message-based streaming recorder
%% - Chunks are stored in reverse order (prepended) and reversed when stream completes
ets_insert(TableName, Key, Recorder, RecordedRequest, Headers, Chunks, LastChunkTime) ->
    TableAtom = binary_to_atom(TableName, utf8),
    Value = {Recorder, RecordedRequest, Headers, Chunks, LastChunkTime},
    ets:insert(TableAtom, {Key, Value}),
    nil.

%% @doc Lookup recorder state from ETS table
%%
%% Retrieves stream recorder state from an ETS table using the stream's request ID key.
%% Returns the state in a format that Gleam can decode as `MessageStreamRecorderState`.
%%
%% ## Parameters
%%
%% - `TableName`: Table name as a binary (will be converted to atom)
%% - `Key`: String key identifying the stream (typically the request ID string)
%%
%% ## Returns
%%
%% - `{some, State}`: State found, where `State` is a tuple matching Gleam's
%%   `MessageStreamRecorderState` constructor format
%% - `none`: No state found for the key (stream doesn't exist or already completed)
%%
%% ## Examples
%%
%% ```erlang
%% case ets_lookup(<<"dream_http_client_stream_recorders">>, ReqId) of
%%     {some, State} -> update_recorder_state(State);
%%     none -> handle_missing_state()
%% end.
%% ```
%%
%% ## Notes
%%
%% - Returns `none` if table doesn't exist or key not found
%% - State format: `{message_stream_recorder_state, Recorder, RecordedRequest, Chunks, LastChunkTime}`
%% - Used internally by message-based streaming recorder to update state
%% - Returns `none` if table conversion fails (safe error handling)
ets_lookup(TableName, Key) ->
    try
        TableAtom = binary_to_atom(TableName, utf8),
        case ets:lookup(TableAtom, Key) of
            [{Key, {Recorder, RecordedRequest, Headers, Chunks, LastChunkTime}}] ->
                %% Return as Gleam MessageStreamRecorderState constructor
                State =
                    {message_stream_recorder_state,
                     Recorder,
                     RecordedRequest,
                     Headers,
                     Chunks,
                     LastChunkTime},
                {some, State};
            [] ->
                none
        end
    catch
        error:badarg ->
            none
    end.

%% @doc Delete a key from an ETS table
%%
%% Removes an entry from an ETS table by key. Used for cleaning up stream recorder
%% state when a stream completes or is cancelled.
%%
%% ## Parameters
%%
%% - `TableName`: Table name as a binary (will be converted to atom)
%% - `Key`: String key identifying the entry to delete
%%
%% ## Returns
%%
%% - `true`: Key was deleted successfully
%% - `false`: Key not found or table doesn't exist
%%
%% ## Examples
%%
%% ```erlang
%% ets_delete(<<"dream_http_client_stream_recorders">>, ReqId).
%% ```
%%
%% ## Notes
%%
%% - Returns `false` if table doesn't exist or conversion fails (safe error handling)
%% - Used internally to clean up recorder state when streams end
%% - Safe to call multiple times on the same key
ets_delete(TableName, Key) ->
    try
        TableAtom = binary_to_atom(TableName, utf8),
        ets:delete(TableAtom, Key)
    catch
        error:badarg ->
            false
    end.

%% =============================================================================
%% Request ID Mapping (String <-> Httpc Ref)
%% =============================================================================

%% Table for mapping string IDs to httpc refs (for cancellation)
-define(REF_MAPPING_TABLE, dream_http_client_ref_mapping).

%% Ensure ref mapping table exists (created on first use)
ensure_ref_mapping_table() ->
    case ets:info(?REF_MAPPING_TABLE) of
        undefined ->
            ets:new(?REF_MAPPING_TABLE, [set, public, named_table]),
            ok;
        _ ->
            ok
    end.

%% Convert httpc ref to unique string ID
%% Uses the ref's string representation which is guaranteed unique
ref_to_string(Ref) ->
    list_to_binary(io_lib:format("~p", [Ref])).

%% Store bidirectional mapping: string <-> ref
store_ref_mapping(StringId, HttpcRef) ->
    ensure_ref_mapping_table(),
    ets:insert(?REF_MAPPING_TABLE, {StringId, HttpcRef}),
    %% Also store reverse mapping for message translation
    ets:insert(?REF_MAPPING_TABLE, {HttpcRef, StringId}),
    ok.

%% Lookup httpc ref by string ID (for cancellation)
lookup_ref_by_string(StringId) ->
    case ets:lookup(?REF_MAPPING_TABLE, StringId) of
        [{StringId, HttpcRef}] ->
            {some, HttpcRef};
        [] ->
            none
    end.

%% Lookup string ID by httpc ref (for message translation)
lookup_string_by_ref(HttpcRef) ->
    case ets:lookup(?REF_MAPPING_TABLE, HttpcRef) of
        [{HttpcRef, StringId}] ->
            {some, StringId};
        [] ->
            none
    end.

%% Remove both mappings (cleanup after stream ends)
remove_ref_mapping(StringId) ->
    case lookup_ref_by_string(StringId) of
        {some, HttpcRef} ->
            ets:delete(?REF_MAPPING_TABLE, StringId),
            ets:delete(?REF_MAPPING_TABLE, HttpcRef),
            ok;
        none ->
            ok
    end.
