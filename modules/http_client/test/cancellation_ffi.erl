-module(cancellation_ffi).
-export([await_registered/1, await_cleanup/1,
         begin_cancel_trace/0, cancel_request_observed/0]).

await_registered({stream_handle, Pid}) -> await_registered(Pid, 50).

await_registered(_Pid, 0) -> false;
await_registered(Pid, Remaining) ->
    case ets:lookup(dream_http_client_ref_mapping, {owner, Pid}) of
        [_] -> true;
        [] ->
            timer:sleep(10),
            await_registered(Pid, Remaining - 1)
    end.

await_cleanup({stream_handle, Pid}) -> await_cleanup(Pid, 50).

await_cleanup(_Pid, 0) -> false;
await_cleanup(Pid, Remaining) ->
    case ets:lookup(dream_http_client_ref_mapping, {owner, Pid}) of
        [] -> true;
        [_] ->
            timer:sleep(10),
            await_cleanup(Pid, Remaining - 1)
    end.

begin_cancel_trace() ->
    Parent = self(),
    Tracer = spawn(fun() ->
        receive
            {trace, _Pid, call, {httpc, cancel_request, [_RequestId]}} ->
                Parent ! cancel_request_observed
        after 1500 -> ok
        end
    end),
    put(cancel_tracer, Tracer),
    erlang:trace_pattern({httpc, cancel_request, 1}, true, [local]),
    erlang:trace(self(), true, [call, {tracer, Tracer}]),
    nil.

cancel_request_observed() ->
    Result = receive
        cancel_request_observed -> true
    after 1000 -> false
    end,
    erlang:trace(self(), false, [call]),
    erlang:trace_pattern({httpc, cancel_request, 1}, false, [local]),
    exit(erase(cancel_tracer), kill),
    Result.
