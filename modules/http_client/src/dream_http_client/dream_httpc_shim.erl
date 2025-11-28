-module(dream_httpc_shim).

-export([request_stream/6, fetch_next/2, request_stream_messages/6, cancel_stream/1,
         cancel_stream_by_string/1, receive_stream_message/1, decode_stream_message_for_selector/1,
         normalize_headers/1, request_sync/5, ets_table_exists/1, ets_new/2, ets_insert/6,
         ets_lookup/2, ets_delete/2]).

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
%% Returns {ok, StringId} where StringId is a string representation of the request
%% Stores mapping: StringId -> HttpcRef for cancellation
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

%% Cancel a streaming request (legacy - takes httpc ref directly)
cancel_stream(RequestId) ->
    httpc:cancel_request(RequestId),
    ok.

%% Cancel a streaming request by string ID
%% Looks up the httpc ref from our mapping table and cancels it
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

%% Decode an httpc stream message for selector integration
%%
%% Converts httpc refs to string IDs for type-safe Gleam API
%% Returns {Tag, StringId, Data} tuple
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

%% =============================================================================
%% ETS Functions for Stream Recorder State Management
%% =============================================================================

%% Check if ETS table exists
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

%% Create ETS table
ets_new(Name, Options) ->
    NameAtom = binary_to_atom(Name, utf8),
    ets:new(NameAtom, Options).

%% Insert recorder state into ETS table
%% Stores as {Key, {Recorder, RecordedRequest, Chunks, LastChunkTime}}
ets_insert(TableName, Key, Recorder, RecordedRequest, Chunks, LastChunkTime) ->
    TableAtom = binary_to_atom(TableName, utf8),
    Value = {Recorder, RecordedRequest, Chunks, LastChunkTime},
    ets:insert(TableAtom, {Key, Value}),
    nil.

%% Lookup recorder state from ETS table
%% Returns {some, State} or none
ets_lookup(TableName, Key) ->
    try
        TableAtom = binary_to_atom(TableName, utf8),
        case ets:lookup(TableAtom, Key) of
            [{Key, {Recorder, RecordedRequest, Chunks, LastChunkTime}}] ->
                %% Return as Gleam MessageStreamRecorderState constructor
                State =
                    {message_stream_recorder_state,
                     Recorder,
                     RecordedRequest,
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

%% Delete a key from ETS table
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
