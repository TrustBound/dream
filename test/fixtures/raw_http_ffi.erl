-module(raw_http_ffi).
-export([request_until_closed/3, free_port/0, read_events/4, exchange/3]).

%% Sends Payload to 127.0.0.1:Port in one TCP packet, then reads until the
%% server closes the socket or Timeout milliseconds pass with no data.
%% Returns every byte the server wrote, so a test can see bytes that an
%% HTTP client would silently leave behind on the connection.
request_until_closed(Port, Payload, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}, {nodelay, true}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            case gen_tcp:send(Socket, Payload) of
                ok ->
                    Received = read_until_closed(Socket, Timeout, <<>>),
                    gen_tcp:close(Socket),
                    {ok, Received};
                {error, Reason} ->
                    gen_tcp:close(Socket),
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

read_until_closed(Socket, Timeout, Acc) ->
    case gen_tcp:recv(Socket, 0, Timeout) of
        {ok, Data} ->
            read_until_closed(Socket, Timeout, <<Acc/binary, Data/binary>>);
        {error, _Reason} ->
            Acc
    end.

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

%% Sends Request to 127.0.0.1:Port and reads exactly one HTTP/1.1 response:
%% the header block, then content-length bytes or a chunked body to its last
%% chunk. Returns {ok, Body} as soon as the body is complete, so the normal
%% path never waits for the server to close the socket. Timeout only limits
%% how long one read can wait when the server stops sending.
exchange(Port, Request, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}, {nodelay, true}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Result = case gen_tcp:send(Socket, Request) of
                ok -> read_head(Socket, Timeout, <<>>);
                {error, Reason} -> {error, describe(Reason)}
            end,
            gen_tcp:close(Socket),
            Result;
        {error, Reason} ->
            {error, describe(Reason)}
    end.

read_head(Socket, Timeout, Received) ->
    case binary:split(Received, <<"\r\n\r\n">>) of
        [Head, Rest] -> read_body(Socket, Timeout, body_framing(Head), Rest);
        [_Incomplete] ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} -> read_head(Socket, Timeout, <<Received/binary, Data/binary>>);
                {error, Reason} -> {error, <<"no complete header block: ", (describe(Reason))/binary>>}
            end
    end.

body_framing(Head) ->
    Lines = binary:split(string:lowercase(Head), <<"\r\n">>, [global]),
    case lists:member(<<"transfer-encoding: chunked">>, Lines) of
        true -> chunked;
        false -> {length, content_length(Lines)}
    end.

content_length([<<"content-length: ", Value/binary>> | _]) -> binary_to_integer(Value);
content_length([_ | Rest]) -> content_length(Rest);
content_length([]) -> 0.

read_body(Socket, Timeout, {length, Length}, Received) when byte_size(Received) < Length ->
    case recv_more(Socket, Timeout, Received) of
        {ok, More} -> read_body(Socket, Timeout, {length, Length}, More);
        Error -> Error
    end;
read_body(_Socket, _Timeout, {length, Length}, Received) ->
    {ok, binary:part(Received, 0, Length)};
read_body(Socket, Timeout, chunked, Received) ->
    read_chunks(Socket, Timeout, Received, <<>>).

%% Decodes chunks from Received; reads more bytes whenever a chunk is not
%% complete yet. Stops at the zero-size last chunk.
read_chunks(Socket, Timeout, Received, Body) ->
    case binary:split(Received, <<"\r\n">>) of
        [SizeLine, Rest] ->
            Size = binary_to_integer(hd(binary:split(SizeLine, <<";">>)), 16),
            read_chunk(Socket, Timeout, Size, SizeLine, Rest, Received, Body);
        [_Incomplete] ->
            more_chunks(Socket, Timeout, Received, Body)
    end.

read_chunk(_Socket, _Timeout, 0, _SizeLine, _Rest, _Received, Body) ->
    {ok, Body};
read_chunk(Socket, Timeout, Size, _SizeLine, Rest, Received, Body) ->
    case Rest of
        <<Chunk:Size/binary, "\r\n", After/binary>> ->
            read_chunks(Socket, Timeout, After, <<Body/binary, Chunk/binary>>);
        _ ->
            more_chunks(Socket, Timeout, Received, Body)
    end.

more_chunks(Socket, Timeout, Received, Body) ->
    case recv_more(Socket, Timeout, Received) of
        {ok, More} -> read_chunks(Socket, Timeout, More, Body);
        Error -> Error
    end.

recv_more(Socket, Timeout, Received) ->
    case gen_tcp:recv(Socket, 0, Timeout) of
        {ok, Data} -> {ok, <<Received/binary, Data/binary>>};
        {error, Reason} -> {error, <<"response body cut short: ", (describe(Reason))/binary>>}
    end.
