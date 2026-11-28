-module(testing_guide_snippets_ffi).
-export([run_main_in_new_vm/1]).

%% Run Module:main() in a new Erlang VM with the same code path, and return
%% its exit status. A test entry point uses dream_test's exit_on_failure.
%% When a test fails, it stops the VM with status 1, so it cannot run in
%% this VM. When the tests pass, main returns, and the new VM stops with
%% status 0, as `gleam test` does.
run_main_in_new_vm(Module) ->
    Erl = os:find_executable("erl"),
    CodePath = lists:append([["-pa", Dir] || Dir <- code:get_path()]),
    Eval = io_lib:format("~s:main(), init:stop(0).", [Module]),
    Port = open_port(
        {spawn_executable, Erl},
        [exit_status, stderr_to_stdout, binary,
         {args, ["-noshell" | CodePath] ++ ["-eval", lists:flatten(Eval)]}]
    ),
    wait_for_exit(Port).

wait_for_exit(Port) ->
    receive
        {Port, {data, _Output}} -> wait_for_exit(Port);
        {Port, {exit_status, Status}} -> Status
    end.
