-module(ets_table_ownership_ffi).
-export([ensure_table/0, table_exists/0, delete_table/0,
         table_owner_is_not_self/0, table_owner_is_alive/0,
         store_test_mapping/0, lookup_test_mapping_exists/0]).

-define(TABLE, dream_http_client_ref_mapping).

ensure_table() ->
    dream_httpc_shim:ensure_ref_mapping_table(),
    nil.

table_exists() ->
    case ets:info(?TABLE) of
        undefined -> false;
        _ -> true
    end.

delete_table() ->
    try ets:delete(?TABLE) catch error:badarg -> ok end,
    nil.

table_owner_is_not_self() ->
    try
        case ets:info(?TABLE, owner) of
            undefined -> false;
            Pid -> Pid =/= self()
        end
    catch
        error:badarg -> false
    end.

table_owner_is_alive() ->
    try
        case ets:info(?TABLE, owner) of
            undefined -> false;
            Pid -> is_process_alive(Pid)
        end
    catch
        error:badarg -> false
    end.

store_test_mapping() ->
    ets:insert(?TABLE, {ets_test_ref_key, <<"ets_test_string_id">>}),
    ets:insert(?TABLE, {<<"ets_test_string_id">>, ets_test_ref_key}),
    nil.

lookup_test_mapping_exists() ->
    try
        case ets:lookup(?TABLE, ets_test_ref_key) of
            [{ets_test_ref_key, <<"ets_test_string_id">>}] -> true;
            _ -> false
        end
    catch
        error:badarg -> false
    end.
