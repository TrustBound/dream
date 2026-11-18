%% Erlang FFI for dream_config.
%%
%% Reads a file as UTF-8 text. No business logic here.

-module(dream_config_ffi).

-export([read_text_file/1]).

%% Returns {ok, Text}, or {error, file_not_found}, {error, file_not_utf8} or
%% {error, {file_not_readable, Reason}} where Reason is a readable binary.
read_text_file(Path) ->
    case file:read_file(Path) of
        {ok, Contents} -> check_utf8(Contents);
        {error, enoent} -> {error, file_not_found};
        {error, Reason} -> {error, {file_not_readable, format_reason(Reason)}}
    end.

check_utf8(Contents) ->
    case unicode:characters_to_binary(Contents) of
        Contents -> {ok, Contents};
        _ -> {error, file_not_utf8}
    end.

format_reason(Reason) ->
    unicode:characters_to_binary(file:format_error(Reason)).
