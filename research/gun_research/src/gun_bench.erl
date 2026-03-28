-module(gun_bench).
-export([
    run_all/0,
    test_http1_sync/0,
    test_http2_negotiation/0,
    test_http2_multiplexing/0,
    test_http2_multiplexing_single_conn/0,
    test_concurrent_scale/0,
    test_streaming/0,
    test_cancel_stream/0,
    test_error_handling/0,
    test_connection_reuse/0,
    test_connect_timeout/0,
    test_auto_decompression/0,
    test_h2_cancel_stream/0
]).

-define(BASE_HOST, "localhost").
-define(BASE_PORT, 3004).

run_all() ->
    io:format("Starting gun research...~n~n"),
    io:format("========================================~n"),
    io:format("  GUN RESEARCH RESULTS~n"),
    io:format("========================================~n~n"),

    io:format("--- 1. HTTP/1.1 sync request (localhost) ---~n"),
    try test_http1_sync(),
        io:format("  RESULT: PASS~n~n")
    catch C1:R1:S1 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C1, R1, hd(S1)])
    end,

    io:format("--- 2. HTTP/2 negotiation (real HTTPS server) ---~n"),
    try test_http2_negotiation(),
        io:format("  RESULT: PASS~n~n")
    catch C2:R2:S2 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C2, R2, hd(S2)])
    end,

    io:format("--- 3. HTTP/2 multiplexing (real HTTPS, multiple streams) ---~n"),
    try test_http2_multiplexing(),
        io:format("  RESULT: PASS~n~n")
    catch C3:R3:S3 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C3, R3, hd(S3)])
    end,

    io:format("--- 4. HTTP/2 multiplexing (single conn, many streams) ---~n"),
    try test_http2_multiplexing_single_conn(),
        io:format("  RESULT: PASS~n~n")
    catch C4:R4:S4 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C4, R4, hd(S4)])
    end,

    io:format("--- 5. Concurrent scale (100, 500, 1000, 5000 against localhost) ---~n"),
    try test_concurrent_scale(),
        io:format("  RESULT: PASS~n~n")
    catch C5:R5:S5 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C5, R5, hd(S5)])
    end,

    io:format("--- 6. Streaming response ---~n"),
    try test_streaming(),
        io:format("  RESULT: PASS~n~n")
    catch C6:R6:S6 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C6, R6, hd(S6)])
    end,

    io:format("--- 7. Cancel stream ---~n"),
    try test_cancel_stream(),
        io:format("  RESULT: PASS~n~n")
    catch C7:R7:S7 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C7, R7, hd(S7)])
    end,

    io:format("--- 8. Error handling ---~n"),
    try test_error_handling(),
        io:format("  RESULT: PASS~n~n")
    catch C8:R8:S8 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C8, R8, hd(S8)])
    end,

    io:format("--- 9. Connection reuse (many requests, one conn) ---~n"),
    try test_connection_reuse(),
        io:format("  RESULT: PASS~n~n")
    catch C9:R9:S9 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C9, R9, hd(S9)])
    end,

    io:format("--- 10. Connect timeout behavior ---~n"),
    try test_connect_timeout(),
        io:format("  RESULT: PASS~n~n")
    catch C10:R10:S10 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C10, R10, hd(S10)])
    end,

    io:format("--- 11. Auto decompression ---~n"),
    try test_auto_decompression(),
        io:format("  RESULT: PASS~n~n")
    catch C11:R11:S11 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C11, R11, hd(S11)])
    end,

    io:format("--- 12. HTTP/2 cancel stream (connection survives) ---~n"),
    try test_h2_cancel_stream(),
        io:format("  RESULT: PASS~n~n")
    catch C12:R12:S12 ->
        io:format("  RESULT: FAIL (~p:~p)~n  Stack: ~p~n~n", [C12, R12, hd(S12)])
    end,

    io:format("========================================~n"),
    io:format("  DONE~n"),
    io:format("========================================~n"),
    ok.

