-module(streaming_api_sse_ffi).
-export([read_events/4]).

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
            Events = dechunk(Body),
            case length(binary:matches(Events, <<"\n\n">>)) >= EventCount of
                true -> {ok, Events};
                false -> incomplete
            end;
        [_Incomplete] ->
            incomplete
    end.

%% The server sends an event stream with chunked transfer encoding, one
%% chunk for each event. Returns the data of the complete chunks, joined, so
%% the tests read the events as an event stream client gets them.
dechunk(Body) ->
    dechunk(Body, <<>>).

dechunk(Body, Events) ->
    case binary:split(Body, <<"\r\n">>) of
        [SizeHex, Rest] ->
            Size = binary_to_integer(SizeHex, 16),
            case Rest of
                <<Chunk:Size/binary, "\r\n", More/binary>> when Size > 0 ->
                    dechunk(More, <<Events/binary, Chunk/binary>>);
                _LastOrIncomplete ->
                    Events
            end;
        [_Incomplete] ->
            Events
    end.

describe(Reason) ->
    unicode:characters_to_binary(io_lib:format("~p", [Reason])).
