-module(streaming_api_sse_ffi).
-export([free_port/0, read_events/4]).

%% Asks the operating system for a free TCP port, so that tests that run at
%% the same time on this machine do not use the same port.
free_port() ->
    {ok, Listen} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    ok = gen_tcp:close(Listen),
    Port.

%% Sends Request to 127.0.0.1:Port, then reads until the response body (the
%% bytes after the header block) holds EventCount complete SSE events. It
%% returns that body and closes the socket. Timeout only limits how long one
%% read can wait; the function returns as soon as the events are there.
read_events(Port, Request, EventCount, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Result = case gen_tcp:send(Socket, Request) of
                ok -> read_until_events(Socket, EventCount, Timeout, <<>>);
                {error, Reason} -> {error, describe(Reason)}
            end,
            gen_tcp:close(Socket),
            Result;
        {error, Reason} ->
            {error, describe(Reason)}
    end.

read_until_events(Socket, EventCount, Timeout, Received) ->
    case complete_body(Received, EventCount) of
        {ok, Body} ->
            {ok, Body};
        incomplete ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} ->
                    read_until_events(Socket, EventCount, Timeout,
                                      <<Received/binary, Data/binary>>);
                {error, Reason} ->
                    {error, describe(Reason)}
            end
    end.

complete_body(Received, EventCount) ->
    case binary:split(Received, <<"\r\n\r\n">>) of
        [_Headers, Body] ->
            case length(binary:matches(Body, <<"\n\n">>)) >= EventCount of
                true -> {ok, Body};
                false -> incomplete
            end;
        [_Incomplete] ->
            incomplete
    end.

describe(Reason) ->
    unicode:characters_to_binary(io_lib:format("~p", [Reason])).
