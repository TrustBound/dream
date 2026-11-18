-module(websockets_guide_test_ffi).
-export([send_text_and_receive/5]).

%% Opens a WebSocket to 127.0.0.1:Port at Path with the extra Headers (a list
%% of {Name, Value} binaries), sends Text in one masked text frame, and
%% returns the payload of the first text frame the server sends back. If the
%% server does not answer 101, it returns {error, StatusLine}. Other errors
%% come back as {error, Description} with a binary.
send_text_and_receive(Port, Path, Headers, Text, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}, {nodelay, true}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Result = exchange(Socket, Path, Headers, Text, Timeout),
            gen_tcp:close(Socket),
            Result;
        {error, Reason} ->
            describe(connect, Reason)
    end.

exchange(Socket, Path, Headers, Text, Timeout) ->
    Extra = [[Name, <<": ">>, Value, <<"\r\n">>] || {Name, Value} <- Headers],
    Handshake = [<<"GET ">>, Path, <<" HTTP/1.1\r\n">>,
                 <<"Host: localhost\r\n">>,
                 <<"Upgrade: websocket\r\n">>,
                 <<"Connection: Upgrade\r\n">>,
                 <<"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n">>,
                 <<"Sec-WebSocket-Version: 13\r\n">>,
                 Extra, <<"\r\n">>],
    ok = gen_tcp:send(Socket, Handshake),
    case read_headers(Socket, Timeout, <<>>) of
        {ok, <<"HTTP/1.1 101", _/binary>>, Rest} ->
            ok = gen_tcp:send(Socket, masked_text_frame(Text)),
            read_text_frame(Socket, Timeout, Rest);
        {ok, Head, _Rest} ->
            [StatusLine | _] = binary:split(Head, <<"\r\n">>),
            {error, StatusLine};
        {error, Reason} ->
            describe(handshake, Reason)
    end.

read_headers(Socket, Timeout, Acc) ->
    case binary:split(Acc, <<"\r\n\r\n">>) of
        [Head, Rest] ->
            {ok, Head, Rest};
        [_] ->
            case gen_tcp:recv(Socket, 0, Timeout) of
                {ok, Data} -> read_headers(Socket, Timeout, <<Acc/binary, Data/binary>>);
                {error, Reason} -> {error, Reason}
            end
    end.

masked_text_frame(Text) when byte_size(Text) < 126 ->
    Mask = <<1, 2, 3, 4>>,
    <<1:1, 0:3, 1:4, 1:1, (byte_size(Text)):7, Mask/binary,
      (apply_mask(Text, Mask))/binary>>.

apply_mask(Data, <<M1, M2, M3, M4>>) ->
    Keys = {M1, M2, M3, M4},
    Bytes = binary_to_list(Data),
    Indexed = lists:zip(lists:seq(0, length(Bytes) - 1), Bytes),
    list_to_binary([B bxor element((I rem 4) + 1, Keys) || {I, B} <- Indexed]).

read_text_frame(_Socket, _Timeout, <<_Fin:1, _:3, 1:4, 0:1, Len:7, Rest/binary>>)
  when Len < 126, byte_size(Rest) >= Len ->
    <<Payload:Len/binary, _/binary>> = Rest,
    {ok, Payload};
read_text_frame(Socket, Timeout, Acc) ->
    case gen_tcp:recv(Socket, 0, Timeout) of
        {ok, Data} -> read_text_frame(Socket, Timeout, <<Acc/binary, Data/binary>>);
        {error, Reason} -> describe(frame, Reason)
    end.

describe(Stage, Reason) ->
    {error, iolist_to_binary(io_lib:format("~p: ~p", [Stage, Reason]))}.
