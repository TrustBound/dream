# Route requests and add middleware

Your app has more than one page now. Some routes take values from the path, some are only for signed-in users, and one answers a method that isn't in the HTTP standard. You want each controller to stay small and the shared checks, like "is there a valid token?", written once. This guide builds that with Dream's router, a custom context and middleware, using the `simple`, `custom_context` and `rate_limiter` examples. Every output is what those servers really answer.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which tool to use](#which-tool-to-use)
- [Step 1: Add routes with path parameters](#step-1-add-routes-with-path-parameters)
- [Step 2: Route a custom method](#step-2-route-a-custom-method)
- [Step 3: Give each request a context](#step-3-give-each-request-a-context)
- [Step 4: Write an auth middleware](#step-4-write-an-auth-middleware)
- [Step 5: Chain middleware](#step-5-chain-middleware)
- [Step 6: Use services in middleware](#step-6-use-services-in-middleware)
- [When a request is refused](#when-a-request-is-refused)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- Routes with path parameters, such as `/users/:id/posts/:post_id`.
- A `PURGE /cache` route for a method that isn't one of the standard ones.
- An `AuthContext` that carries the signed-in user, set by an auth middleware.
- An admin route behind two middleware, and the `401` and `403` answers they give.
- A rate limit middleware that reads a shared service and adds headers to the response.
- A test of the middleware through the routes, with no server running.

## Before you start

Read [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) first: it explains controllers, the router and the server. You need Dream in your project:

```sh
gleam add dream
```

The examples run from the Dream repository. Each one starts with `make run` in its folder: `simple` and `rate_limiter` listen on port 3000, `custom_context` on 3001.

## Which tool to use

| Your situation | Use | Why |
|:---|:---|:---|
| A value in the URL path, such as an id | A `:name` segment in the route, read with `require_int` or `require_string` | The router extracts it, and the helper checks its type. |
| A value for this request only, such as the signed-in user | A custom context type | Middleware fills it in, and controllers read it. |
| Something shared by all requests, such as a database pool or a counter table | A services type | Made once at startup, and the same value for every request. |
| A check that many routes need | Middleware on those routes | Written once, and it can stop the request before the controller runs. |
| A method outside the standard set, such as `PURGE` | `Other("PURGE")` as the route's method | The router matches it like any other method. |

## Step 1: Add routes with path parameters

A route's path can have segments that start with `:`. The router matches any value there and hands it to the controller by name. The `simple` example's router has a route with two of them:

### The routes of the simple example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/router.gleam#L9-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/",
    controller: posts_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    controller: posts_controller.show,
```

The controller reads each value with `http.require_string` (or `require_int` for a number, as [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) shows). Both return a `Result`, so a missing or wrong value turns into a `400` answer instead of a crash.

Lookup is fast whatever the number of routes: Dream keeps the routes in a radix trie, so a lookup walks the segments of the path, not the list of routes. In Dream's benchmarks a lookup takes about 1.3 to 1.5 microseconds with 100 or with 1,000 routes.

## Step 2: Route a custom method

`Method` has a constructor for each standard method (`Get`, `Post`, `Put`, `Delete`, `Patch`, `Options`, `Head`, `Connect`, `Trace`) and `Other(String)` for the rest. Caching proxies use `PURGE`, so the example routes it:

### A route for PURGE <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/router.gleam#L72-L77"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  |> route(
    method: Other("PURGE"),
    path: "/cache",
    controller: cache_controller.purge,
    middleware: [],
  )
```

### The PURGE controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/cache_controller.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Cache controller
////
//// Answers PURGE, a method that is not in the HTTP standard. The router
//// matches it with Other("PURGE").

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type EmptyServices}

/// PURGE /cache
pub fn purge(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Cache purged")
}
```

Send it with curl's `-X`:

### Send PURGE to /cache <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L52"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X PURGE http://localhost:3000/cache
```

### The answer to PURGE /cache <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L707-L713"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 12
date: (the time of the request)
connection: keep-alive

Cache purged
```

The route matches only `PURGE` on `/cache`. A path that no route matches gets `404 Route not found`. A path that a route matches, with a method that no route of that path has, gets `405 Method Not Allowed` (RFC 9110, section 15.5.6). Its `allow` header lists the methods that the path has:

### Send PURGE to /missing and DELETE to /cache <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L54-L56"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X PURGE http://localhost:3000/missing
echo
curl -i -X DELETE http://localhost:3000/cache
```

### The answers to PURGE /missing and DELETE /cache <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L714-L728"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
content-length: 15
date: (the time of the request)
connection: keep-alive

Route not found
HTTP/1.1 405 Method Not Allowed
content-type: text/plain; charset=utf-8
allow: PURGE
content-length: 18
date: (the time of the request)
connection: keep-alive

Method not allowed
```

The `allow` header names the methods in alphabetical order. A path can match more than one route: a `GET` route of `/users/new` and a `POST` route of `/users/:id` both match `/users/new`, so a `DELETE` to it gets `allow: GET, POST`. `HEAD` and `OPTIONS` are methods like the others: a path with only a `GET` route answers them with `405` and `allow: GET`, unless you add a route for them. `router.allowed_methods` gives the same list for your own code.

## Step 3: Give each request a context

Context is data for one request: who's asking, a request id. Services are shared by every request: a database pool, a cache. The `custom_context` example defines its context with an optional user:

### The context type <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/context.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Custom context type for authenticated requests
////
//// This module defines a custom context type that extends the basic
//// request context with authenticated user information.

import gleam/option

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: option.Option(User))
}

pub const context = AuthContext(request_id: "", user: option.None)
```

The server gets the starting value of the context, and its services, before the router:

### Start the server with a context <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/main.gleam#L10-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  // Initialize services
  let app_services = app_services.initialize_services()

  // Start the server
  dream.new()
  |> context(app_context.AuthContext(request_id: "", user: option.None))
  |> services(app_services)
  |> router(app_router.create_router())
  |> bind("localhost")
  |> listen(3001)
```

Every request starts with this value: no request id and no user. The router's type names the context and the services, `Router(AuthContext, Services)`, so the compiler checks that every controller and middleware takes the same types:

### The routes of the custom_context example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/router.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context.{type AuthContext}
import controllers/posts_controller
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import middleware/admin_middleware.{admin_middleware}
import middleware/auth_middleware.{auth_middleware}
import services.{type Services}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/",
    controller: posts_controller.index,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id/posts/:post_id",
    controller: posts_controller.show,
    middleware: [auth_middleware],
  )
  |> route(
    method: Get,
    path: "/admin",
    controller: posts_controller.index,
    middleware: [auth_middleware, admin_middleware],
  )
}
```

## Step 4: Write an auth middleware

A middleware is a function that gets the request, the context, the services and `next`, which runs the rest of the chain (more middleware, then the controller). It can answer on its own without calling `next`, or call `next` with a changed request or context, or change the response that `next` returns:

### The auth middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/middleware/auth_middleware.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// auth_middleware.gleam
////
//// Authentication middleware that validates tokens and populates user context.

import context.{type AuthContext, type User, AuthContext, User}
import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status
import gleam/option
import services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        status.unauthorized,
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) ->
      validate_and_authenticate(request, context, services, token, next)
  }
}

fn validate_and_authenticate(
  request: Request,
  context: AuthContext,
  services: Services,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(token) {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Invalid token")
    option.Some(user) -> {
      let updated_context =
        AuthContext(request_id: context.request_id, user: option.Some(user))
      next(request, updated_context, services)
    }
  }
}

fn validate_token(token: String) -> option.Option(User) {
  case token {
    "Bearer admin-token" ->
      option.Some(User(id: "1", email: "admin@example.com", role: "admin"))
    "Bearer user-token" ->
      option.Some(User(id: "2", email: "user@example.com", role: "user"))
    _ -> option.None
  }
}
```

With no `Authorization` header, or with a token it doesn't know, it answers `401` and the controller never runs. With a known token it puts the user into the context and calls `next`. The tokens here are fixed strings to keep the example small. In your app, `validate_token` checks a signed token or looks up a session. If you keep a session id in a cookie, make the cookie with `cookie.secure_cookie`: it sets `Secure`, `HttpOnly` and `SameSite=Strict`.

## Step 5: Chain middleware

The admin route has two middleware. They run in the order of the list, and each one wraps the next:

### The admin middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/src/middleware/admin_middleware.gleam#L13-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check user role from context (auth_middleware should have populated this)
  case context.user {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) ->
      check_role(role, request, context, services, next)
  }
}

fn check_role(
  role: String,
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case role {
    "admin" -> next(request, context, services)
    _ ->
      text_response(
        status.forbidden,
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
```

`admin_middleware` reads the user that `auth_middleware` put into the context, so `auth_middleware` must come first in the list. Here are the four cases, one request each:

### Ask /admin with no token, a wrong token, a user token and an admin token <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/test/integration/readme.sh#L43-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer not-a-token" http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer user-token" http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer admin-token" http://localhost:3001/admin
```

### The four answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/test/integration/readme_output.txt#L1212-L1239"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 401 Unauthorized
content-type: text/plain; charset=utf-8
content-length: 42
date: (the time of the request)
connection: keep-alive

Unauthorized: Missing Authorization header
HTTP/1.1 401 Unauthorized
content-type: text/plain; charset=utf-8
content-length: 27
date: (the time of the request)
connection: keep-alive

Unauthorized: Invalid token
HTTP/1.1 403 Forbidden
content-type: text/plain; charset=utf-8
content-length: 49
date: (the time of the request)
connection: keep-alive

Forbidden: Admin access required. Your role: user
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 13
date: (the time of the request)
connection: keep-alive

Hello, World!
```

The first two stop in `auth_middleware`, the third in `admin_middleware`, and only the fourth reaches the controller.

## Step 6: Use services in middleware

Middleware gets the services too. The `rate_limiter` example counts requests per client in a table that lives in its services, and puts the middleware on the API routes only:

### Rate-limited routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/router.gleam#L14-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  // Public route - no rate limiting
  |> route(
    method: Get,
    path: "/",
    controller: api_controller.welcome,
    middleware: [],
  )
  // Rate-limited API endpoint
  |> route(
    method: Get,
    path: "/api",
    controller: api_controller.index,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
  // Rate-limited status endpoint
  |> route(
    method: Get,
    path: "/api/status",
    controller: api_controller.status,
    middleware: [rate_limit_middleware.rate_limit_middleware],
  )
}
```

### The rate limit middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/middleware/rate_limit_middleware.gleam#L19-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn rate_limit_middleware(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let ip = get_client_ip(request)

  case rate_limiter_service.check_and_increment(services.rate_limiter, ip) {
    Ok(status) ->
      handle_rate_limit_result(status, request, context, services, next)
    Error(_) -> handle_service_error(request, context, services, next)
  }
}

fn handle_rate_limit_result(
  status: rate_limiter_service.RateLimitStatus,
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let rate_limiter_service.RateLimitStatus(allowed, remaining, limit) = status

  case allowed {
    True ->
      allow_request_with_headers(
        request,
        context,
        services,
        next,
        remaining,
        limit,
      )
    False -> deny_request_with_headers(limit)
  }
}
```

When the client is under the limit, the middleware calls `next` and adds `X-RateLimit-Limit` and `X-RateLimit-Remaining` to the controller's response. Over the limit, it answers `429` itself. The example's README sends 15 requests in a row:

### Send 15 requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme.sh#L4-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
for i in {1..15}; do 
  echo "Request $i:"
  curl -i http://localhost:3000/api | head -5
  echo ""
done
```

The tenth gets the last allowed answer, and the eleventh is refused:

### Requests 10 and 11 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme_output.txt#L64-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Request 10:
HTTP/1.1 200 OK
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 11:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
```

If the counter table fails, this middleware lets the request through. That's a choice: an API that must never go over its limit would answer `503` there instead.

## When a request is refused

| What happened | What the client gets | Where it's decided |
|:---|:---|:---|
| No route for the path | `404 Route not found` | The router |
| A route for the path, but not for the method | `405 Method not allowed`, with `Allow` | The router |
| A path parameter has the wrong type | `400 Bad Request: id must be an integer` | `require_int` in the controller |
| No token, or an unknown token | `401` | `auth_middleware` |
| A known user without the admin role | `403` | `admin_middleware` |
| Too many requests | `429` with `Retry-After: 60` | `rate_limit_middleware` |

## Test your code

Middleware is easiest to test through the routes, with `dream.route_request` and services you build for the test. The app under test is the one from Dream's authentication snippet: a public `/`, and a `/profile` route behind an `auth_middleware` that looks the bearer token up in `Services`:

### The app under test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/authentication_guide_app.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Authentication guide: middleware, routes and a controller
////
//// Shown in docs/guides/routing.md.

import dream/http.{
  type Request, type Response, bad_request, created, get_header, json_response,
  ok, text_response, unauthorized,
}
import dream/http/request.{Get, Post, body_as_string}
import dream/router.{type Router, route, router}
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import snippets/authentication_guide_context.{
  type AuthContext, type User, AuthContext,
}

pub type Services {
  Services(tokens: List(#(String, User)))
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(header) -> verify_token(request, context, services, header, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: Services,
  header: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(services, header) {
    Error(Nil) -> text_response(unauthorized, "Invalid token")
    Ok(user) -> {
      // Enrich context with authenticated user
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

// Replace with real validation logic (for example, JWT verification)
fn validate_token(services: Services, header: String) -> Result(User, Nil) {
  case header {
    "Bearer " <> token -> list.key_find(services.tokens, token)
    _ -> Error(Nil)
  }
}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  // Public route
  |> route(method: Get, path: "/", controller: public_index, middleware: [])
  // Protected routes
  |> route(method: Get, path: "/profile", controller: show_profile, middleware: [
    auth_middleware,
  ])
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}

pub fn show_profile(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> json_response(ok, user_to_json(user))
    None -> text_response(unauthorized, "Authentication required")
  }
}

fn public_index(
  _request: Request,
  _context: AuthContext,
  _services: Services,
) -> Response {
  text_response(ok, "Welcome")
}

fn create_post(
  request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user, body_as_string(request) {
    Some(user), Ok(text) ->
      text_response(created, user.email <> " wrote: " <> text)
    Some(_user), Error(Nil) ->
      text_response(bad_request, "Request body is not text")
    None, _ -> text_response(unauthorized, "Authentication required")
  }
}

fn user_to_json(user: User) -> String {
  json.object([
    #("id", json.string(user.id)),
    #("email", json.string(user.email)),
    #("role", json.string(user.role)),
  ])
  |> json.to_string
}
```

The test gives the app one known token, so it controls who is signed in:

### Test the middleware through the routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_routing_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Routing guide: a test of an auth middleware through the routes
////
//// The app is test/snippets/authentication_guide_app.gleam: a public route,
//// and a /profile route behind auth_middleware, which looks the bearer
//// token up in Services.

import dream/dream
import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/authentication_guide_app.{Services}
import snippets/authentication_guide_context.{User, default_context}

// One known token, so the tests control who is signed in
fn test_services() -> authentication_guide_app.Services {
  Services(tokens: [
    #("ada-token", User(id: "1", email: "ada@example.com", role: "admin")),
  ])
}

fn get(path: String, headers: List(Header)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: headers,
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn send(request: Request) -> response.Response {
  dream.route_request(
    authentication_guide_app.create_router(),
    request,
    default_context,
    test_services(),
  )
}

pub fn tests() -> TestSuite {
  describe("auth middleware", [
    it("lets a request with no token reach the public route", fn() {
      // Arrange
      let request = get("/", [])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Welcome"))
      |> or_fail_with("GET / should answer Welcome")
    }),
    it("answers 401 for /profile with no token", fn() {
      // Arrange
      let request = get("/profile", [])

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(401)
      |> or_fail_with("GET /profile with no token should answer 401")
    }),
    it("answers 401 for /profile with an unknown token", fn() {
      // Arrange
      let request =
        get("/profile", [Header("Authorization", "Bearer unknown-token")])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Invalid token"))
      |> or_fail_with("an unknown token should answer Invalid token")
    }),
    it("gives the signed-in user to the controller", fn() {
      // Arrange
      let request =
        get("/profile", [Header("Authorization", "Bearer ada-token")])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text(
        "{\"id\":\"1\",\"email\":\"ada@example.com\",\"role\":\"admin\"}",
      ))
      |> or_fail_with("GET /profile should answer the user as JSON")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_routing_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
auth middleware
  ✓ answers 401 for /profile with an unknown token
  ✓ answers 401 for /profile with no token
  ✓ gives the signed-in user to the controller
  ✓ lets a request with no token reach the public route

Summary: 4 run, 0 failed, 4 passed in 0ms
```

[Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) shows how to test a middleware alone, with a `next` that records what it got.

## Common pitfalls

- **The path parameter name in the route and in the controller differ.** The router checks names at run time, not at compile time. If the route says `:user_id` and the controller asks for `"id"`, every request gets `400`. Keep the two in step, and test the route.
- **Middleware in the wrong order.** A middleware that reads the user must come after the one that sets it. With `[admin_middleware, auth_middleware]`, every admin request gets `401 Unauthorized: Not authenticated`.
- **Business logic in middleware.** Middleware is for checks that many routes share. Logic that belongs to one action goes in the controller, or in an operation (see [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html)).
- **Per-request data in services.** Services are shared by every request at the same time. Put the user in the context, never in services.
- **A `405` where you expected `404`.** A route of another method matches the path, for example a `GET` route of `/users/:id` matches `/users/new`. The `allow` header of the answer names the methods that match.

## Where to go next

- [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html): path parameters, query strings, JSON and forms.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): services with a database pool.
- [Concepts](https://github.com/TrustBound/dream/blob/3.0.0/docs/concepts.md): context, services and middleware explained.
- [Core patterns](https://github.com/TrustBound/dream/blob/3.0.0/docs/concepts/patterns.md): the middleware onion and the other patterns.
- The API reference of `dream/router` on [HexDocs](https://hexdocs.pm/dream/3.0.0/dream/router.html).
