# Dream 3.0.0 Release Notes

**Release Date:** not released yet (draft)

This release makes HTTP/2 work end to end in Dream's Mist server adapter, for browsers over HTTPS and for clients over plain HTTP. To ship the fixes, the adapter now uses two packages that we publish, `dream_http_server` and `dream_socket_server`.

It is a major version because a request body now has one type, `RequestBody`, for text, bytes and streams. Read the Migration Guide before you upgrade. Every code example in the docs, the READMEs and the doc comments is now a tested snippet.

## Key Highlights

- **HTTP/2 works for real workloads**: Requests with bodies, large uploads, large responses, file responses, server-sent events and streamed responses all work over HTTP/2
- **HTTPS with `server.tls()`**: Browsers and other clients agree on HTTP/2 during the TLS handshake. Over plain HTTP, clients get HTTP/2 with prior knowledge
- **Faster and lighter under load**: HTTP/2 throughput is level with Bandit or ahead of it on the same machine, and memory under load is much lower, most of all on macOS
- **New server packages**: Dream depends on `dream_http_server` and, through it, `dream_socket_server`. Read "Upgrading" first if your project lists `mist` or `glisten` itself
- **`gleam_stdlib` 1.x**: Dream now requires `gleam_stdlib` 1.0.0 or later
- **One request body type (breaking)**: `Request.body` is a `RequestBody`: `Text`, `Bytes` or `Stream`. Binary uploads no longer arrive as `""`. New `require_json` reads and decodes a JSON body in one step
- **Tested docs**: every code block in the guides, READMEs and doc comments comes from a snippet that the tests compile and run

## What's New

### HTTP/2 That Works End to End

Before this release, HTTP/2 in the Mist server adapter was not finished. Requests with a body got no response, every request left a process behind, large responses stalled, and several kinds of client input closed or crashed the whole connection. All of that is fixed, with no change to your application code:

- Requests with a body get a response
- Request bodies are read to the end of the stream, with or without a `content-length`, and are checked against it when it is given
- Large responses and large headers are split into frames, and flow control is respected in both directions
- Server-sent events, streamed (chunked) responses and file responses work
- A slow client slows its own response and no longer builds up memory on the server
- Bad input gets the error the HTTP/2 specification asks for and no longer closes or crashes the whole connection
- A handler that fails answers 500 on its own stream only
- The process that serves a request is cleaned up when the request ends
- At most 100 streams run at once on a connection

The full list, one line per change, is in the [changelog of the server package](https://github.com/TrustBound/mist/blob/dream-http-server/CHANGELOG.md).

### HTTPS, and HTTP/2 for Every Kind of Client

`server.tls()` serves HTTPS from a certificate and key.

#### Serve HTTPS <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/server_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_request, _context, _services) {
  text_response(ok, "Hello over HTTPS")
}

