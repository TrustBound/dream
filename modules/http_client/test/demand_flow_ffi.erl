-module(demand_flow_ffi).
-export([one_httpc_advance_per_fetch/1]).

one_httpc_advance_per_fetch(Port) ->
    Url = "http://localhost:" ++ integer_to_list(Port) ++ "/stream/huge",
    {ok, Owner} = dream_httpc_shim:request_stream(get, Url, [], <<>>, self(), 30000),
    try
        {ok, _Headers} = dream_httpc_shim:fetch_start_headers(Owner, 5000),
        erlang:trace_pattern({httpc, stream_next, 1}, true, [local]),
        erlang:trace(Owner, true, [call, {tracer, self()}]),
        {chunk, _First} = dream_httpc_shim:fetch_next(Owner, 5000),
        FirstAdvance = receive_advance(Owner, 1000),
        NoAdvanceWithoutDemand = no_advance(Owner, 100),
        {chunk, _Second} = dream_httpc_shim:fetch_next(Owner, 5000),
        SecondAdvance = receive_advance(Owner, 1000),
        FirstAdvance andalso NoAdvanceWithoutDemand andalso SecondAdvance
    after
        erlang:trace(Owner, false, [call]),
        erlang:trace_pattern({httpc, stream_next, 1}, false, [local]),
        Owner ! cancel_stream
    end.

receive_advance(Owner, Timeout) ->
    receive
        {trace, Owner, call, {httpc, stream_next, [_Handler]}} -> true
    after Timeout -> false
    end.

no_advance(Owner, Timeout) ->
    receive
        {trace, Owner, call, {httpc, stream_next, [_Handler]}} -> false
    after Timeout -> true
    end.
