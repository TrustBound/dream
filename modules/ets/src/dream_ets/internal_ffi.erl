%% Erlang FFI for ETS operations
%%
%% Pure wrappers around Erlang ETS functions. No business logic here.

-module(internal_ffi).

-export([ets_new/2, ets_insert/2, ets_lookup/2, ets_delete_table/1, ets_delete_key/2,
         ets_delete_object/2, ets_delete_all_objects/1, ets_first/1, ets_next/2, ets_member/2,
         ets_insert_new/2, ets_take/2, ets_update_element/3, ets_info/1, ets_info_by_name/1,
         ets_match/2, ets_match_object/2, ets_select/2, ets_tab2file/2, ets_file2tab/1,
         to_dynamic/1, wrap_table_ref/1, unwrap_table_ref/1]).

%% Pure wrapper - accepts atom name and list of options (atoms or tuples)
%% All conversion happens in Gleam before calling this
ets_new(NameAtom, Options) ->
    try
        TableId = ets:new(NameAtom, Options),
        {ok, TableId}
    catch
        error:badarg ->
            {error, badarg};
        error:system_limit ->
            {error, system_limit};
        _:_ ->
            {error, unknown}
    end.

%% Each operation on an existing table runs through with_table/2, so that an
%% operation on a table that does not exist returns {error, table_not_found}
%% and does not crash the calling process.

ets_insert(TableId, Object) ->
    with_table(TableId, fun() ->
        ets:insert(TableId, Object),
        {ok, nil}
    end).

ets_lookup(TableId, Key) ->
    with_table(TableId, fun() -> lookup_result(ets:lookup(TableId, Key)) end).

ets_delete_table(TableId) ->
    with_table(TableId, fun() ->
        ets:delete(TableId),
        {ok, nil}
    end).

ets_delete_key(TableId, Key) ->
    with_table(TableId, fun() ->
        ets:delete(TableId, Key),
        {ok, nil}
    end).

ets_delete_object(TableId, Object) ->
    with_table(TableId, fun() ->
        ets:delete_object(TableId, Object),
        {ok, nil}
    end).

ets_delete_all_objects(TableId) ->
    with_table(TableId, fun() ->
        ets:delete_all_objects(TableId),
        {ok, nil}
    end).

ets_first(TableId) ->
    with_table(TableId, fun() ->
        case ets:first(TableId) of
            '$end_of_table' ->
                {error, empty_table};
            Key ->
                {ok, Key}
        end
    end).

ets_next(TableId, Key) ->
    with_table(TableId, fun() ->
        case ets:next(TableId, Key) of
            '$end_of_table' ->
                {error, end_of_table};
            NextKey ->
                {ok, NextKey}
        end
    end).

ets_member(TableId, Key) ->
    with_table(TableId, fun() -> {ok, ets:member(TableId, Key)} end).

ets_insert_new(TableId, Object) ->
    with_table(TableId, fun() -> {ok, ets:insert_new(TableId, Object)} end).

ets_take(TableId, Key) ->
    with_table(TableId, fun() -> lookup_result(ets:take(TableId, Key)) end).

ets_update_element(TableId, Key, {Pos, Value}) ->
    with_table(TableId, fun() ->
        case ets:update_element(TableId, Key, {Pos, Value}) of
            true ->
                {ok, nil};
            false ->
                {error, not_found}
        end
    end).

ets_info(TableId) ->
    case ets:info(TableId) of
        undefined ->
            {error, not_found};
        Info ->
            {ok, Info}
    end.

%% Check if a named table exists by name atom
ets_info_by_name(NameAtom) ->
    case ets:info(NameAtom) of
        undefined ->
            {error, not_found};
        Info ->
            {ok, Info}
    end.

%% Pattern matching - returns list of matches
ets_match(TableId, Pattern) ->
    with_table(TableId, fun() -> {ok, ets:match(TableId, Pattern)} end).

%% Pattern matching - returns matching objects
ets_match_object(TableId, Pattern) ->
    with_table(TableId, fun() -> {ok, ets:match_object(TableId, Pattern)} end).

%% Select with match specification
ets_select(TableId, MatchSpec) ->
    with_table(TableId, fun() -> {ok, ets:select(TableId, MatchSpec)} end).

%% Save table to file
ets_tab2file(TableId, Filename) ->
    %% Convert binary (Gleam String) to charlist (Erlang string)
    FilenamePath = binary_to_list(Filename),
    case ets:tab2file(TableId, FilenamePath) of
        ok ->
            {ok, nil};
        {error, badtab} ->
            missing_table_or(TableId, {invalid_operation, <<"badtab">>});
        {error, Reason} ->
            {error, {invalid_operation, format_error(Reason)}}
    end.

%% Load table from file
ets_file2tab(Filename) ->
    %% Convert binary (Gleam String) to charlist (Erlang string)
    FilenamePath = binary_to_list(Filename),
    case ets:file2tab(FilenamePath) of
        {ok, TableId} ->
            {ok, TableId};
        {error, Reason} ->
            {error, {invalid_operation, format_error(Reason)}}
    end.

%% Lookup and take return a list of objects
lookup_result([]) ->
    {error, not_found};
lookup_result([Object]) ->
    {ok, Object};
lookup_result(Objects) ->
    {ok, Objects}.

%% Runs Operation, which returns {ok, Value} or {error, Reason}.
%%
%% ETS raises badarg when the table does not exist, and also for other
%% causes (for example no access rights, or a bad match specification). The
%% table is checked only after badarg, so the normal path does no extra
%% lookup and no table can be deleted between a check and the operation.
%% A deleted table stays deleted, so the check after badarg finds it gone.
%% (Only if another process creates a new named table with the same name
%% between the two steps does the check find a table; then badarg is
%% raised, as before.) When the table exists, the badarg had another cause
%% and is raised again with its stack trace.
with_table(TableId, Operation) ->
    try
        Operation()
    catch
        error:badarg:Stacktrace ->
            case ets:info(TableId) of
                undefined ->
                    {error, table_not_found};
                _ ->
                    erlang:raise(error, badarg, Stacktrace)
            end
    end.

%% Returns {error, table_not_found} when the table does not exist, and
%% {error, OtherError} when it does
missing_table_or(TableId, OtherError) ->
    case ets:info(TableId) of
        undefined ->
            {error, table_not_found};
        _ ->
            {error, OtherError}
    end.

%% Format error reason as string
format_error(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason, utf8);
format_error(Reason) when is_list(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason]));
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% Convert any Erlang term to Dynamic (identity function - Gleam FFI handles the wrapping)
to_dynamic(Value) ->
    Value.

%% Wrap table ID as opaque type (identity function)
wrap_table_ref(TableId) ->
    TableId.

%% Unwrap opaque table ref to table ID (identity function)
unwrap_table_ref(TableRef) ->
    TableRef.