pub fn start(certfile: String, keyfile: String, port: Int) {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: index, middleware: []),
  )
  |> server.tls(certfile:, keyfile:)
  |> server.listen_with_handle(port)
}
```

One port serves every client with the protocol it can use:

| Connection | How the client gets HTTP/2 |
|------------|----------------------------|
| HTTPS | The client and server agree on HTTP/2 during the TLS handshake (ALPN). Browsers do this. |
| Plain HTTP, prior knowledge | The client sends HTTP/2 from its first byte, as proxies set to speak h2c to their backends do. |

Every other client gets HTTP/1.1. Dream does not upgrade HTTP/1.1 connections with `Upgrade: h2c`: RFC 9113 deprecated it, and it can let a client get past a proxy's rules. The [HTTP/2 guide](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md) covers HTTPS, proxies and how to check the protocol.

### Faster and Lighter Under Load

Measured with `h2load -D 10 -t 32 -c 256` against a small test application, on an Apple M1 Max (10 cores, 64 GB, macOS 26.5.1, OTP 28). The machine was quiet but not empty.

| HTTP/2 | mist 6.0.3 | Dream 3.0.0's server | Bandit |
|--------|-----------|----------------------|--------|
| Requests per second | 42k to 74k | 95k | 95k |
| With 100 streams per connection | 80k to 91k | 130k | 128k |
| 1 MB responses per second | | 7.9k | 1.5k |
| 8 MB uploads per second, 8 connections | | 340 | 347 |

| Memory under 256 connections | glisten 9.0.1 | Dream 3.0.0's server |
|------------------------------|---------------|----------------------|
| macOS | about 3 GB | 155 MB |
| Linux | 139 MB | about 70 MB |

The large memory gain is mostly a macOS effect. Linux gets a smaller one, about half.

### Dream's HTTP Server Packages

Dream's router, controllers and HTTP types do not depend on any web server. The server is an adapter, and the one Dream ships today is built on [mist](https://github.com/rawhat/mist), the HTTP server, and mist is built on [glisten](https://github.com/rawhat/glisten), the socket server. Both are by Alex Manning (rawhat) and their contributors. We chose mist for the adapter because we would rather support the libraries the Gleam community already shares than go our own way.

The adapter needed many HTTP/2 fixes in mist and one fix in glisten. We are giving all of them back upstream, which takes time for this many changes. Until upstream releases contain them, the adapter uses two forks that we publish:

| Package | What it is |
|---------|------------|
| [`dream_http_server`](https://hex.pm/packages/dream_http_server) | mist 6.0.3 plus fixes, most of them for HTTP/2, and HTTP/2 over TLS |
| [`dream_socket_server`](https://hex.pm/packages/dream_socket_server) | glisten 9.0.1 plus a socket buffer fix |

Both keep the upstream module names (`mist`, `glisten`). They are named for what they do, so they do not appear when people search Hex for mist or glisten. They are temporary: when upstream releases contain the fixes, Dream goes back to `mist` and `glisten`. See [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/main/docs/contributing/http-server-packages.md) for the reasons and for how to go back.

### Streaming Uses Chunked Responses

Dream's streaming adapter now uses the server's actor-based chunked responses. Dream's public streaming API (`stream_response`, `sse_response`, `ResponseBody.Stream`) is unchanged.

### One Request Body Type

`Request.body` is now a `RequestBody`, and the `Request.stream` field is gone.

#### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L238-L242"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(BitArray))
}
```

On a route made with `route`, a body that is valid UTF-8 arrives as `Text`, and any other body arrives as `Bytes` with the exact bytes. On a route made with `stream_route`, the body arrives as `Stream`. In Dream 2, a body that was not valid UTF-8, such as a PNG upload, reached the controller as `""` with no error. New helpers: `require_json(request, decoder)` and `body_as_string(request)`. The Migration Guide shows each change.

### Broadcaster Removes Stopped Subscribers

The broadcaster removes a subscriber when the process that subscribed stops, so a WebSocket or SSE connection no longer has to unsubscribe before it ends. New function: `broadcaster.count_subscribers`.

### Tested Docs

Every Gleam code block in the guides, the READMEs, the doc comments and SECURITY.md comes from a snippet file that the tests compile and run. Each block has a "tested snippet" badge that links to its snippet at this release's tag. Converting them found and fixed wrong examples across the docs.

`make check-snippets` keeps it that way. It checks that every Gleam code block has a heading with the badge and shows the same code as its snippet file. It runs in the pre-commit hook, in CI and before every publish, so a wrong example cannot ship. It found 512 code blocks and 5 diff blocks with no problems.

## Bug Fixes

### Router Falls Back to the Next Route

When a route fit the start of a path but failed deeper down, the router returned 404. It now tries the next route. With `/users/:id/posts` and `/users/**rest`, `GET /users/1/comments` now finds `/users/**rest`.

### `server.stop` Stops the Server From Any Process

`server.stop` did nothing unless the process that started the server called it. It now stops the server from any process, and returns after the server is down.

### Values That Contain `=`

A form field, query parameter or cookie value that contains `=` (`token=a=b`) was dropped or came back empty. The value is now kept (`a=b`).


