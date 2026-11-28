-module(testing_guide_snippets_ffi).
-export([run_main_in_new_vm/1]).

%% Run Module:main() in a new Erlang VM with the same code path, and return
%% its exit status. A test entry point ends with dream_test's
%% exit_on_failure, which halts the VM, so it cannot run in this VM.
run_main_in_new_vm(Module) ->
    Erl = os:find_executable("erl"),
    CodePath = lists:append([["-pa", Dir] || Dir <- code:get_path()]),
    Eval = io_lib:format("~s:main().", [Module]),
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
