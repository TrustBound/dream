-module(tls_server_ffi).
-export([start_once/0]).

start_once() ->
    {ok, _} = application:ensure_all_started(ssl),
    {ok, Listener} = ssl:listen(0, [binary, {active, false}, {reuseaddr, true},
        {certfile, "test/fixtures/tls_server.pem"},
        {keyfile, "test/fixtures/tls_server.key"}]),
    {ok, {_Address, Port}} = ssl:sockname(Listener),
    spawn(fun() -> serve_once(Listener) end),
    Port.

serve_once(Listener) ->
    case ssl:transport_accept(Listener, 5000) of
        {ok, Socket} ->
            case ssl:handshake(Socket, 5000) of
                {ok, TlsSocket} ->
                    case ssl:recv(TlsSocket, 0, 5000) of
                        {ok, _Request} ->
                            ssl:send(TlsSocket,
                                <<"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
                                  "Content-Length: 2\r\nConnection: close\r\n\r\nok">>);
                        _ -> ok
                    end,
                    ssl:close(TlsSocket);
                _ -> ok
            end;
        _ -> ok
    end,
    ssl:close(Listener).