%% Test 1: Basic HTTP/1.1 sync request against mock server
test_http1_sync() ->
    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
        protocols => [http]
    }),
    {ok, Protocol} = gun:await_up(ConnPid),
    io:format("  Protocol: ~p~n", [Protocol]),
    StreamRef = gun:get(ConnPid, "/text"),
    case gun:await(ConnPid, StreamRef, 5000) of
        {response, fin, Status, Headers} ->
            io:format("  Status: ~p (no body)~n", [Status]),
            io:format("  Headers: ~p~n", [Headers]);
        {response, nofin, Status, Headers} ->
            io:format("  Status: ~p~n", [Status]),
            io:format("  Headers count: ~p~n", [length(Headers)]),
            {ok, Body} = gun:await_body(ConnPid, StreamRef, 5000),
            io:format("  Body: ~s (~p bytes)~n", [Body, byte_size(Body)])
    end,
    gun:close(ConnPid),
    ok.

%% Test 2: HTTP/2 ALPN negotiation with a real HTTPS server
test_http2_negotiation() ->
    {ok, ConnPid} = gun:open("www.google.com", 443, #{
        transport => tls,
        protocols => [http2],
        tls_opts => [{verify, verify_none}]
    }),
    case gun:await_up(ConnPid, 10000) of
        {ok, Protocol} ->
            io:format("  Negotiated protocol: ~p~n", [Protocol]),
            StreamRef = gun:get(ConnPid, "/"),
            case gun:await(ConnPid, StreamRef, 10000) of
                {response, nofin, Status, Headers} ->
                    io:format("  Status: ~p~n", [Status]),
                    HeaderNames = [N || {N, _} <- Headers],
                    AllLower = lists:all(fun(N) ->
                        N =:= string:lowercase(N)
                    end, HeaderNames),
                    io:format("  All headers lowercase: ~p~n", [AllLower]),
                    io:format("  Sample headers: ~p~n", [lists:sublist(Headers, 3)]),
                    gun:cancel(ConnPid, StreamRef);
                {response, fin, Status, _Headers} ->
                    io:format("  Status: ~p (no body)~n", [Status])
            end;
        {error, Reason} ->
            io:format("  Connection failed: ~p~n", [Reason])
    end,
    gun:close(ConnPid),
    ok.

%% Test 3: HTTP/2 multiplexing - concurrent requests on separate connections
test_http2_multiplexing() ->
    {ok, ConnPid} = gun:open("www.google.com", 443, #{
        transport => tls,
        protocols => [http2],
        tls_opts => [{verify, verify_none}]
    }),
    {ok, http2} = gun:await_up(ConnPid, 10000),
    io:format("  Connected via HTTP/2~n"),

    N = 10,
    T1 = erlang:monotonic_time(millisecond),
    StreamRefs = [gun:get(ConnPid, "/") || _ <- lists:seq(1, N)],
    io:format("  Sent ~p concurrent requests on ONE connection~n", [N]),

    Results = lists:map(fun(Ref) ->
        case gun:await(ConnPid, Ref, 10000) of
            {response, nofin, Status, _H} ->
                gun:cancel(ConnPid, Ref),
                {ok, Status};
            {response, fin, Status, _H} ->
                {ok, Status};
            {error, E} ->
                {error, E}
        end
    end, StreamRefs),
    T2 = erlang:monotonic_time(millisecond),

    Successes = length([ok || {ok, _} <- Results]),
    io:format("  ~p/~p succeeded in ~pms~n", [Successes, N, T2 - T1]),
    io:format("  All on a SINGLE TCP connection (HTTP/2 multiplexing)~n"),
    gun:close(ConnPid),
    ok.

%% Test 4: Many HTTP/2 streams on a single connection
test_http2_multiplexing_single_conn() ->
    {ok, ConnPid} = gun:open("www.google.com", 443, #{
        transport => tls,
        protocols => [http2],
        tls_opts => [{verify, verify_none}],
        http2_opts => #{max_concurrent_streams => 1000}
    }),
    {ok, http2} = gun:await_up(ConnPid, 10000),

    N = 50,
    T1 = erlang:monotonic_time(millisecond),
    StreamRefs = [gun:get(ConnPid, "/") || _ <- lists:seq(1, N)],
    io:format("  Sent ~p requests on single HTTP/2 connection~n", [N]),

    Results = lists:map(fun(Ref) ->
        case gun:await(ConnPid, Ref, 15000) of
            {response, nofin, Status, _H} ->
                gun:cancel(ConnPid, Ref),
                {ok, Status};
            {response, fin, Status, _H} ->
                {ok, Status};
            {error, E} ->
                {error, E}
        end
    end, StreamRefs),
    T2 = erlang:monotonic_time(millisecond),

    Successes = length([ok || {ok, _} <- Results]),
    Errors = [E || {error, E} <- Results],
    io:format("  ~p/~p succeeded in ~pms~n", [Successes, N, T2 - T1]),
    case Errors of
        [] -> ok;
        _ -> io:format("  Errors: ~p~n", [lists:sublist(Errors, 5)])
    end,
    gun:close(ConnPid),
    ok.

