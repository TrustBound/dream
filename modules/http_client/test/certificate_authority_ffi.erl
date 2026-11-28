-module(certificate_authority_ffi).
-export([write_certificates/1]).

-include_lib("public_key/include/public_key.hrl").

%% Writes test certificates for "localhost" to Directory, for tests only:
%% the server certificate and key, the certificate authority that signed
%% them, and an unrelated certificate authority.
%% Returns {CertFile, KeyFile, CaFile, OtherCaFile}.
write_certificates(Directory) ->
    %% public_key is not loaded until an application that uses it starts.
    {ok, _} = application:ensure_all_started(ssl),
    {Cert, Key, Ca} = generate(),
    {_, _, OtherCa} = generate(),
    CertFile = filename:join(Directory, "cert.pem"),
    KeyFile = filename:join(Directory, "key.pem"),
    CaFile = filename:join(Directory, "ca.pem"),
    OtherCaFile = filename:join(Directory, "other-ca.pem"),
    ok = filelib:ensure_dir(CertFile),
    ok = file:write_file(CertFile, pem([{'Certificate', Cert, not_encrypted}])),
    ok = file:write_file(KeyFile, pem([Key])),
    ok = file:write_file(CaFile, pem([{'Certificate', Ca, not_encrypted}])),
    ok = file:write_file(OtherCaFile, pem([{'Certificate', OtherCa, not_encrypted}])),
    {CertFile, KeyFile, CaFile, OtherCaFile}.

generate() ->
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
    {Cert, {KeyType, KeyDer, not_encrypted}, Ca}.

pem(Entries) ->
    public_key:pem_encode(Entries).