### Stray 500 After a Fast Streamed Response

Over HTTP/1.1, a streamed response that finished very quickly could be followed by a stray `500 Internal Server Error`. A keep-alive client could read that 500 as the answer to its next request. The first chunk is now sent only after the server has handed the socket to the stream.

### Response Lost to a Connection Reset

Over HTTP/1.1, a response sent just before the connection closed could be lost to a connection reset. The server now reads the remaining request data before it closes.

## Known Limits

- A single HTTP/2 connection uploads large bodies at about 89% of Bandit's speed. With 8 connections it is level.
- The server does not enforce the connection-level receive window. Unread request data on one connection is limited by 100 streams of 1 MiB each.
- The server packages have three new settings (read timeout, send timeout, stream window size). Dream does not expose them yet.

## Testing

- Dream's own tests: 952 run, 0 failed, in about 7 seconds (MacBook, OTP 28, Gleam 1.17.0)
- `dream_http_client`: 281 passed. Its `h2c_test` drives a real HTTP/2 client against the mock server, which serves its requests through Dream's server adapter
- `dream_mock_server`: 25 passed
- `dream_http_server` 1.2.0: 100 passed, on Gleam 1.17.0 and on Gleam 1.14.0 with OTP 28. Each of its fixes has a test that fails without the fix
- `dream_socket_server`: 6 passed
- Integration tests: every scenario of the mock server and ten examples runs twice, over HTTP/1.1 and over HTTP/2 with TLS, through `dream_http_client`

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 3.0.0 and < 4.0.0"
```

Then run:

```bash
gleam deps update dream
```

### Migration Guide

Most projects need only the request body change in step 3. Steps 1, 2 and 4 apply only in the cases they name.

Each "before and after" below is a diff of a real file in this repository, from Dream 2.4.1 to Dream 3.0.0. The badge on a diff links to that file in GitHub's compare view.

#### 1. Your `gleam.toml` lists `mist` or `glisten`

Dream's server packages define the same modules, and Gleam stops the build with a duplicate module error when two packages do. Replace `mist` with `dream_http_server`, as Dream's own `gleam.toml` did:

#### Replace `mist` with `dream_http_server` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-7cd1e07e743a743d849d706b1dafd77e5839325c3b7327d3f060335605d525be"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/gleam.toml
+++ b/gleam.toml
 [dependencies]
-gleam_stdlib = ">= 0.44.0 and < 2.0.0"
-mist = ">= 5.0.3 and < 6.0.0"
+gleam_stdlib = ">= 1.0.0 and < 2.0.0"
+# dream's HTTP server: a fork of mist 6.0.3 with HTTP/2 fixes, published under
+# its own name with mist's module names.
+dream_http_server = ">= 1.2.0 and < 2.0.0"
```

Replace `glisten` with `dream_socket_server = ">= 1.0.0 and < 2.0.0"` in the same way. Your `import mist` and `import glisten` lines stay as they are, because the module names are the same.

#### 2. Your project still uses `gleam_stdlib` 0.x

Dream 2.4.1 accepted `gleam_stdlib` from 0.44. Dream 3.0.0 requires `>= 1.0.0 and < 2.0.0`. The diff in step 1 shows this change in Dream's own `gleam.toml`.

#### 3. Request bodies

`RequestBody` replaces `body: String` and `stream`.

**What changed.** `Request.body` is now a `RequestBody`. The `Request.stream` field is gone.

#### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L238-L242"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(BitArray))
}
```

- On a route made with `route`, a body that is valid UTF-8 arrives as `Text`. An empty body is `Text("")`. Any other body arrives as `Bytes`, with the exact bytes.
- On a route made with `stream_route`, the body arrives as `Stream`.

**Why.** In Dream 2, a body that was not valid UTF-8 (for example a PNG or a PDF upload) reached the controller as `""`, with no error. The `body` and `stream` fields could also disagree. One value with three shapes removes both problems, and it matches `ResponseBody`.

**How to upgrade.**

**A controller that parses JSON.** Use the new `require_json`. It reads the body as text, parses the JSON, runs your decoder, and returns `BadRequest` with the reason when a step fails. The database example made this change:

#### Parse a JSON body with `require_json` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-93ef6055589a796ca5033f0c627fc0d8178a9c5bf171b6bf79301e81cbe33e1b"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/examples/database/src/controllers/users_controller.gleam
+++ b/examples/database/src/controllers/users_controller.gleam
@@ -16,13 +14,6 @@ import services.{type Services}
-fn parse_user_data(body: String) -> Result(#(String, String), Error) {
-  case validate_json(body, user.decoder()) {
-    Ok(d) -> Ok(d)
-    Error(_) -> Error(BadRequest("Invalid user data"))
-  }
-}
@@ -65,8 +56,7 @@ pub fn create(
   let result = {
-    use data <- result.try(parse_user_data(request.body))
-    let #(name, email) = data
+    use #(name, email) <- result.try(require_json(request, user.decoder()))
     let db = services.database.connection
```

`validate_json(text, decoder)` did not change. Use it when you already have a `String`.

**A controller that needs the body as text.** Use `body_as_string(request)`. It returns `Error(Nil)` when the body is not valid UTF-8. The mock server used `request.body` as a `String`, and now reads it with `body_as_string`:

