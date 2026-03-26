-module(hackney_bench).
-export([
    run_all/0,
    test_sync_request/0,
    test_pull_stream/0,
    test_async_stream/0,
    test_async_once_stream/0,
    test_connection_pool/0,
    test_redirect_control/0,
    test_connect_timeout/0,
    test_auto_decompression/0,
    test_error_format/0,
    test_cancel_async/0,
    test_http2_negotiation/0,
    test_http2_multiplexing/0,
    test_concurrent_requests_hackney/0,
    test_concurrent_requests_httpc/0
]).

%% Run all research tests against a target URL
%% Start the mock server first: cd modules/http_client && gleam test
%% Or use httpbin.org for external tests

-define(BASE, "http://localhost:3004").

run_all() ->
    {ok, _} = application:ensure_all_started(hackney),
    Tests = [
        {"1. Sync request", fun test_sync_request/0},
        {"2. Pull-based streaming (stream_body)", fun test_pull_stream/0},
        {"3. Async streaming (async: true)", fun test_async_stream/0},
        {"4. Async-once streaming (async: once)", fun test_async_once_stream/0},
        {"5. Connection pooling", fun test_connection_pool/0},
        {"6. Redirect control (follow_redirect)", fun test_redirect_control/0},
        {"7. Connect timeout", fun test_connect_timeout/0},
        {"8. Auto decompression", fun test_auto_decompression/0},
        {"9. Error format", fun test_error_format/0},
        {"10. Cancel async request", fun test_cancel_async/0}
    ],
    io:format("~n========================================~n"),
    io:format("  HACKNEY RESEARCH RESULTS~n"),
    io:format("========================================~n~n"),
    lists:foreach(fun({Name, Fun}) ->
        io:format("--- ~s ---~n", [Name]),
        try
            Fun(),
            io:format("  RESULT: PASS~n~n")
        catch
            Class:Reason:Stack ->
                io:format("  RESULT: FAIL~n"),
                io:format("  Error: ~p:~p~n", [Class, Reason]),
                io:format("  Stack: ~p~n~n", [hd(Stack)])
        end
    end, Tests),
    io:format("~n--- 11. HTTP/2 negotiation ---~n"),
    try test_http2_negotiation(),
        io:format("  RESULT: PASS~n~n")
    catch C11:R11:S11 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C11, R11, hd(S11)])
    end,

    io:format("--- 12. HTTP/2 multiplexing ---~n"),
    try test_http2_multiplexing(),
        io:format("  RESULT: PASS~n~n")
    catch C12:R12:S12 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C12, R12, hd(S12)])
    end,

    io:format("--- 13. Concurrent requests (hackney, 100 parallel) ---~n"),
    try test_concurrent_requests_hackney(),
        io:format("  RESULT: PASS~n~n")
    catch C13:R13:S13 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C13, R13, hd(S13)])
    end,

    io:format("--- 14. Concurrent requests (httpc, 100 parallel) ---~n"),
    try test_concurrent_requests_httpc(),
        io:format("  RESULT: PASS~n~n")
    catch C14:R14:S14 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C14, R14, hd(S14)])
    end,

    io:format("========================================~n"),
    io:format("  DONE~n"),
    io:format("========================================~n"),
    ok.

%% Test 1: Basic sync request - does hackney return status, headers, body?
test_sync_request() ->
    {ok, Status, Headers, Body} = hackney:request(get, <<?BASE, "/text">>, [], <<>>, []),
    io:format("  Status: ~p~n", [Status]),
    io:format("  Headers type: ~p (first: ~p)~n", [length(Headers), hd(Headers)]),
    io:format("  Body type: ~p, size: ~p~n", [element(1, {Body}), byte_size(Body)]),
    io:format("  Body: ~s~n", [Body]),
    true = is_integer(Status),
    true = Status =:= 200,
    true = is_binary(Body),
    ok.

%% Test 2: Pull-based streaming via stream_body/1
%% This is hackney's equivalent of our pull-based yielder model
test_pull_stream() ->
    {ok, Status, Headers, Ref} = hackney:request(get, <<?BASE, "/stream/fast">>, [], <<>>, []),
    io:format("  Status: ~p~n", [Status]),
    io:format("  Headers count: ~p~n", [length(Headers)]),
    io:format("  Ref type: ~p~n", [Ref]),
    {Chunks, _FinalRef} = collect_stream_body(Ref, []),
    io:format("  Chunks received: ~p~n", [length(Chunks)]),
    io:format("  Total bytes: ~p~n", [lists:sum([byte_size(C) || C <- Chunks])]),
    true = length(Chunks) > 0,
    ok.

