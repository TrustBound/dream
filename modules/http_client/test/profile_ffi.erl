-module(profile_ffi).
-export([max_sessions/1, begin_cancel_trace/0, cancelled_in/1]).

max_sessions(Profile) ->
    {ok, [{max_sessions, Count}]} = httpc:get_options([max_sessions], Profile),
    Count.

begin_cancel_trace() ->
    Parent = self(),
    Tracer = spawn(fun() ->
        receive
            {trace, _Pid, call, {httpc, cancel_request, [_RequestId, Profile]}} ->
                Parent ! {cancelled_in, Profile}
        after 1500 -> ok
        end
    end),
    put(profile_cancel_tracer, Tracer),
    erlang:trace_pattern({httpc, cancel_request, 2}, true, [local]),
    erlang:trace(self(), true, [call, {tracer, Tracer}]),
    nil.

cancelled_in(Profile) ->
    Result = receive
        {cancelled_in, ObservedProfile} -> ObservedProfile =:= Profile
    after 1000 -> false
    end,
    erlang:trace(self(), false, [call]),
    erlang:trace_pattern({httpc, cancel_request, 2}, false, [local]),
    exit(erase(profile_cancel_tracer), kill),
    Result.
