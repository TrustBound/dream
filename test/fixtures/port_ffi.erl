-module(port_ffi).
-export([free_port/0, claim/1, call_trapping_exits/1]).

-define(REGISTRY, dream_test_port_registry).

%% Returns a TCP port on 127.0.0.1 that no other caller in this BEAM got
%% before, so that tests that run at the same time do not use the same port.
%%
%% The operating system gives a port that has no listener. The registry
%% process then claims it. If an earlier call claimed the port, the listener
%% stays open while this call asks for the next port, so the operating system
%% cannot give the same port again. All listeners close before the call
%% returns.
free_port() ->
    free_port([]).

free_port(Held) ->
    {ok, Listen} = gen_tcp:listen(0, [{ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    case claim(Port) of
        true ->
            lists:foreach(fun gen_tcp:close/1, [Listen | Held]),
            Port;
        false ->
            free_port([Listen | Held])
    end.

%% Records Port as given out. Returns true for the first claim of Port in
%% this BEAM and false for each claim after it. One registry process does
%% all claims one at a time, so two callers cannot both get true.
claim(Port) ->
    Registry = registry(),
    Ref = erlang:monitor(process, Registry),
    Registry ! {claim, self(), Ref, Port},
    receive
        {Ref, Claimed} ->
            erlang:demonitor(Ref, [flush]),
            Claimed;
        {'DOWN', Ref, process, Registry, Reason} ->
            erlang:error({port_registry_down, Reason})
    end.

%% Finds the registry process, or starts it. register/2 is atomic: if two
%% first callers start a process each, only one gets the name. The other
%% caller stops its own process and uses the registered one. The process is
%% not linked to a caller and does not use the caller's group leader, so it
%% stays alive when test processes stop. It runs until the BEAM stops.
registry() ->
    case whereis(?REGISTRY) of
        undefined ->
            Pid = spawn(fun() ->
                group_leader(whereis(init), self()),
                registry_loop(#{})
            end),
            try register(?REGISTRY, Pid) of
                true -> Pid
            catch
                error:badarg ->
                    exit(Pid, kill),
                    registry()
            end;
        Pid ->
            Pid
    end.

registry_loop(Claimed) ->
    receive
        {claim, From, Ref, Port} ->
            From ! {Ref, not maps:is_key(Port, Claimed)},
            registry_loop(Claimed#{Port => true})
    end.

%% Calls Fun with trap_exit set, then sets trap_exit back to its old value.
%% A server that fails to start then comes back as an Error value, and its
%% linked supervisor does not stop the calling process.
call_trapping_exits(Fun) ->
    Old = process_flag(trap_exit, true),
    try
        Fun()
    after
        process_flag(trap_exit, Old)
    end.
