-module(ets_table_ownership_ffi).
-export([table_exists/0, table_owner_is_not_self/0, table_owner_is_alive/0,
         store_test_mapping/0, lookup_test_mapping_exists/0,
         clear_test_mappings/0]).

-define(TABLE, dream_http_client_ref_mapping).

table_exists() ->
    case ets:info(?TABLE) of
        undefined -> false;
        _ -> true
    end.

table_owner_is_not_self() ->
    case ets:info(?TABLE, owner) of
        undefined -> false;
        Pid -> Pid =/= self()
    end.

table_owner_is_alive() ->
    case ets:info(?TABLE, owner) of
        undefined -> false;
        Pid -> is_process_alive(Pid)
    end.

store_test_mapping() ->
    ets:insert(?TABLE, {ets_test_ref_key, <<"ets_test_string_id">>}),
    ets:insert(?TABLE, {<<"ets_test_string_id">>, ets_test_ref_key}),
    nil.

lookup_test_mapping_exists() ->
    case ets:lookup(?TABLE, ets_test_ref_key) of
        [{ets_test_ref_key, <<"ets_test_string_id">>}] -> true;
        _ -> false
    end.

clear_test_mappings() ->
    ets:delete(?TABLE, ets_test_ref_key),
    ets:delete(?TABLE, <<"ets_test_string_id">>),
    nil.
