%% One-shot HTTP/1.1 test server for the dream_opensearch tests.
%%
%% Each call to start/1 opens its own listening socket on 127.0.0.1 with an
%% OS-assigned port, accepts exactly one connection, reports what it received
%% to the calling process, answers as told, and exits. Nothing outlives a test:
%% the accept and receive calls time out after a few seconds.
-module(opensearch_test_server_ffi).
-export([start/1, await_request/1, await_raw_bytes/1, port/1, unused_port/0]).

-define(TIMEOUT_MS, 3000).

%% Reply is one of:
%%   {respond, Status, Body}  - answer with Status and Body, then close
%%   capture_raw_bytes        - report the first bytes received, then close
start(Reply) ->
    Parent = self(),
    Pid = spawn(fun() -> listen(Parent, Reply) end),
    receive
        {opensearch_test_server_port, Pid, Port} -> {test_server, Pid, Port}
    after ?TIMEOUT_MS -> erlang:error(test_server_did_not_start)
    end.

port({test_server, _Pid, Port}) -> Port.

await_request({test_server, Pid, _Port}) ->
    receive
        {opensearch_test_server_request, Pid, Request} -> {ok, Request}
    after ?TIMEOUT_MS -> {error, nil}
    end.

await_raw_bytes({test_server, Pid, _Port}) ->
    receive
        {opensearch_test_server_raw, Pid, Bytes} -> {ok, Bytes}
    after ?TIMEOUT_MS -> {error, nil}
    end.

%% A port on 127.0.0.1 that nothing listens on: bind it, read it, release it.
unused_port() ->
    {ok, Socket} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Socket),
    ok = gen_tcp:close(Socket),
    Port.

listen(Parent, Reply) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false},
                                      {ip, {127, 0, 0, 1}}, {reuseaddr, true}]),
    {ok, Port} = inet:port(Listen),
    Parent ! {opensearch_test_server_port, self(), Port},
    case gen_tcp:accept(Listen, ?TIMEOUT_MS) of
        {ok, Socket} ->
            handle(Parent, Reply, Socket),
            gen_tcp:close(Socket);
        {error, _} -> ok
    end,
    gen_tcp:close(Listen).

handle(Parent, capture_raw_bytes, Socket) ->
    case gen_tcp:recv(Socket, 0, ?TIMEOUT_MS) of
        {ok, Bytes} -> Parent ! {opensearch_test_server_raw, self(), Bytes};
        {error, _} -> ok
    end;
handle(Parent, Reply, Socket) ->
    case read_head(Socket, <<>>) of
        {ok, Head, Rest} ->
            {Method, Target, Headers} = parse_head(Head),
            Body = read_body(Socket, Rest, content_length(Headers)),
            Parent ! {opensearch_test_server_request, self(),
                      {captured_request, Method, Target, Headers, Body}},
            answer(Reply, Socket);
        {error, _} -> ok
    end.

answer({respond, Status, Body}, Socket) ->
    Response = [<<"HTTP/1.1 ">>, integer_to_binary(Status), <<" Test\r\n">>,
                <<"content-type: application/json\r\n">>,
                <<"content-length: ">>, integer_to_binary(byte_size(Body)),
                <<"\r\nconnection: close\r\n\r\n">>, Body],
    gen_tcp:send(Socket, Response).

read_head(Socket, Buffer) ->
    case binary:split(Buffer, <<"\r\n\r\n">>) of
        [Head, Rest] -> {ok, Head, Rest};
        [_] ->
            case gen_tcp:recv(Socket, 0, ?TIMEOUT_MS) of
                {ok, More} -> read_head(Socket, <<Buffer/binary, More/binary>>);
                Error -> Error
            end
    end.

parse_head(Head) ->
    [RequestLine | HeaderLines] = binary:split(Head, <<"\r\n">>, [global]),
    {Method, Target} = parse_request_line(RequestLine),
    {Method, Target, [parse_header(Line) || Line <- HeaderLines]}.

%% "METHOD TARGET HTTP/1.1": the target is everything between the first and
%% the last space, so a target that holds a raw space is still reported whole.
parse_request_line(Line) ->
    [Method, AfterMethod] = binary:split(Line, <<" ">>),
    {Start, _} = lists:last(binary:matches(AfterMethod, <<" ">>)),
    {Method, binary:part(AfterMethod, 0, Start)}.

parse_header(Line) ->
    [Name, Value] = binary:split(Line, <<":">>),
    {string:lowercase(Name), string:trim(Value)}.

content_length(Headers) ->
    case lists:keyfind(<<"content-length">>, 1, Headers) of
        {_, Value} -> binary_to_integer(Value);
        false -> 0
    end.

read_body(_Socket, Received, Length) when byte_size(Received) >= Length ->
    binary:part(Received, 0, Length);
read_body(Socket, Received, Length) ->
    case gen_tcp:recv(Socket, 0, ?TIMEOUT_MS) of
        {ok, More} -> read_body(Socket, <<Received/binary, More/binary>>, Length);
        {error, _} -> Received
    end.
