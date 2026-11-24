-module(graceful_stop_ffi).
-behaviour(gen_event).
-export([server_pid/1, request/3, open_idle/2, closed_within/2, connect/1, now_ms/0,
         start_signal_manager/1, stop_signal_manager/1, notify/2]).
-export([init/1, handle_event/2, handle_call/2, terminate/2]).

%% Sends Request to 127.0.0.1:Port and reads one response, as a client does:
%% it reads the body that content-length gives and then closes the
%% connection. It gives the bytes it read, also when the server closes the
%% connection first or Timeout milliseconds pass with no data.
request(Port, Request, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}],
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout),
    ok = gen_tcp:send(Socket, Request),
    Received = read_response(Socket, Timeout, <<>>),
    gen_tcp:close(Socket),
    Received.

read_response(Socket, Timeout, Received) ->
    case is_complete(Received) of
        true ->
            Received;
        false ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} ->
                    read_response(Socket, Timeout, <<Received/binary, Data/binary>>);
                {error, _ClosedOrTimeout} ->
                    Received
            end
    end.

is_complete(Received) ->
    case binary:split(Received, <<"\r\n\r\n">>) of
        [Head, Body] ->
            case re:run(Head, <<"(?i)\r\ncontent-length: *([0-9]+)">>,
                        [{capture, all_but_first, binary}]) of
                {match, [Length]} -> byte_size(Body) >= binary_to_integer(Length);
                nomatch -> false
            end;
        [_Head] ->
            false
    end.

%% Sends Request to 127.0.0.1:Port and reads one response. The connection
%% stays open: the server keeps it as an idle keep-alive connection.
open_idle(Port, Request) ->
    Options = [binary, {active, false}, {packet, raw}],
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port, Options, 2000),
    ok = gen_tcp:send(Socket, Request),
    {ok, _Response} = gen_tcp:recv(Socket, 0, 2000),
    Socket.

%% True when the server closes Socket within Timeout milliseconds.
closed_within(Socket, Timeout) ->
    Result = case gen_tcp:recv(Socket, 0, Timeout) of
        {error, closed} -> true;
        _DataOrTimeout -> false
    end,
    gen_tcp:close(Socket),
    Result.

%% Opens a connection to 127.0.0.1:Port and gives the result as a string:
%% "connected" or the reason, for example "econnrefused".
connect(Port) ->
    Options = [binary, {active, false}, {packet, raw}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, 1000) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            <<"connected">>;
        {error, Reason} ->
            atom_to_binary(Reason)
    end.

%% The supervisor pid in a dream ServerHandle, which is opaque to a test.
server_pid({server_handle, Pid}) ->
    Pid.

now_ms() ->
    erlang:monotonic_time(millisecond).

%% A gen_event manager in place of erl_signal_server. Its one handler, this
%% module, takes the place of erl_signal_handler: it sends each event it gets
%% to Subject.
start_signal_manager(Subject) ->
    {ok, Manager} = gen_event:start(),
    ok = gen_event:add_handler(Manager, ?MODULE, Subject),
    Manager.

stop_signal_manager(Manager) ->
    gen_event:stop(Manager),
    nil.

notify(Manager, Event) ->
    gen_event:notify(Manager, Event),
    nil.

init(Subject) ->
    {ok, Subject}.

handle_event(Event, Subject) ->
    gleam@erlang@process:send(Subject, Event),
    {ok, Subject}.

handle_call(_Request, Subject) ->
    {ok, nil, Subject}.

%% A swap of this handler gives Subject to the new handler.
terminate(_Reason, Subject) ->
    Subject.
