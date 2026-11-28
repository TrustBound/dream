-module(stop_supervisor_ffi).
-behaviour(gen_server).
-export([start_failing_on_stop/0, is_alive/1]).
-export([init/1, handle_call/3, handle_cast/2, terminate/2]).

%% A gen_server that exits with reason failed_while_stopping when it is
%% asked to stop. A test stops it with dream_mist_server_ffi:stop_supervisor/1
%% to see that the call returns when the process stops with a reason other
%% than normal. It is not linked to the caller.
start_failing_on_stop() ->
    {ok, Pid} = gen_server:start(?MODULE, nil, []),
    Pid.

is_alive(Pid) ->
    erlang:is_process_alive(Pid).

init(nil) ->
    {ok, nil}.

handle_call(_Request, _From, State) ->
    {reply, nil, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    exit(failed_while_stopping).
