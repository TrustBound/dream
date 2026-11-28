-module(websocket_client_ffi).
-export([binary_exchange/4, connect_and_close/3]).

%% A small WebSocket client for tests. Every error comes back as
%% {error, Description} with a binary.

%% Opens a WebSocket to 127.0.0.1:Port at Path, sends Data in one masked
%% binary frame, and returns {Opcode, Payload} of the first frame the server
%% sends back (1 is text, 2 is binary).
binary_exchange(Port, Path, Data, Timeout) ->
    case open(Port, Path, Timeout) of
        {ok, Socket, Rest} ->
            Result = case gen_tcp:send(Socket, masked_frame(2, Data)) of
                ok -> read_frame(Socket, Timeout, Rest);
                {error, Reason} -> describe(send, Reason)
            end,
            gen_tcp:close(Socket),
            Result;
        {error, Description} ->
            {error, Description}
    end.

%% Opens a WebSocket to 127.0.0.1:Port at Path, then closes the TCP
%% connection without a close frame, as a client that goes away does.
connect_and_close(Port, Path, Timeout) ->
    case open(Port, Path, Timeout) of
        {ok, Socket, _Rest} ->
            ok = gen_tcp:close(Socket),
            {ok, nil};
        {error, Description} ->
            {error, Description}
    end.

open(Port, Path, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}, {nodelay, true}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Handshake = [<<"GET ">>, Path, <<" HTTP/1.1\r\n">>,
                         <<"Host: localhost\r\n">>,
                         <<"Upgrade: websocket\r\n">>,
                         <<"Connection: Upgrade\r\n">>,
                         <<"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n">>,
                         <<"Sec-WebSocket-Version: 13\r\n\r\n">>],
            ok = gen_tcp:send(Socket, Handshake),
            case read_head(Socket, Timeout, <<>>) of
                {ok, <<"HTTP/1.1 101", _/binary>>, Rest} ->
                    {ok, Socket, Rest};
                {ok, Head, _Rest} ->
                    gen_tcp:close(Socket),
                    {error, <<"expected 101, got: ", Head/binary>>};
                {error, Reason} ->
                    gen_tcp:close(Socket),
                    describe(handshake, Reason)
            end;
        {error, Reason} ->
            describe(connect, Reason)
    end.

read_head(Socket, Timeout, Acc) ->
    case binary:split(Acc, <<"\r\n\r\n">>) of
        [Head, Rest] ->
            {ok, Head, Rest};
        [_] ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} -> read_head(Socket, Timeout, <<Acc/binary, Data/binary>>);
                {error, Reason} -> {error, Reason}
            end
    end.

masked_frame(Opcode, Data) when byte_size(Data) < 126 ->
    Mask = <<1, 2, 3, 4>>,
    <<1:1, 0:3, Opcode:4, 1:1, (byte_size(Data)):7, Mask/binary,
      (apply_mask(Data, Mask))/binary>>.

apply_mask(Data, <<M1, M2, M3, M4>>) ->
    Keys = {M1, M2, M3, M4},
    Bytes = binary_to_list(Data),
    Indexed = lists:zip(lists:seq(0, length(Bytes) - 1), Bytes),
    list_to_binary([B bxor element((I rem 4) + 1, Keys) || {I, B} <- Indexed]).

read_frame(_Socket, _Timeout, <<_Fin:1, _:3, Opcode:4, 0:1, Len:7, Rest/binary>>)
  when Len < 126, byte_size(Rest) >= Len ->
    <<Payload:Len/binary, _/binary>> = Rest,
    {ok, {Opcode, Payload}};
read_frame(Socket, Timeout, Acc) ->
    case gen_tcp:recv(Socket, 0, Timeout) of
        {ok, Data} -> read_frame(Socket, Timeout, <<Acc/binary, Data/binary>>);
        {error, Reason} -> describe(frame, Reason)
    end.

describe(Stage, Reason) ->
    {error, unicode:characters_to_binary(
              io_lib:format("~p failed: ~p", [Stage, Reason]))}.
