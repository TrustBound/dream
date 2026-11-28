-module(beam_guide_test_ffi).
-export([message_queue_len/1, heap_words/1, referenced_byte_size/1,
         catch_crash/1, time_warp_mode/0, atom_limit/0, reductions_of/1,
         run_with_heap_limit/2, get_on_new_connection/2,
         get_twice_on_one_connection/2]).

%% Measurements for the tests of docs/guides/beam.md. Each one reads a
%% number that the runtime keeps, so a test can show what the guide says.

%% The number of messages in the mailbox of Pid. The request is a signal
%% from the caller to Pid, so the count includes each message that the
%% caller sent to Pid before this call.
message_queue_len(Pid) ->
    {message_queue_len, Length} = erlang:process_info(Pid, message_queue_len),
    Length.

%% The size of Term in the heap of the calling process, in machine words.
%% The bytes of a large binary are outside the heap, so they do not count.
heap_words(Term) ->
    erts_debug:size(Term).

%% The size of the binary that Bits points into. A slice of a large binary
%% points into the whole binary, so this is the size of the whole binary.
referenced_byte_size(Bits) ->
    binary:referenced_byte_size(Bits).

%% Calls Fun. Returns {ok, Value} when it returns, or {error, Message} when
%% it raises a Gleam error, such as a panic or a failed let assert.
catch_crash(Fun) ->
    try
        {ok, Fun()}
    catch
        error:#{gleam_error := _, message := Message} ->
            {error, Message}
    end.

%% How the runtime moves system time when the clock of the machine
%% changes, as a binary. In multi_time_warp mode, system time can move
%% forwards and backwards at any time.
time_warp_mode() ->
    atom_to_binary(erlang:system_info(time_warp_mode)).

%% The largest number of atoms that the runtime can hold.
atom_limit() ->
    erlang:system_info(atom_limit).

%% Runs Fun in a new process, and returns the reductions that the process
%% used. A reduction is a unit of work of the scheduler, so a function that
%% does more work uses more reductions.
reductions_of(Fun) ->
    Parent = self(),
    {Pid, Monitor} = spawn_monitor(fun() ->
        _ = Fun(),
        {reductions, Reductions} = erlang:process_info(self(), reductions),
        Parent ! {self(), Reductions}
    end),
    receive
        {Pid, Reductions} ->
            erlang:demonitor(Monitor, [flush]),
            Reductions;
        {'DOWN', Monitor, process, Pid, Reason} ->
            erlang:error({reductions_of_failed, Reason})
    end.

%% Runs Fun in a new process whose heap, with its stack, can hold at most
%% Words machine words. Returns {ok, Value} when Fun returns, or
%% {error, nil} when the runtime stops the process at the limit. The
%% runtime logs nothing for the stop.
run_with_heap_limit(Fun, Words) ->
    Parent = self(),
    Limit = #{size => Words, kill => true, error_logger => false},
    {Pid, Monitor} = spawn_opt(fun() -> Parent ! {self(), Fun()} end,
                               [monitor, {max_heap_size, Limit}]),
    receive
        {Pid, Value} ->
            erlang:demonitor(Monitor, [flush]),
            {ok, Value};
        {'DOWN', Monitor, process, Pid, killed} ->
            {error, nil}
    end.

%% Sends GET Path to 127.0.0.1:Port on a new connection, reads one
%% response, and closes the connection. Returns {Status, Body}.
get_on_new_connection(Port, Path) ->
    {ok, Socket} = connect(Port),
    Response = exchange(Socket, Path),
    gen_tcp:close(Socket),
    Response.

%% Sends GET Path two times on one keep-alive connection, one request after
%% the other, and closes the connection. Returns the two bodies.
get_twice_on_one_connection(Port, Path) ->
    {ok, Socket} = connect(Port),
    {_, First} = exchange(Socket, Path),
    {_, Second} = exchange(Socket, Path),
    gen_tcp:close(Socket),
    {First, Second}.

connect(Port) ->
    gen_tcp:connect({127, 0, 0, 1}, Port, [binary, {active, false}], 5000).

exchange(Socket, Path) ->
    Request = [<<"GET ">>, Path, <<" HTTP/1.1\r\nhost: localhost\r\n\r\n">>],
    ok = gen_tcp:send(Socket, Request),
    read_response(Socket, <<>>).

%% Reads one response with a content-length body.
read_response(Socket, Received) ->
    case binary:split(Received, <<"\r\n\r\n">>) of
        [Head, Body] ->
            Length = content_length(Head),
            case byte_size(Body) >= Length of
                true -> {status(Head), binary:part(Body, 0, Length)};
                false -> read_more(Socket, Received)
            end;
        [_] ->
            read_more(Socket, Received)
    end.

read_more(Socket, Received) ->
    {ok, Data} = gen_tcp:recv(Socket, 0, 5000),
    read_response(Socket, <<Received/binary, Data/binary>>).

status(<<"HTTP/1.1 ", Code:3/binary, _/binary>>) ->
    binary_to_integer(Code).

content_length(Head) ->
    {match, [Length]} = re:run(Head, "(?i)\r\ncontent-length: *([0-9]+)",
                               [{capture, all_but_first, binary}]),
    binary_to_integer(Length).
