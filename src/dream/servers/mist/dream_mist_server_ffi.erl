-module(dream_mist_server_ffi).
-export([stop_supervisor/1]).

%% Stops the supervisor that mist:start/1 returns, from any process, and
%% returns nil when the supervisor is no longer running.
%%
%% An exit signal with reason normal does nothing unless it comes from the
%% parent of the supervisor, so dream asks the supervisor to stop through
%% the sys protocol: gen_server:stop/1 calls proc_lib:stop(Pid, normal,
%% infinity). The supervisor then runs its terminate callback, which stops
%% each child in reverse start order with the shutdown that its child
%% specification gives, and then exits with reason normal. Because the
%% reason is normal, the linked process that started the server does not
%% get an exit that kills it. The call returns only after the supervisor is
%% down, so the port is free when it returns.
%%
%% With a local pid and an infinity timeout, gen_server:stop/1 exits the
%% caller only when the supervisor is not running: noproc when it was down
%% before the call, or the exit reason of the supervisor when it stopped
%% for a different reason during the call. In each case the supervisor is
%% down, which is the result that stop asks for, so the function returns
%% nil and does not crash the caller.
stop_supervisor(Pid) ->
    try gen_server:stop(Pid) of
        ok -> nil
    catch
        exit:noproc -> nil;
        exit:_ReasonTheSupervisorStoppedWith -> nil
    end.
