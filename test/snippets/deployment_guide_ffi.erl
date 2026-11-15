-module(deployment_guide_ffi).
-export([free_port/0]).

%% Asks the operating system for a free TCP port, so that tests that run at
%% the same time on this machine do not use the same port.
free_port() ->
    {ok, Listen} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    ok = gen_tcp:close(Listen),
    Port.