%% Test 5: Concurrent scale test against localhost (HTTP/1.1)
%% Each request gets its own gun connection (no pool bottleneck)
test_concurrent_scale() ->
    lists:foreach(fun(N) ->
        Self = self(),
        T1 = erlang:monotonic_time(millisecond),
        lists:foreach(fun(I) ->
            spawn(fun() ->
                Result = try
                    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
                        protocols => [http],
                        connect_timeout => 5000
                    }),
                    {ok, _} = gun:await_up(ConnPid, 5000),
                    StreamRef = gun:get(ConnPid, "/text"),
                    Res = case gun:await(ConnPid, StreamRef, 10000) of
                        {response, nofin, 200, _H} ->
                            {ok, Body} = gun:await_body(ConnPid, StreamRef, 10000),
                            {ok, byte_size(Body)};
                        {response, fin, 200, _H} ->
                            {ok, 0};
                        Other ->
                            {error, Other}
                    end,
                    gun:close(ConnPid),
                    Res
                catch
                    _:Err -> {error, Err}
                end,
                Self ! {gun_done, N, I, Result}
            end)
        end, lists:seq(1, N)),
        Successes = lists:foldl(fun(I, Acc) ->
            receive
                {gun_done, N, I, {ok, _}} -> Acc + 1;
                {gun_done, N, I, _} -> Acc
            after 30000 -> Acc
            end
        end, 0, lists:seq(1, N)),
        T2 = erlang:monotonic_time(millisecond),
        io:format("  gun    ~p concurrent: ~p/~p in ~pms~n", [N, Successes, N, T2 - T1])
    end, [100, 500, 1000, 5000]),
    ok.

%% Test 6: Streaming response
test_streaming() ->
    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
        protocols => [http]
    }),
    {ok, _} = gun:await_up(ConnPid, 5000),
    StreamRef = gun:get(ConnPid, "/stream/10"),
    {response, nofin, Status, _Headers} = gun:await(ConnPid, StreamRef, 5000),
    io:format("  Status: ~p~n", [Status]),
    Chunks = collect_body_chunks(ConnPid, StreamRef, []),
    io:format("  Chunks received: ~p~n", [length(Chunks)]),
    TotalBytes = lists:sum([byte_size(C) || C <- Chunks]),
    io:format("  Total bytes: ~p~n", [TotalBytes]),
    gun:close(ConnPid),
    ok.

collect_body_chunks(ConnPid, StreamRef, Acc) ->
    receive
        {gun_data, ConnPid, StreamRef, nofin, Data} ->
            collect_body_chunks(ConnPid, StreamRef, [Data | Acc]);
        {gun_data, ConnPid, StreamRef, fin, Data} ->
            lists:reverse([Data | Acc])
    after 5000 ->
        lists:reverse(Acc)
    end.

%% Test 7: Cancel a stream mid-response
test_cancel_stream() ->
    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
        protocols => [http]
    }),
    {ok, _} = gun:await_up(ConnPid, 5000),
    StreamRef = gun:get(ConnPid, "/stream/slow"),
    case gun:await(ConnPid, StreamRef, 5000) of
        {response, nofin, Status, _H} ->
            io:format("  Got response status: ~p~n", [Status]),
            ok = gun:cancel(ConnPid, StreamRef),
            io:format("  Cancelled stream~n"),
            gun:flush(StreamRef),
            io:format("  Flushed remaining messages~n");
        {response, fin, Status, _H} ->
            io:format("  Got complete response: ~p~n", [Status])
    end,
    %% Verify connection is still usable after cancel
    StreamRef2 = gun:get(ConnPid, "/text"),
    case gun:await(ConnPid, StreamRef2, 5000) of
        {response, nofin, 200, _} ->
            {ok, Body} = gun:await_body(ConnPid, StreamRef2, 5000),
            io:format("  Connection still usable after cancel: ~s~n", [Body]);
        {response, fin, 200, _} ->
            io:format("  Connection still usable after cancel~n");
        {error, E} ->
            io:format("  Connection broken after cancel: ~p~n", [E])
    end,
    gun:close(ConnPid),
    ok.

