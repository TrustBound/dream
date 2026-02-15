-module(http_test_ffi).
-export([make_request/1, make_request_full/1, make_request_with_method/3]).

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

%% GET request returning {ok, {StatusCode, Body}} or {error, Reason} (for config-mode tests).
make_request_full(Url) when is_binary(Url) ->
    inets:start(),
    UrlStr = binary_to_list(Url),
    case httpc:request(get, {UrlStr, []}, [{timeout, 5000}], []) of
        {ok, {{_Version, StatusCode, _ReasonPhrase}, _Headers, Body}} ->
            {ok, {StatusCode, list_to_binary(ensure_string(Body))}};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

%% Request with method and body; returns {ok, {StatusCode, Body}} or {error, Reason}.
make_request_with_method(Url, Method, Body) when is_binary(Url), is_binary(Method), is_binary(Body) ->
    inets:start(),
    UrlStr = binary_to_list(Url),
    MethodAtom = method_to_atom(binary_to_list(Method)),
    BodyStr = binary_to_list(Body),
    Request = {UrlStr, [], "application/octet-stream", BodyStr},
    case httpc:request(MethodAtom, Request, [{timeout, 5000}], []) of
        {ok, {{_Version, StatusCode, _ReasonPhrase}, _Headers, RespBody}} ->
            {ok, {StatusCode, list_to_binary(ensure_string(RespBody))}};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

ensure_string(Body) when is_list(Body) -> Body;
ensure_string(Body) when is_binary(Body) -> binary_to_list(Body).

method_to_atom("GET") -> get;
method_to_atom("POST") -> post;
method_to_atom("PUT") -> put;
method_to_atom("DELETE") -> delete;
method_to_atom("PATCH") -> patch.

