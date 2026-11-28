-module(doc_server_ffi).
-export([hold_port/0, release_port/1, websocket_exchange/4]).

%% Opens a listener on a free port and returns {Port, Listener}. The port
%% stays in use until release_port/1 closes the listener. The port is claimed
%% in the port_ffi registry, so port_ffi:free_port/0 never gives it to another
%% test, also after release_port/1.
hold_port() ->
    hold_port([]).

hold_port(Rejected) ->
    {ok, Listen} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    case port_ffi:claim(Port) of
        true ->
            lists:foreach(fun gen_tcp:close/1, Rejected),
            {Port, Listen};
        false ->
            hold_port([Listen | Rejected])
    end.

release_port(Listen) ->
    gen_tcp:close(Listen),
    nil.

%% Opens a WebSocket to 127.0.0.1:Port at Path, sends Text in one masked text
%% frame, and returns {Opcode, Payload} of the first frame the server sends
%% back (1 is text, 2 is binary). Every error comes back as
%% {error, Description} with a binary.
websocket_exchange(Port, Path, Text, Timeout) ->
    Options = [binary, {active, false}, {packet, raw}, {nodelay, true}],
    case gen_tcp:connect({127, 0, 0, 1}, Port, Options, Timeout) of
        {ok, Socket} ->
            Result = exchange(Socket, Path, Text, Timeout),
            gen_tcp:close(Socket),
            Result;
        {error, Reason} ->
            describe(connect, Reason)
    end.

exchange(Socket, Path, Text, Timeout) ->
    Handshake = [<<"GET ">>, Path, <<" HTTP/1.1\r\n">>,
                 <<"Host: localhost\r\n">>,
                 <<"Upgrade: websocket\r\n">>,
                 <<"Connection: Upgrade\r\n">>,
                 <<"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n">>,
                 <<"Sec-WebSocket-Version: 13\r\n\r\n">>],
    ok = gen_tcp:send(Socket, Handshake),
    case read_headers(Socket, Timeout, <<>>) of
        {ok, <<"HTTP/1.1 101", _/binary>>, Rest} ->
            ok = gen_tcp:send(Socket, masked_text_frame(Text)),
            read_frame(Socket, Timeout, Rest);
        {ok, Head, _Rest} ->
            {error, <<"expected 101, got: ", Head/binary>>};
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
    {error, iolist_to_binary(io_lib:format("~p: ~p", [Stage, Reason]))}.
