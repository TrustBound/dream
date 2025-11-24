-module(env_ffi).
-export([get_env/2]).

get_env(Name, Default) ->
    case os:getenv(binary_to_list(Name)) of
        false -> Default;
        Value -> list_to_binary(Value)
    end.

