-module(integration_certificates).
-export([write/1]).

-include_lib("public_key/include/public_key.hrl").

%% Writes a test certificate authority (ca.pem) and a server certificate for
%% "localhost" signed by it (cert.pem, key.pem) to Directory. For tests only:
%% the keys are made fresh on every run and never leave the build folder.
write(Directory) ->
    {ok, _} = application:ensure_all_started(ssl),
    Options = [{key, {namedCurve, secp256r1}}, {digest, sha256}],
    Localhost = #'Extension'{
        extnID = ?'id-ce-subjectAltName',
        extnValue = [{dNSName, "localhost"}],
        critical = false
    },
    Chain = #{
        root => Options,
        intermediates => [],
        peer => [{extensions, [Localhost]} | Options]
    },
    #{server_config := Config} =
        public_key:pkix_test_data(#{server_chain => Chain, client_chain => Chain}),
    Cert = proplists:get_value(cert, Config),
    {KeyType, KeyDer} = proplists:get_value(key, Config),
    [Ca | _] = lists:reverse(proplists:get_value(cacerts, Config)),
    ok = filelib:ensure_dir(filename:join(Directory, "ca.pem")),
    ok = write_pem(Directory, "ca.pem", [{'Certificate', Ca, not_encrypted}]),
    ok = write_pem(Directory, "cert.pem", [{'Certificate', Cert, not_encrypted}]),
    ok = write_pem(Directory, "key.pem", [{KeyType, KeyDer, not_encrypted}]),
    nil.

write_pem(Directory, Name, Entries) ->
    file:write_file(filename:join(Directory, Name), public_key:pem_encode(Entries)).
