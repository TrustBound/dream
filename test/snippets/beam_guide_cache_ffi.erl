-module(beam_guide_cache_ffi).
-export([new_table/0, insert/3, lookup/2, increment/2, exists/1]).

%% An ETS table that every process can read and write. The process that
%% calls new_table/0 owns the table: the table goes away when that process
%% ends.
new_table() ->
    ets:new(cache, [set, public, {read_concurrency, true}]).

insert(Table, Key, Value) ->
    true = ets:insert(Table, {Key, Value}),
    nil.

lookup(Table, Key) ->
    case ets:lookup(Table, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil}
    end.

%% Adds 1 to the number under Key in one step, and returns the new number.
%% A key that is not there starts at 0.
increment(Table, Key) ->
    ets:update_counter(Table, Key, 1, {Key, 0}).

exists(Table) ->
    ets:info(Table, id) =/= undefined.
