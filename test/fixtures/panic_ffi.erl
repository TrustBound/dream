-module(panic_ffi).
-export([catch_panic/1]).

%% Calls Fun. Returns {ok, Value} when it returns, or {error, Message} with
%% the message of a Gleam panic that it raised. Any other exception is
%% raised again, so a test sees it as a crash.
catch_panic(Fun) ->
    try
        {ok, Fun()}
    catch
        error:#{gleam_error := panic, message := Message} ->
            {error, Message}
    end.
