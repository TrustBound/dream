-module(dream_tls_test_ffi).
-export([write_certificate/1, request/3]).

%% Writes a certificate and key for "localhost" to Directory, for tests only.
%% Returns {CertFile, KeyFile}.
write_certificate(Directory) ->
    %% public_key is not loaded until an application that uses it starts.
    {ok, _} = application:ensure_all_started(ssl),
    Options = [{key, {namedCurve, secp256r1}}, {digest, sha256}],
    Chain = #{root => Options, intermediates => [], peer => Options},
    #{server_config := Config} =
        public_key:pkix_test_data(#{server_chain => Chain, client_chain => Chain}),
    Der = proplists:get_value(cert, Config),
    {KeyType, KeyDer} = proplists:get_value(key, Config),
    CertFile = filename:join(Directory, "cert.pem"),
    KeyFile = filename:join(Directory, "key.pem"),
    ok = filelib:ensure_dir(CertFile),
    ok = file:write_file(
        CertFile, public_key:pem_encode([{'Certificate', Der, not_encrypted}])
    ),
    ok = file:write_file(
        KeyFile, public_key:pem_encode([{KeyType, KeyDer, not_encrypted}])
    ),
    {CertFile, KeyFile}.

%% Sends GET Path to https://localhost:Port, offering only Protocol (http2 or
%% http) in the TLS handshake. Returns {ok, {Negotiated, Status, Body}}.
request(Port, Protocol, Path) ->
    {ok, _} = application:ensure_all_started(gun),
    Options = #{
        transport => tls,
        tls_opts => [{verify, verify_none}],
        protocols => [Protocol],
        retry => 0
    },
    {ok, Connection} = gun:open("localhost", Port, Options),
    Result =
        case gun:await_up(Connection, 5000) of
            {ok, Negotiated} ->
                Stream = gun:get(Connection, Path),
                case gun:await(Connection, Stream, 5000) of
                    {response, nofin, Status, _Headers} ->
                        {ok, Body} = gun:await_body(Connection, Stream, 5000),
                        {ok, {Negotiated, Status, Body}};
                    {response, fin, Status, _Headers} ->
                        {ok, {Negotiated, Status, <<>>}};
                    {error, Reason} ->
                        {error, Reason}
                end;
            {error, Reason} ->
                {error, Reason}
        end,
    gun:close(Connection),
    Result.