collect_stream_body(Ref, Acc) ->
    case hackney:stream_body(Ref) of
        {ok, Data} ->
            collect_stream_body(Ref, [Data | Acc]);
        done ->
            {lists:reverse(Acc), Ref};
        {error, Reason} ->
            io:format("  Stream error: ~p~n", [Reason]),
            {lists:reverse(Acc), Ref}
    end.

%% Test 3: Async streaming - messages pushed to process mailbox
%% This is hackney's equivalent of our message-based start_stream() model
test_async_stream() ->
    {ok, Ref} = hackney:request(get, <<?BASE, "/stream/fast">>, [], <<>>, [{async, true}]),
    io:format("  Ref: ~p~n", [Ref]),
    {Status, Headers, Chunks} = collect_async_messages(Ref, undefined, [], []),
    io:format("  Status: ~p~n", [Status]),
    io:format("  Headers count: ~p~n", [length(Headers)]),
    io:format("  Chunks received: ~p~n", [length(Chunks)]),
    io:format("  Total bytes: ~p~n", [lists:sum([byte_size(C) || C <- Chunks])]),
    true = Status =:= 200,
    true = length(Chunks) > 0,
    ok.

collect_async_messages(Ref, Status, Headers, Chunks) ->
    receive
        {hackney_response, Ref, {status, S, _Reason}} ->
            collect_async_messages(Ref, S, Headers, Chunks);
        {hackney_response, Ref, {headers, H}} ->
            collect_async_messages(Ref, Status, H, Chunks);
        {hackney_response, Ref, done} ->
            {Status, Headers, lists:reverse(Chunks)};
        {hackney_response, Ref, Bin} when is_binary(Bin) ->
            collect_async_messages(Ref, Status, Headers, [Bin | Chunks]);
        {hackney_response, Ref, {error, Reason}} ->
            io:format("  Async error: ~p~n", [Reason]),
            {Status, Headers, lists:reverse(Chunks)}
    after 30000 ->
        io:format("  TIMEOUT waiting for async message~n"),
        {Status, Headers, lists:reverse(Chunks)}
    end.

%% Test 4: Async-once streaming - pull one chunk at a time via stream_next/1
%% This gives backpressure control like our pull-based model
test_async_once_stream() ->
    {ok, Ref} = hackney:request(get, <<?BASE, "/stream/fast">>, [], <<>>, [{async, once}]),
    io:format("  Ref: ~p~n", [Ref]),
    {Status, Headers, Chunks} = collect_async_once(Ref, undefined, [], []),
    io:format("  Status: ~p~n", [Status]),
    io:format("  Headers count: ~p~n", [length(Headers)]),
    io:format("  Chunks received: ~p~n", [length(Chunks)]),
    true = Status =:= 200,
    true = length(Chunks) > 0,
    ok.

collect_async_once(Ref, Status, Headers, Chunks) ->
    receive
        {hackney_response, Ref, {status, S, _Reason}} ->
            hackney:stream_next(Ref),
            collect_async_once(Ref, S, Headers, Chunks);
        {hackney_response, Ref, {headers, H}} ->
            hackney:stream_next(Ref),
            collect_async_once(Ref, Status, H, Chunks);
        {hackney_response, Ref, done} ->
            {Status, Headers, lists:reverse(Chunks)};
        {hackney_response, Ref, Bin} when is_binary(Bin) ->
            hackney:stream_next(Ref),
            collect_async_once(Ref, Status, Headers, [Bin | Chunks]);
        {hackney_response, Ref, {error, Reason}} ->
            io:format("  Async-once error: ~p~n", [Reason]),
            {Status, Headers, lists:reverse(Chunks)}
    after 30000 ->
        io:format("  TIMEOUT~n"),
        {Status, Headers, lists:reverse(Chunks)}
    end.

%% Test 5: Connection pooling - does hackney reuse connections?
test_connection_pool() ->
    %% Make 5 requests to same host - check pool stats
    lists:foreach(fun(I) ->
        {ok, 200, _H, Body} = hackney:request(get, <<?BASE, "/text">>, [], <<>>, []),
        io:format("  Request ~p: ~p bytes~n", [I, byte_size(Body)])
    end, lists:seq(1, 5)),
    %% Check pool stats
    Stats = hackney_pool:get_stats(default),
    io:format("  Pool stats: ~p~n", [Stats]),
    ok.