%% Test 8: Error handling
test_error_handling() ->
    %% Connection refused
    T1 = erlang:monotonic_time(millisecond),
    {ok, ConnPid} = gun:open("localhost", 19999, #{
        protocols => [http],
        connect_timeout => 2000
    }),
    case gun:await_up(ConnPid, 3000) of
        {ok, _} ->
            io:format("  Unexpectedly connected~n");
        {error, Reason} ->
            T2 = erlang:monotonic_time(millisecond),
            io:format("  Connection refused: ~p in ~pms~n", [Reason, T2 - T1])
    end,
    gun:close(ConnPid),

    %% Unreachable host (connect timeout)
    io:format("  Testing connect timeout to unreachable host...~n"),
    T3 = erlang:monotonic_time(millisecond),
    {ok, ConnPid2} = gun:open("192.0.2.1", 80, #{
        protocols => [http],
        connect_timeout => 1000
    }),
    case gun:await_up(ConnPid2, 3000) of
        {ok, _} ->
            io:format("  Unexpectedly connected~n");
        {error, Reason2} ->
            T4 = erlang:monotonic_time(millisecond),
            io:format("  Timeout error: ~p in ~pms~n", [Reason2, T4 - T3])
    end,
    gun:close(ConnPid2),
    ok.

%% Test 10: Connect timeout - does gun's connect_timeout option work?
test_connect_timeout() ->
    %% Gun retries by default (retry=5, retry_timeout=5000).
    %% Disable retries to isolate connect_timeout behavior.

    %% Test 1: connect_timeout=500ms, no retries, unreachable host
    io:format("  Testing with retry=0 to isolate connect_timeout...~n"),
    T1 = erlang:monotonic_time(millisecond),
    {ok, ConnPid1} = gun:open("192.0.2.1", 80, #{
        protocols => [http],
        connect_timeout => 500,
        retry => 0
    }),
    Result1 = gun:await_up(ConnPid1, 10000),
    T2 = erlang:monotonic_time(millisecond),
    io:format("  connect_timeout=500ms, retry=0: ~p in ~pms~n", [Result1, T2 - T1]),
    gun:close(ConnPid1),

    %% Test 2: connect_timeout=2000ms, no retries
    T3 = erlang:monotonic_time(millisecond),
    {ok, ConnPid2} = gun:open("192.0.2.1", 80, #{
        protocols => [http],
        connect_timeout => 2000,
        retry => 0
    }),
    Result2 = gun:await_up(ConnPid2, 10000),
    T4 = erlang:monotonic_time(millisecond),
    io:format("  connect_timeout=2000ms, retry=0: ~p in ~pms~n", [Result2, T4 - T3]),
    gun:close(ConnPid2),

    %% Test 3: connection refused (should be instant, regardless of timeout)
    T5 = erlang:monotonic_time(millisecond),
    {ok, ConnPid3} = gun:open("localhost", 19999, #{
        protocols => [http],
        connect_timeout => 5000,
        retry => 0
    }),
    Result3 = gun:await_up(ConnPid3, 10000),
    T6 = erlang:monotonic_time(millisecond),
    io:format("  connect_timeout=5000ms, refused port, retry=0: ~p in ~pms~n",
              [Result3, T6 - T5]),
    gun:close(ConnPid3),

    %% Test 4: verify retries amplify the time (retry=2 with 500ms timeout)
    T7 = erlang:monotonic_time(millisecond),
    {ok, ConnPid4} = gun:open("192.0.2.1", 80, #{
        protocols => [http],
        connect_timeout => 500,
        retry => 2,
        retry_timeout => 100
    }),
    Result4 = gun:await_up(ConnPid4, 30000),
    T8 = erlang:monotonic_time(millisecond),
    io:format("  connect_timeout=500ms, retry=2, retry_timeout=100ms: ~p in ~pms~n",
              [Result4, T8 - T7]),
    gun:close(ConnPid4),
    ok.

