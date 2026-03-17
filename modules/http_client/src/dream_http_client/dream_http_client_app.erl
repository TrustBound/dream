-module(dream_http_client_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _Args) ->
    ets:new(dream_http_client_ref_mapping, [set, public, named_table]),
    ets:new(dream_http_client_stream_recorders, [set, public, named_table]),
    dream_http_client_sup:start_link().

stop(_State) ->
    ok.
