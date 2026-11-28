-module(blocking_listen_ffi).
-export([spawn_watched/1, await_blocked/2, kill_and_await_links/2]).

%% server.listen/2 sends no message when the server runs: it calls
%% gleam_erlang_ffi:sleep_forever/0 and blocks. A test can wait for that
%% call with call tracing. The trace message comes to the process that
%% calls this function.
%%
%% The new process waits for go until its trace is on, so the call to
%% sleep_forever cannot come before the trace.
spawn_watched(Run) ->
    Pid = spawn(fun() ->
        receive go -> Run() end
    end),
    erlang:trace_pattern({gleam_erlang_ffi, sleep_forever, 0}, true, [global]),
    erlang:trace(Pid, true, [call]),
    Pid ! go,
    Pid.

%% True when Pid calls sleep_forever within Timeout milliseconds. The trace
%% of Pid stops in each case.
await_blocked(Pid, Timeout) ->
    Blocked = receive
        {trace, Pid, call, {gleam_erlang_ffi, sleep_forever, []}} -> true
    after Timeout ->
        false
    end,
    catch erlang:trace(Pid, false, [call]),
    Blocked.

%% Kills Pid and waits until each process that is linked to it is down, for
%% example the supervisor of a server that Pid started. True when all are
%% down within Timeout milliseconds.
kill_and_await_links(Pid, Timeout) ->
    {links, Links} = erlang:process_info(Pid, links),
    Monitors = [erlang:monitor(process, Link) || Link <- Links, is_pid(Link)],
    exit(Pid, kill),
    Deadline = erlang:monotonic_time(millisecond) + Timeout,
    lists:all(fun(Monitor) -> await_down(Monitor, Deadline) end, Monitors).

await_down(Monitor, Deadline) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {'DOWN', Monitor, process, _Pid, _Reason} -> true
    after Remaining ->
        erlang:demonitor(Monitor, [flush]),
        false
    end.
