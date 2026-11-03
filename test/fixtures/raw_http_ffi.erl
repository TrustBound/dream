-module(raw_http_ffi).
-export([request_until_closed/3]).

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
