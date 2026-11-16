-module(loader_test_ffi).

-export([write_file/2, make_unreadable/1, delete_file/1]).

%% Writes Contents to the file at Path. Returns {ok, nil} or {error, nil}.
write_file(Path, Contents) ->
    to_result(file:write_file(Path, Contents)).

%% Removes every permission from the file at Path.
make_unreadable(Path) ->
    to_result(file:change_mode(Path, 8#000)).

%% Deletes the file at Path.
delete_file(Path) ->
    to_result(file:delete(Path)).

to_result(ok) -> {ok, nil};
to_result({error, _Reason}) -> {error, nil}.
