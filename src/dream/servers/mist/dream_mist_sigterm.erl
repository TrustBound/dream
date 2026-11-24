-module(dream_mist_sigterm).
-behaviour(gen_event).
-export([install/1, install/3]).
-export([init/1, handle_event/2, handle_call/2]).

%% Makes SIGTERM drain the servers that `listen` starts before the VM stops.
%%
%% The VM sends each signal as an event to the gen_event manager
%% erl_signal_server. Its default handler, erl_signal_handler, calls
%% init:stop() on SIGTERM. init:stop() stops the OTP applications and then
%% kills every other process, also a server that `listen` started from
%% `main`, so that server would close its running requests at once.
%%
%% This handler takes the place of erl_signal_handler. On SIGTERM, it stops
%% each server with the normal OTP stop, which drains it within the
%% shutdown timeout of the server, and then gives SIGTERM to
%% erl_signal_handler, which logs it and calls init:stop(). It gives every
%% other signal to erl_signal_handler at once.
install(Server) ->
    install(erl_signal_server, erl_signal_handler, Server).

%% Adds Server to the handler on Manager. The first call puts the handler in
%% the place of Next.
install(Manager, Next, Server) ->
    case lists:member(?MODULE, gen_event:which_handlers(Manager)) of
        true ->
            ok = gen_event:call(Manager, ?MODULE, {add, Server});
        false ->
            ok = gen_event:swap_handler(Manager, {Next, swap},
                                        {?MODULE, {Next, Server}})
    end,
    nil.

%% NextState is what the terminate callback of Next returned in the swap.
init({{Next, Server}, NextState}) ->
    {ok, {Next, NextState, [Server]}}.

handle_event(sigterm, {Next, NextState, Servers} = State) ->
    spawn(fun() ->
        stop_all(Servers),
        Next:handle_event(sigterm, NextState)
    end),
    {ok, State};
handle_event(Signal, {Next, NextState, Servers}) ->
    {ok, NextState1} = Next:handle_event(Signal, NextState),
    {ok, {Next, NextState1, Servers}}.

handle_call({add, Server}, {Next, NextState, Servers}) ->
    Running = [Pid || Pid <- Servers, is_process_alive(Pid)],
    {ok, ok, {Next, NextState, [Server | Running]}}.

%% Stops the servers at the same time, and returns when all are down.
stop_all(Servers) ->
    Monitors = [element(2, spawn_monitor(fun() ->
                    dream_mist_server_ffi:stop_supervisor(Server)
                end)) || Server <- Servers],
    [receive {'DOWN', Monitor, process, _Pid, _Reason} -> ok end
     || Monitor <- Monitors],
    ok.