%% Test 11: Auto decompression - does gun handle gzip/deflate?
test_auto_decompression() ->
    %% Request gzipped content from mock server
    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
        protocols => [http]
    }),
    {ok, _} = gun:await_up(ConnPid, 5000),

    %% Request with Accept-Encoding: gzip
    StreamRef1 = gun:get(ConnPid, "/gzip", [
        {<<"accept-encoding">>, <<"gzip">>}
    ]),
    case gun:await(ConnPid, StreamRef1, 5000) of
        {response, nofin, Status1, Headers1} ->
            {ok, Body1} = gun:await_body(ConnPid, StreamRef1, 5000),
            CE = proplists:get_value(<<"content-encoding">>, Headers1, <<"none">>),
            io:format("  With accept-encoding:gzip~n"),
            io:format("    Status: ~p~n", [Status1]),
            io:format("    Content-Encoding: ~s~n", [CE]),
            io:format("    Body size: ~p bytes~n", [byte_size(Body1)]),
            %% Check if body is still gzipped or was auto-decompressed
            IsGzipped = case Body1 of
                <<16#1f, 16#8b, _/binary>> -> true;
                _ -> false
            end,
            io:format("    Body still gzipped: ~p~n", [IsGzipped]),
            case IsGzipped of
                true ->
                    Decompressed = zlib:gunzip(Body1),
                    io:format("    Decompressed: ~s (~p bytes)~n",
                              [Decompressed, byte_size(Decompressed)]),
                    io:format("    GUN DOES NOT AUTO-DECOMPRESS~n");
                false ->
                    io:format("    Body: ~s~n", [Body1]),
                    io:format("    GUN AUTO-DECOMPRESSES~n")
            end;
        {response, fin, Status1, _} ->
            io:format("  Status: ~p (no body)~n", [Status1])
    end,

    %% Also test without accept-encoding
    StreamRef2 = gun:get(ConnPid, "/text"),
    case gun:await(ConnPid, StreamRef2, 5000) of
        {response, nofin, _Status2, _Headers2} ->
            {ok, Body2} = gun:await_body(ConnPid, StreamRef2, 5000),
            io:format("  Without accept-encoding:~n"),
            io:format("    Body: ~s~n", [Body2]);
        {response, fin, _Status2, _} ->
            io:format("  No body without accept-encoding~n")
    end,

    gun:close(ConnPid),
    ok.

%% Test 12: HTTP/2 cancel stream - connection should survive
test_h2_cancel_stream() ->
    {ok, ConnPid} = gun:open("www.google.com", 443, #{
        transport => tls,
        protocols => [http2],
        tls_opts => [{verify, verify_none}]
    }),
    {ok, http2} = gun:await_up(ConnPid, 10000),
    io:format("  Connected via HTTP/2~n"),

    %% Start a request and cancel it
    StreamRef1 = gun:get(ConnPid, "/search?q=test"),
    timer:sleep(100),
    gun:cancel(ConnPid, StreamRef1),
    gun:flush(StreamRef1),
    io:format("  Cancelled first request~n"),

    %% Now try another request on the SAME connection
    StreamRef2 = gun:get(ConnPid, "/"),
    case gun:await(ConnPid, StreamRef2, 10000) of
        {response, nofin, Status, _H} ->
            gun:cancel(ConnPid, StreamRef2),
            io:format("  Second request after cancel: status ~p~n", [Status]),
            io:format("  HTTP/2 connection SURVIVES cancel (streams are independent)~n");
        {response, fin, Status, _H} ->
            io:format("  Second request after cancel: status ~p~n", [Status]),
            io:format("  HTTP/2 connection SURVIVES cancel~n");
        {error, E} ->
            io:format("  Second request FAILED: ~p~n", [E]),
            io:format("  HTTP/2 connection BROKEN after cancel~n")
    end,
    gun:close(ConnPid),
    ok.

%% Test 9: Connection reuse - many sequential requests on one connection
test_connection_reuse() ->
    {ok, ConnPid} = gun:open(?BASE_HOST, ?BASE_PORT, #{
        protocols => [http]
    }),
    {ok, _} = gun:await_up(ConnPid, 5000),

    N = 100,
    T1 = erlang:monotonic_time(millisecond),
    Successes = lists:foldl(fun(_, Acc) ->
        StreamRef = gun:get(ConnPid, "/text"),
        case gun:await(ConnPid, StreamRef, 5000) of
            {response, nofin, 200, _} ->
                {ok, _} = gun:await_body(ConnPid, StreamRef, 5000),
                Acc + 1;
            {response, fin, 200, _} ->
                Acc + 1;
            _ ->
                Acc
        end
    end, 0, lists:seq(1, N)),
    T2 = erlang:monotonic_time(millisecond),
    io:format("  ~p/~p sequential requests on ONE connection in ~pms~n",
              [Successes, N, T2 - T1]),
    gun:close(ConnPid),
    ok.
