-module(h2c_ffi).
-export([h2c_connect/1, h2c_connect_raw/1, h2c_send_headers/4,
         h2c_send_frame/2, h2c_recv_frame/2, h2c_send_ping/2, h2c_close/1]).

recv_frame_internal(Socket, Timeout) ->
    {ok, Header} = gen_tcp:recv(Socket, 9, Timeout),
    <<Len:24, Type:8, Flags:8, _R:1, StreamId:31>> = Header,
    Payload = case Len of
        0 -> <<>>;
        _ ->
            {ok, P} = gen_tcp:recv(Socket, Len, Timeout),
            P
    end,
    {Type, Flags, StreamId, Payload}.

h2c_connect(Port) ->
    timer:sleep(50),
    {ok, Socket} = gen_tcp:connect({127,0,0,1}, Port, [binary, {active, false}]),
    Preface = <<"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n">>,
    ClientSettings = <<0:24, 4:8, 0:8, 0:32>>,
    ok = gen_tcp:send(Socket, <<Preface/binary, ClientSettings/binary>>),
    {4, _, 0, _} = recv_frame_internal(Socket, 5000),
    ok = gen_tcp:send(Socket, <<0:24, 4:8, 1:8, 0:32>>),
    {4, 1, 0, _} = recv_frame_internal(Socket, 5000),
    Socket.

h2c_connect_raw(Port) ->
    timer:sleep(50),
    {ok, Socket} = gen_tcp:connect({127,0,0,1}, Port, [binary, {active, false}]),
    ok = gen_tcp:send(Socket, <<"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n">>),
    Socket.

h2c_send_headers(Socket, StreamId, Headers, EndStream) ->
    Context = hpack:new_context(4096),
    {ok, {HeaderBlock, _NewContext}} = hpack:encode(Headers, Context),
    Len = byte_size(HeaderBlock),
    Flags = case EndStream of
        true -> 5;
        false -> 4
    end,
    Frame = <<Len:24, 1:8, Flags:8, 0:1, StreamId:31, HeaderBlock/binary>>,
    ok = gen_tcp:send(Socket, Frame),
    nil.

h2c_send_frame(Socket, FrameBytes) ->
    ok = gen_tcp:send(Socket, FrameBytes),
    nil.

h2c_recv_frame(Socket, Timeout) ->
    recv_frame_internal(Socket, Timeout).

h2c_send_ping(Socket, Data) ->
    Frame = <<8:24, 6:8, 0:8, 0:32, Data/binary>>,
    ok = gen_tcp:send(Socket, Frame),
    nil.

h2c_close(Socket) ->
    gen_tcp:close(Socket),
    nil.
