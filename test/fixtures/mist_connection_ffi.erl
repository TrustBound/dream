-module(mist_connection_ffi).
-export([closed_connection/1, open_connection/2, ipv6_connection/0,
         ipv4_mapped_connection/0,
         start_refusing_factory/0, start_accepting_factory/0, stop_factory/1,
         close_socket/1, close_connection_socket/1]).

%% Builds the connection value that mist gives a handler, so a test can call
%% dream's server code without a running server. The tuple follows the
%% Connection record of mist/internal/http:
%% {connection, Body, Socket, Transport, FactoryName, ReadTimeout,
%%  ChunkProcess}. Body is {initial, Data}: the bytes of the request body
%% that mist read with the head.

-define(READ_TIMEOUT_MS, 1000).

%% A connection whose socket is already closed. Every read and write on it
%% fails.
closed_connection(Data) ->
    {Listen, Client, Server} = socket_pair(inet, {127, 0, 0, 1}),
    ok = gen_tcp:close(Client),
    ok = gen_tcp:close(Server),
    ok = gen_tcp:close(Listen),
    connection(Data, Server, unregistered_name()).

%% A connection with an open socket. Returns the connection and the client
%% end of the socket, which the test closes.
open_connection(Data, FactoryName) ->
    {Listen, Client, Server} = socket_pair(inet, {127, 0, 0, 1}),
    ok = gen_tcp:close(Listen),
    {connection(Data, Server, FactoryName), Client}.

%% A connection that a client made from the IPv6 loopback address ::1.
ipv6_connection() ->
    case gen_tcp:listen(0, [binary, inet6, {ip, {0, 0, 0, 0, 0, 0, 0, 1}},
                            {active, false}]) of
        {ok, Listen} ->
            {ok, Port} = inet:port(Listen),
            {ok, Client} = gen_tcp:connect({0, 0, 0, 0, 0, 0, 0, 1}, Port,
                                           [binary, inet6, {active, false}]),
            {ok, Server} = gen_tcp:accept(Listen),
            ok = gen_tcp:close(Listen),
            {ok, {connection(<<>>, Server, unregistered_name()), Client}};
        {error, Reason} ->
            {error, unicode:characters_to_binary(
                      io_lib:format("IPv6 loopback is not available: ~p",
                                    [Reason]))}
    end.

%% A connection that a client made from 127.0.0.1 to an IPv6 socket that
%% also takes IPv4 clients, so the peer address is ::ffff:127.0.0.1.
ipv4_mapped_connection() ->
    MappedLoopback = {0, 0, 0, 0, 0, 16#ffff, 16#7f00, 1},
    case gen_tcp:listen(0, [binary, inet6, {ipv6_v6only, false},
                            {ip, MappedLoopback}, {active, false}]) of
        {ok, Listen} ->
            {ok, Port} = inet:port(Listen),
            {ok, Client} = gen_tcp:connect({127, 0, 0, 1}, Port,
                                           [binary, inet, {active, false}]),
            {ok, Server} = gen_tcp:accept(Listen),
            ok = gen_tcp:close(Listen),
            {ok, {connection(<<>>, Server, unregistered_name()), Client}};
        {error, Reason} ->
            {error, unicode:characters_to_binary(
                      io_lib:format("IPv4-mapped listen is not available: ~p",
                                    [Reason]))}
    end.

%% A registered process that answers every supervisor:start_child/2 call
%% with an error, like a factory supervisor that cannot start a child.
start_refusing_factory() ->
    start_factory(fun(_Arguments) -> {error, start_refused} end).

%% A registered process that answers supervisor:start_child/2 like the
%% factory supervisor of mist: it calls the start function it gets.
start_accepting_factory() ->
    start_factory(fun([Start]) ->
        case Start() of
            {ok, {started, Pid, Data}} -> {ok, Pid, Data};
            {error, Reason} -> {error, Reason}
        end
    end).

stop_factory(Name) ->
    case whereis(Name) of
        undefined ->
            nil;
        Pid ->
            Ref = erlang:monitor(process, Pid),
            Pid ! stop,
            receive
                {'DOWN', Ref, process, Pid, _Reason} -> nil
            end
    end.

close_socket(Socket) ->
    ok = gen_tcp:close(Socket),
    nil.

%% Closes the server end of the socket of a connection, as if the client
%% went away. Closing it again does nothing.
close_connection_socket(Connection) ->
    ok = gen_tcp:close(element(3, Connection)),
    nil.

start_factory(Answer) ->
    Name = unregistered_name(),
    Parent = self(),
    Pid = spawn(fun() ->
        true = register(Name, self()),
        Parent ! {self(), registered},
        factory_loop(Answer)
    end),
    receive
        {Pid, registered} -> Name
    end.

factory_loop(Answer) ->
    receive
        {'$gen_call', From, {start_child, Arguments}} ->
            gen:reply(From, Answer(Arguments)),
            factory_loop(Answer);
        stop ->
            ok
    end.

socket_pair(Family, Address) ->
    Options = [binary, Family, {ip, Address}, {active, false}],
    {ok, Listen} = gen_tcp:listen(0, Options),
    {ok, Port} = inet:port(Listen),
    {ok, Client} = gen_tcp:connect(Address, Port, [binary, Family,
                                                   {active, false}]),
    {ok, Server} = gen_tcp:accept(Listen),
    {Listen, Client, Server}.

%% Mist tells ChunkProcess when a chunked response starts and stops. The
%% tests do not read these messages, so a short-lived process takes them.
connection(Data, Socket, FactoryName) ->
    Sink = spawn(fun() -> timer:sleep(5000) end),
    ChunkProcess = {subject, Sink, make_ref()},
    {connection, {initial, Data}, Socket, tcp, FactoryName, ?READ_TIMEOUT_MS,
     ChunkProcess}.

unregistered_name() ->
    list_to_atom("dream_test_factory_" ++
                 integer_to_list(erlang:unique_integer([positive]))).