#### Read a text body with `body_as_string` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-aafe04b74828dcf43f35dd72b3ed668640b1d9b18a0ad42c3915b4810f92ee54"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/modules/mock_server/src/dream_mock_server/controllers/api_controller.gleam
+++ b/modules/mock_server/src/dream_mock_server/controllers/api_controller.gleam
@@ -31,10 +31,7 @@ pub fn post(
-  json_response(
-    status.created,
-    api_view.post_to_json(request.path, request.body),
-  )
+  echo_text_body(request, status.created, api_view.post_to_json)
@@ -43,7 +40,32 @@ pub fn put(
+/// Echo a text request body as JSON, or reply 400 when the body is not text
+fn echo_text_body(
+  request: Request,
+  status_code: Int,
+  format_echo: fn(String, String) -> String,
+) -> Response {
+  case body_as_string(request) {
+    Ok(body) -> json_response(status_code, format_echo(request.path, body))
+    Error(Nil) ->
+      json_response(
+        status.bad_request,
+        api_view.error_to_json("Request body is not UTF-8 text"),
+      )
+  }
 }
```

**A controller or middleware that reads the stream.** Match `Stream` on `request.body` in place of `Some` on `request.stream`:

#### Read a stream from `request.body` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-96161bd1d29b10b5817d71e3db6be67d9a8494e6ea36bc113379cb3b2743ce32"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/examples/streaming_capabilities/src/controllers/stream_controller.gleam
+++ b/examples/streaming_capabilities/src/controllers/stream_controller.gleam
@@ -50,13 +50,14 @@ pub fn echo_transform(
-  case request.stream {
-    Some(stream) -> {
+  case request.body {
+    Stream(stream) -> {
       // Just echo the stream back!
       // The middleware does the heavy lifting (uppercase -> replace space)
       stream_response(status.ok, stream, "text/plain")
     }
-    None -> text_response(status.bad_request, "Expected streaming request body")
+    Text(_) | Bytes(_) ->
+      text_response(status.bad_request, "Expected streaming request body")
   }
```

**Code that builds a `Request`** (tests, middleware). Remove `stream:` and give `body:` a `RequestBody`. The test fixtures made this change:

#### Build a `Request` with a `RequestBody` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-35a52c8b99fa4dc8d5c395580d1a99ff19404fdc3316a228fb5ab2dbecabb54c"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/test/fixtures/request.gleam
+++ b/test/fixtures/request.gleam
@@ -20,8 +22,7 @@ pub fn create_request(method: Method, path: String) -> Request {
-    body: "",
-    stream: option.None,
+    body: Text(""),
@@ -62,7 +72,7 @@ pub fn create_streaming_request(
-  Request(..create_request(method, path), stream: option.Some(stream))
+  Request(..create_request(method, path), body: Stream(stream))
```

**A module that uses request and response bodies together.** `Text`, `Bytes` and `Stream` are also the `ResponseBody` constructors. Qualify the request side: `request.Text`, `request.Bytes`, `request.Stream`.

**Other behaviour changes.**

- `require_form` returns `BadRequest("Request body is not text")` for a body that is not text. It now also reads a `Stream` body.
- A binary upload on a `route` now arrives as `Bytes`. In Dream 2 it arrived as `""`.

#### 4. Your code names the `Dream` type, or calls `context()` or `services()` after `router()`

**What changed.** The `Dream` type has a fourth type parameter, `router`. It is `NoRouter` until you call `server.router()`, and then it is the `Router(context, services)` you gave. The compiler now enforces the builder order:

- `server.context()` and `server.services()` accept only an app that has no router yet. Call them before `server.router()`.
- `server.listen()` and `server.listen_with_handle()` accept only an app that has a router.
- `server.router()` accepts only an app that has no router yet, so you call it one time.
- `bind()`, `max_body_size()` and `tls()` work before or after `router()`.

The accessors in `dream/dream` follow the new shape. `get_router` returns `NoRouter` or the router, not an `Option`. `get_services` returns the services, not an `Option`. `create` takes the router state and the services without an `Option`.

**Why.** A router's type includes the context and services types: `Router(context, services)`. `context()` and `services()` change those types, so a router given before them cannot stay in the app. In Dream 2, `context()` and `services()` dropped the router with no error, and `listen()` crashed at start. The compiler caught the wrong order only when the controllers used the context type. A router whose controllers ignore the context compiled, and so did an app with no router at all.

**How to upgrade.**

- If the build fails with a type mismatch between `NoRouter` and `Router(...)`, move `context()` and `services()` above `router()`, and make sure that `router()` comes before `listen()`.
- If you write the `Dream` type, add the fourth parameter. This app has its own context and services, in the right order:

##### Context, services, router, in that order <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_type.gleam#L22-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_server() -> Dream(
  mist.Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(Services(
    database_url: "postgres://localhost/app",
    cache_size: 100,
  ))
  |> server.router(my_router())
}
```

- If you use `dream.get_router` or `dream.get_services`, remove the `Some` and `None` cases.

#### 5. Other changes that can affect an app

- **Router fallback.** When a route fits the start of a path but fails deeper down, the router now tries the next route. With `/users/:id/posts` and `/users/**rest`, `GET /users/1/comments` now finds `/users/**rest`. In Dream 2 it returned 404. A wildcard route can now receive requests that got a 404 before.
- **`server.stop`.** `stop` now stops the server from any process, and it returns after the server is down. In Dream 2 it did nothing unless the process that started the server called it.
- **Broadcaster.** The broadcaster removes a subscriber when the process that subscribed stops. You do not have to call `unsubscribe` before a WebSocket or SSE connection ends. New function: `broadcaster.count_subscribers`.
- **Form, query string and cookie values.** A value that contains `=` is kept. `token=a=b` gives the value `a=b`. In Dream 2 the form field and the query parameter were dropped, and the cookie value was empty.
- **SSE `on_init` selector.** The selector that `on_init` returns is used, as in Dream 2.4.

## Acknowledgements

To Alex Manning and the contributors to mist and glisten. Problems with the HTTP server in this release belong to us: report them at [TrustBound/mist](https://github.com/TrustBound/mist/issues) or [TrustBound/dream](https://github.com/TrustBound/dream/issues), not to the mist or glisten maintainers.

## Documentation

- [dream](https://hexdocs.pm/dream) - v3.0.0
- [dream_http_server](https://hexdocs.pm/dream_http_server) - v1.2.0
- [dream_socket_server](https://hexdocs.pm/dream_socket_server) - v1.0.0
- [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/main/docs/contributing/http-server-packages.md)
- [HTTP/2 guide](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md)
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/streaming-api.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
