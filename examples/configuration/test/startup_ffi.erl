-module(startup_ffi).
-export([run_app/2, first_line/2, read_output/1]).

%% The settings of the links app. A setting that a test does not give is
%% removed from the environment of the new VM, so the environment of the
%% test run never leaks into it.
-define(settings, ["PORT", "SITE_URL", "SIGNING_KEY"]).
-define(timeout_ms, 20000).

%% Runs links/main in a new VM, in Directory, with Variables. Waits for
%% the VM to stop, and returns {ExitStatus, Output}.
run_app(Directory, Variables) ->
    Port = open_app(Directory, Variables),
    collect(Port, <<>>).

%% Runs links/main in a new VM, returns its first line of output, and
%% stops the VM.
first_line(Directory, Variables) ->
    Port = open_app(Directory, Variables),
    Line = read_line(Port, <<>>),
    stop(Port),
    Line.

%% The text of test/outputs/<Name>.txt.
read_output(Name) ->
    case file:read_file(<<"test/outputs/", Name/binary, ".txt">>) of
        {ok, Text} -> {ok, Text};
        {error, Reason} -> {error, atom_to_binary(Reason)}
    end.

open_app(Directory, Variables) ->
    Erl = os:find_executable("erl"),
    Paths = [filename:absname(Path) || Path <- code:get_path(),
                                       string:find(Path, "build/dev/erlang") =/= nomatch],
    Eval = "'dream_example_configuration@@main':run('links@main')",
    open_port({spawn_executable, Erl},
              [{args, ["-noshell", "-pa" | Paths] ++ ["-eval", Eval]},
               {cd, binary_to_list(Directory)},
               {env, environment(Variables)},
               exit_status, stderr_to_stdout, binary, use_stdio]).

environment(Variables) ->
    Set = [{binary_to_list(Name), binary_to_list(Value)} || {Name, Value} <- Variables],
    Unset = [{Name, false} || Name <- ?settings, not lists:keymember(Name, 1, Set)],
    Unset ++ Set.

collect(Port, Output) ->
    receive
        {Port, {data, Data}} -> collect(Port, <<Output/binary, Data/binary>>);
        {Port, {exit_status, Status}} -> {Status, Output}
    after ?timeout_ms ->
        stop(Port),
        {-1, Output}
    end.

read_line(Port, Output) ->
    case binary:split(Output, <<"\n">>) of
        [Line, _] -> <<Line/binary, "\n">>;
        [_] ->
            receive
                {Port, {data, Data}} -> read_line(Port, <<Output/binary, Data/binary>>);
                {Port, {exit_status, _}} -> Output
            after ?timeout_ms -> Output
            end
    end.

%% Stops the VM with SIGTERM, and waits until it is gone, so that its
%% listen port is free again.
stop(Port) ->
    case erlang:port_info(Port, os_pid) of
        {os_pid, OsPid} ->
            os:cmd("kill " ++ integer_to_list(OsPid)),
            receive {Port, {exit_status, _}} -> ok
            after ?timeout_ms -> ok
            end;
        undefined -> ok
    end.
