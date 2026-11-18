-module(sse_guide_test_ffi).
-export([open_stream/3, read_until_events/4, close/1]).

%% Connects to 127.0.0.1:Port and sends a GET request for an event stream.
open_stream(Port, Path, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Request = [<<"GET ">>, Path, <<" HTTP/1.1\r\n">>,
                       <<"Host: localhost\r\n">>,
                       <<"Accept: text/event-stream\r\n\r\n">>],
            case gen_tcp:send(Socket, Request) of
                ok -> {ok, Socket};
                {error, Reason} ->
                    gen_tcp:close(Socket),
                    {error, describe(Reason)}
            end;
        {error, Reason} ->
            {error, describe(Reason)}
    end.

%% Reads from Socket until the response body (the bytes after the header
%% block) in Received holds EventCount complete SSE events, and returns all
%% the bytes received so far. Timeout only limits how long one read waits.
read_until_events(Socket, Received, EventCount, Timeout) ->
    case has_events(Received, EventCount) of
        true ->
            {ok, Received};
        false ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} ->
                    read_until_events(Socket, <<Received/binary, Data/binary>>,
                                      EventCount, Timeout);
                {error, Reason} ->
                    {error, describe(Reason)}
            end
    end.

close(Socket) ->
    gen_tcp:close(Socket),
    nil.

has_events(Received, EventCount) ->
    case binary:split(Received, <<"\r\n\r\n">>) of
        [_Headers, Body] -> length(binary:matches(Body, <<"\n\n">>)) >= EventCount;
        [_Incomplete] -> false
    end.

describe(Reason) ->
    unicode:characters_to_binary(io_lib:format("~p", [Reason])).
