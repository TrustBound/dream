[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Build your first Dream server

# Build your first Dream server

You want a web server in Gleam that answers a request, and you want to understand every line of it before you add more. This guide starts from an empty folder and ends with a running server, a look at what it answers when a request doesn't match, and a test that sends requests through your routes without opening a port. Everything here is the code of `examples/simplest` in the Dream repository, and every output is what that example's server really answers.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which starting point to use](#which-starting-point-to-use)
- [Step 1: Write the server](#step-1-write-the-server)
- [Step 2: Run it and send a request](#step-2-run-it-and-send-a-request)
- [Step 3: See what an unknown request gets](#step-3-see-what-an-unknown-request-gets)
- [How the pieces fit](#how-the-pieces-fit)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A server on `localhost:3000` that answers `GET /` with `Hello, World!`.
- The exact HTTP answer for a path and a method that have no route.
- A test with `dream_test` that checks the answers through your router, with no server running.

## Before you start

You need [Gleam](https://gleam.run/getting-started/installing/) and Erlang/OTP. The Dream repository tests with Gleam 1.19 and OTP 28. Make a project with `gleam new hello_dream`, go into its folder, and add Dream:

```sh
gleam add dream
```

For the test at the end you also need Dream Test as a dev dependency:

```sh
gleam add --dev dream_test
```

To run the example from the Dream repository instead, start it with the commands of its integration run:

### Start examples/simplest <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/simplest
make run
```

`make run` runs `gleam run -m main`.

## Which starting point to use

| Your situation | Start from | Why |
|:---|:---|:---|
| You want to see the smallest working app | `examples/simplest` (this guide) | One file: a controller, a router and the server. |
| You need path parameters, request bodies, cookies | `examples/simple`, with [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) | Several controllers in their own modules. |
| You need middleware and a per-request context | `examples/custom_context`, with [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) | Shows the context type and auth middleware. |
| You need a database | `examples/database`, with [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) | PostgreSQL, `dream_model` and migrations. |

## Step 1: Write the server

Put this in `src/hello_dream.gleam` (in the example it's `src/main.gleam`):

### The whole app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/src/main.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// main.gleam
////
//// The simplest possible Dream application.
//// Everything in one file - a controller, a router, and the server setup.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, type Router, route, router}
import dream/servers/mist/server

/// The controller of GET / - returns "Hello, World!"
pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Hello, World!")
}

/// The routes of the app. Public, so a test can send requests through them.
pub fn app_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

/// Starts the server on localhost, port 3000
pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.router(app_router())
    |> server.bind("localhost")
    |> server.listen(3000)
}
```

There are three pieces, and every Dream app has them:

- **A controller.** `index` is a plain function. It gets the `Request`, the context and the services, and returns a `Response`. This one doesn't need any of its arguments yet, so their names start with `_`. `text_response(status.ok, ...)` builds a `200 OK` with a `text/plain` body.
- **A router.** `router()` makes an empty router, and `route(...)` adds one route: the method, the path, the controller, and a list of middleware (none yet). The `|>` pipe passes the value on its left as the first argument of the call on its right, so read it as "then".
- **The server.** `server.new()` makes a server with the default context and services. `server.router` gives it the routes, `server.bind("localhost")` keeps it on your machine, and `server.listen(3000)` starts it and blocks forever.

`app_router` is public on purpose: a test can call it and send requests through the same routes the server uses. You'll do that at the end.

## Step 2: Run it and send a request

Run `gleam run` in your project (the example's `make run` does the same). Then ask it for `/`:

### Ask for the root path <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/
```

### The answer to GET / <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme_output.txt#L2-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 13
date: (the time of the request)
connection: keep-alive

Hello, World!
```

Dream filled in the `content-type` from `text_response` and the `content-length` from the body. The `date` line has the real time of your request. On this page it's replaced, so the output stays the same on every run.

## Step 3: See what an unknown request gets

The router has one route. A path it doesn't know gets a `404`:

### Ask for a path with no route <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme.sh#L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/missing
```

### The answer to GET /missing <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme_output.txt#L9-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
content-length: 15
date: (the time of the request)
connection: keep-alive

Route not found
```

A known path with another method gets `405 Method Not Allowed`. The route is for `GET`, so a `POST /` gets `405`, and the `allow` header names the method that the path has:

### Send POST to the root path <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme.sh#L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3000/
```

### The answer to POST / <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme_output.txt#L16-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 405 Method Not Allowed
content-type: text/plain; charset=utf-8
allow: GET
content-length: 18
date: (the time of the request)
connection: keep-alive

Method not allowed
```

Dream answers `404 Route not found` for a path that no route matches, and `405 Method not allowed` for a known path with a method that it has no route for. A client can tell the two apart.

## How the pieces fit

When a request arrives, Dream turns it into a `Request` value, looks up the route by method and path, runs the route's middleware in order, then the controller, and sends the `Response` back. No global state is involved: the context and the services you give the server are the only values your controllers get, besides the request.

Two notes on the builder:

- If you add your own context or services later, call `server.context(...)` and `server.services(...)` before `server.router(...)`. The router's type names the context and services types, so the compiler rejects the other order.
- `server.listen` never returns when the server starts. If it cannot start, for example because the port is in use, it returns the error. Then `let assert Ok(Nil) =` stops the program with that error and a non-zero exit code. [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html) shows those errors and how to handle them.

### The same server, shorter

Gleam infers types, so a small server can leave out its type annotations. This version is the example in the Dream README. It does the same job as the app above:

### Hello, world <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_hello_server.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// README: A Quick Example
////
//// The smallest useful Dream server, as shown in the root README.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_request, _context, _services) {
  text_response(ok, "Hello, world!")
}

pub fn app_router() {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.router(app_router())
    |> server.bind("localhost")
    |> server.listen(3000)
}
```

## Test your code

You don't need a running server to test your routes. `dream.route_request` sends a `Request` through a router, with the context and services you give it, and returns the `Response` the server would send. Put this in `test/hello_dream_test.gleam`:

### Test the routes of the app <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_getting_started_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Getting started guide: the test of the app
////
//// In your project this is test/hello_dream_test.gleam, and the import of
//// the app is `import hello_dream as app`.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Post, Request}
import dream/http/response.{Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_getting_started_app as app

// gleam test runs this: it runs the tests and prints the report
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

// A request with no body, headers or cookies
fn request_to(method: request.Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

// Sends the request through the routes of the app, as the server does
fn send(request: Request) -> response.Response {
  dream.route_request(app.app_router(), request, EmptyContext, EmptyServices)
}

pub fn tests() -> TestSuite {
  describe("hello app", [
    it("answers GET / with 200", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("GET / should answer 200")
    }),
    it("answers GET / with Hello, World!", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Hello, World!"))
      |> or_fail_with("GET / should answer Hello, World!")
    }),
    it("answers an unknown path with 404", fn() {
      // Arrange
      let request = request_to(Get, "/missing")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(404)
      |> or_fail_with("GET /missing should answer 404")
    }),
    it("answers POST / with 405", fn() {
      // Arrange
      let request = request_to(Post, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(405)
      |> or_fail_with("POST / should answer 405")
    }),
  ])
}
```

`request_to` builds a request by hand: a `Request` is a plain record, so a test can make any request it wants. `send` is the one place that knows how the app is wired. Each test checks one thing about one answer.

Run `gleam test`. The report lists each test:

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_getting_started_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
hello app
  ✓ answers GET / with 200
  ✓ answers GET / with Hello, World!
  ✓ answers POST / with 405
  ✓ answers an unknown path with 404

Summary: 4 run, 0 failed, 4 passed in 0ms
```

The report sorts the tests by name, so `answers POST /` comes before `answers an unknown path`. [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) goes further: path parameters, JSON bodies, middleware and a test against the real server.

## Common pitfalls

- **The port is taken.** A second `gleam run` while the first one still runs stops with `Port 3000 already in use on localhost`. Stop the other process or pick another port.
- **The server isn't reachable from another machine or a container.** `bind("localhost")` listens on your machine only. Use `bind("0.0.0.0")` when something else must reach it, as in [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html).
- **A `405` where you expected `404`.** A route of another method matches the path. The `allow` header names its methods. See Step 3.
- **The compiler complains about the router's type after you add a context.** Call `server.context` and `server.services` before `server.router`.

## Where to go next

- [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html): more routes, path parameters, custom methods and middleware.
- [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html): query strings, JSON bodies and forms.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html).
- [How it works](https://github.com/TrustBound/dream/blob/3.0.0/docs/concepts/how-it-works.md): the path of a request through Dream.
- The API reference on [HexDocs](https://hexdocs.pm/dream/3.0.0/).
