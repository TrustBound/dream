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

ets_insert(TableId, Object) ->
    ets:insert(TableId, Object),
    ok.

ets_lookup(TableId, Key) ->
    case ets:lookup(TableId, Key) of
        [] ->
            {error, not_found};
        [Object] ->
            {ok, Object};
        Objects ->
            {ok, Objects}
    end.

ets_delete_table(TableId) ->
    ets:delete(TableId),
    ok.

ets_delete_key(TableId, Key) ->
    ets:delete(TableId, Key),
    ok.

ets_delete_object(TableId, Object) ->
    ets:delete_object(TableId, Object),
    ok.

ets_delete_all_objects(TableId) ->
    ets:delete_all_objects(TableId),
    ok.

ets_first(TableId) ->
    case ets:first(TableId) of
        '$end_of_table' ->
            {error, empty_table};
        Key ->
            {ok, Key}
    end.

ets_next(TableId, Key) ->
    case ets:next(TableId, Key) of
        '$end_of_table' ->
            {error, end_of_table};
        NextKey ->
            {ok, NextKey}
    end.

ets_member(TableId, Key) ->
    ets:member(TableId, Key).

ets_insert_new(TableId, Object) ->
    ets:insert_new(TableId, Object).

ets_take(TableId, Key) ->
    case ets:take(TableId, Key) of
        [] ->
            {error, not_found};
        [Object] ->
            {ok, Object};
        Objects ->
            {ok, Objects}
    end.

ets_update_element(TableId, Key, {Pos, Value}) ->
    case ets:update_element(TableId, Key, {Pos, Value}) of
        true ->
            {ok, nil};
        false ->
            {error, not_found}
    end.

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
    ets:match(TableId, Pattern).

%% Pattern matching - returns matching objects
ets_match_object(TableId, Pattern) ->
    ets:match_object(TableId, Pattern).

%% Select with match specification
ets_select(TableId, MatchSpec) ->
    ets:select(TableId, MatchSpec).

%% Save table to file
ets_tab2file(TableId, Filename) ->
    %% Convert binary (Gleam String) to charlist (Erlang string)
    FilenamePath = binary_to_list(Filename),
    case ets:tab2file(TableId, FilenamePath) of
        ok ->
            {ok, nil};
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
