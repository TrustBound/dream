-module(dream_http_client_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ConnManager = #{
        id => dream_http_conn_manager,
        start => {dream_http_conn_manager, start_link, []},
        restart => permanent,
        type => worker
    },
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [ConnManager]}}.
