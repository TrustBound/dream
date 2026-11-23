%% Node-wide lock for tests that change environment variables.
%%
%% global:trans/4 runs Body while this process holds the lock, and releases
%% the lock when Body returns or crashes. Other callers wait for it.
-module(environment_ffi).
-export([with_lock/1]).

with_lock(Body) ->
    global:trans({dream_test_environment, self()}, Body, [node()], infinity).
