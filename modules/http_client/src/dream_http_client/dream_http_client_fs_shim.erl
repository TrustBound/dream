-module(dream_http_client_fs_shim).

-export([atomic_write/2]).

%% @doc Atomically write file content.
%%
%% Writes content to a temporary file and renames it into place so readers
%% never observe partial content.
atomic_write(Path, Content) when is_binary(Path), is_binary(Content) ->
    Unique = erlang:unique_integer([monotonic, positive]),
    Tmp = <<Path/binary, ".tmp.", (integer_to_binary(Unique))/binary>>,
    case file:write_file(Tmp, Content) of
        ok ->
            case file:rename(Tmp, Path) of
                ok ->
                    {ok, nil};
                {error, Reason} ->
                    _ = file:delete(Tmp),
                    {error, format_reason(Reason)}
            end;
        {error, Reason} ->
            {error, format_reason(Reason)}
    end;
atomic_write(Path, Content) ->
    %% Normalize non-binary inputs to binaries for safety
    atomic_write(iolist_to_binary(Path), iolist_to_binary(Content)).

format_reason(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
