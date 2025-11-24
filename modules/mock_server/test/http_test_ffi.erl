-module(http_test_ffi).
-export([make_request/1]).

%% Simple HTTP GET request using httpc
%% Returns {ok, Body} or {error, Reason}
make_request(Url) when is_binary(Url) ->
    %% Ensure httpc application is started
    inets:start(),
    
    %% Convert binary URL to list
    UrlStr = binary_to_list(Url),
    
    %% Make the HTTP request with a short timeout
    case httpc:request(get, {UrlStr, []}, [{timeout, 5000}], []) of
        {ok, {{_Version, StatusCode, _ReasonPhrase}, _Headers, Body}} ->
            if
                StatusCode >= 200 andalso StatusCode < 300 ->
                    {ok, list_to_binary(Body)};
                true ->
                    {error, list_to_binary(io_lib:format("HTTP ~p", [StatusCode]))}
            end;
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