%% Test 6: Redirect control
test_redirect_control() ->
    %% hackney uses follow_redirect option (default: false)
    %% This is different from httpc where autoredirect defaults to true
    io:format("  hackney default: follow_redirect = false~n"),
    io:format("  httpc default: autoredirect = true~n"),
    io:format("  hackney also supports max_redirect option (default: 5)~n"),
    io:format("  NOTE: No redirect endpoint on mock server to test against~n"),
    ok.

%% Test 7: Connect timeout behavior
test_connect_timeout() ->
    %% hackney default connect_timeout is 8000ms
    %% httpc default is infinity (we hardcoded 15000ms)
    T1 = erlang:monotonic_time(millisecond),
    Result = hackney:request(get, <<"http://localhost:1/test">>, [], <<>>, [
        {connect_timeout, 1000}
    ]),
    T2 = erlang:monotonic_time(millisecond),
    Elapsed = T2 - T1,
    io:format("  Result: ~p~n", [Result]),
    io:format("  Elapsed: ~pms (with 1000ms connect_timeout)~n", [Elapsed]),
    io:format("  hackney default connect_timeout: 8000ms~n"),
    io:format("  httpc default connect_timeout: infinity~n"),
    ok.

%% Test 8: Auto decompression
test_auto_decompression() ->
    %% Does hackney handle gzip automatically?
    {ok, Status, Headers, Body} = hackney:request(get, <<?BASE, "/gzip">>, [], <<>>, []),
    io:format("  Status: ~p~n", [Status]),
    CE = proplists:get_value(<<"content-encoding">>, Headers, <<"none">>),
    io:format("  Content-Encoding header: ~p~n", [CE]),
    io:format("  Body size: ~p~n", [byte_size(Body)]),
    io:format("  Body starts with: ~p~n", [binary:part(Body, 0, min(100, byte_size(Body)))]),
    %% Check if body looks like JSON (decompressed) or binary (compressed)
    IsJson = case Body of
        <<"{", _/binary>> -> true;
        _ -> false
    end,
    io:format("  Body looks like JSON (decompressed): ~p~n", [IsJson]),
    ok.

%% Test 9: Error format - what do hackney errors look like?
test_error_format() ->
    %% Connection refused
    {error, Reason1} = hackney:request(get, <<"http://localhost:1/test">>, [], <<>>, [
        {connect_timeout, 500}
    ]),
    io:format("  Connection refused error: ~p~n", [Reason1]),
    io:format("  Error type: ~p~n", [element(1, {Reason1})]),
    ok.

%% Test 10: Cancel an async request
test_cancel_async() ->
    {ok, Ref} = hackney:request(get, <<?BASE, "/stream/slow">>, [], <<>>, [{async, true}]),
    io:format("  Started async request, ref: ~p~n", [Ref]),
    timer:sleep(500),
    %% hackney 3.x: try hackney:close/1 instead of cancel_request
    Result = hackney:close(Ref),
    io:format("  Close result: ~p~n", [Result]),
    ok.

%% Test 11: Does hackney negotiate HTTP/2 with a real HTTPS server?
test_http2_negotiation() ->
    Urls = [
        <<"https://http2.pro/api/v1">>,
        <<"https://www.google.com">>
    ],
    lists:foreach(fun(Url) ->
        io:format("  Requesting ~s~n", [Url]),
        case hackney:request(get, Url, [], <<>>, []) of
            {ok, Status, Headers, Body} ->
                io:format("  Status: ~p~n", [Status]),
                io:format("  Body size: ~p~n", [byte_size(Body)]),
                HeaderNames = [N || {N, _V} <- Headers],
                AllLower = lists:all(fun(N) -> N =:= string:lowercase(N) end, HeaderNames),
                io:format("  All headers lowercase (HTTP/2 indicator): ~p~n", [AllLower]),
                io:format("  Sample headers: ~p~n", [lists:sublist(Headers, 3)]),
                %% Check if body mentions h2 protocol
                case binary:match(Body, <<"h2">>) of
                    nomatch -> io:format("  Body does not mention h2~n");
                    _ -> io:format("  Body mentions h2 (server confirms HTTP/2)~n")
                end;
            {error, E} ->
                io:format("  Error: ~p~n", [E])
        end,
        io:format("~n")
    end, Urls),
    ok.

