-module(dream_http_client_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _Args) ->
    case application:ensure_all_started(inets) of
        {ok, _} -> start_http_profile();
        {error, _} = Error -> Error
    end.

start_http_profile() ->
    case inets:start(httpc, [{profile, dream_http_client}]) of
        {ok, _Pid} -> configure_profile();
        {error, {already_started, _Pid}} -> configure_profile();
        {error, _} = Error -> Error
    end.

configure_profile() ->
    case httpc:set_options([{max_sessions, 100}, {max_pipeline_length, 0}],
                           dream_http_client) of
        ok -> start_supervisor();
        {error, _} = Error -> Error
    end.

start_supervisor() ->
    ets:new(dream_http_client_ref_mapping, [set, public, named_table]),
    ets:new(dream_http_client_stream_recorders, [set, public, named_table]),
    dream_http_client_sup:start_link().

stop(_State) ->
    inets:stop(httpc, dream_http_client),
    ok.