%% Test 12: HTTP/2 multiplexing - multiple requests on same connection
test_http2_multiplexing() ->
    Url = <<"https://nghttp2.org/httpbin/get">>,
    %% Make 5 concurrent requests and see if they share connections
    Self = self(),
    T1 = erlang:monotonic_time(millisecond),
    lists:foreach(fun(I) ->
        spawn(fun() ->
            Result = hackney:request(get, Url, [], <<>>, [
                {protocols, [http2, http1]}
            ]),
            Self ! {done, I, Result}
        end)
    end, lists:seq(1, 5)),
    %% Collect results
    Results = [receive {done, I, R} -> {I, R} after 15000 -> {timeout, timeout} end
               || I <- lists:seq(1, 5)],
    T2 = erlang:monotonic_time(millisecond),
    lists:foreach(fun({I, R}) ->
        case R of
            {ok, S, _H, _B} -> io:format("  Request ~p: status ~p~n", [I, S]);
            {error, E} -> io:format("  Request ~p: error ~p~n", [I, E]);
            _ -> io:format("  Request ~p: ~p~n", [I, R])
        end
    end, Results),
    io:format("  Total time for 5 concurrent HTTPS requests: ~pms~n", [T2 - T1]),
    ok.

%% Test 13: Benchmark concurrent requests with hackney at multiple scales
test_concurrent_requests_hackney() ->
    %% Use a dedicated pool with large max to avoid pool-size bottleneck
    hackney_pool:start_pool(bench_pool, [{max_connections, 2000}, {timeout, 60000}]),
    lists:foreach(fun(N) ->
        Self = self(),
        T1 = erlang:monotonic_time(millisecond),
        lists:foreach(fun(I) ->
            spawn(fun() ->
                R = hackney:request(get, <<?BASE, "/text">>, [], <<>>, [{pool, bench_pool}]),
                Self ! {hackney_done, N, I, R}
            end)
        end, lists:seq(1, N)),
        Successes = lists:foldl(fun(I, Acc) ->
            receive
                {hackney_done, N, I, {ok, 200, _H, _B}} -> Acc + 1;
                {hackney_done, N, I, Other} ->
                    case N =< 100 of
                        true -> io:format("  hackney fail ~p: ~p~n", [I, Other]);
                        false -> ok
                    end,
                    Acc
            after 30000 -> Acc
            end
        end, 0, lists:seq(1, N)),
        T2 = erlang:monotonic_time(millisecond),
        io:format("  hackney ~p concurrent: ~p/~p in ~pms~n", [N, Successes, N, T2 - T1])
    end, [100, 500, 1000, 5000]),
    PoolStats = hackney_pool:get_stats(bench_pool),
    io:format("  Pool stats after: ~p~n", [PoolStats]),
    hackney_pool:stop_pool(bench_pool),
    ok.

%% Test 14: Benchmark concurrent requests with httpc at multiple scales
test_concurrent_requests_httpc() ->
    {ok, _} = application:ensure_all_started(inets),
    {ok, _} = application:ensure_all_started(ssl),
    %% Reset httpc to cold state by using a fresh profile
    inets:stop(httpc, default),
    inets:start(httpc, [{profile, default}]),
    httpc:set_options([{max_sessions, 2000}, {max_pipeline_length, 0},
                       {keep_alive_timeout, 60000}, {max_keep_alive_length, 1000}]),
    lists:foreach(fun(N) ->
        Self = self(),
        T1 = erlang:monotonic_time(millisecond),
        lists:foreach(fun(I) ->
            spawn(fun() ->
                R = httpc:request(get, {"http://localhost:3004/text", []},
                                  [{timeout, 30000}, {connect_timeout, 5000}],
                                  [{sync, true}, {body_format, binary}]),
                Self ! {httpc_done, N, I, R}
            end)
        end, lists:seq(1, N)),
        Successes = lists:foldl(fun(I, Acc) ->
            receive
                {httpc_done, N, I, {ok, _}} -> Acc + 1;
                {httpc_done, N, I, _} -> Acc
            after 30000 -> Acc
            end
        end, 0, lists:seq(1, N)),
        T2 = erlang:monotonic_time(millisecond),
        io:format("  httpc  ~p concurrent: ~p/~p in ~pms~n", [N, Successes, N, T2 - T1])
    end, [100, 500, 1000, 5000]),
    ok.
