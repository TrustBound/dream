# Dream 3.0.0 Release Notes

**Release Date:** not released yet (draft)

This release makes HTTP/2 work end to end in Dream's Mist server adapter, for browsers over HTTPS and for clients over plain HTTP. To ship the fixes, the adapter now uses two packages that we publish, `dream_http_server` and `dream_socket_server`.

It is a major version because a request body now has one type, `RequestBody`, for text, bytes and streams, a streamed body gives a failed read as a value, `Method` holds every HTTP method, and `validate_json` returns every decode error. Read the Migration Guide before you upgrade. Every code example in the docs, the READMEs and the doc comments is now a tested snippet.

## Key Highlights

- **HTTP/2 works for real workloads**: Requests with bodies, large uploads, large responses, file responses, server-sent events and streamed responses all work over HTTP/2
- **HTTPS with `server.tls()`**: Browsers and other clients agree on HTTP/2 during the TLS handshake. Over plain HTTP, clients get HTTP/2 with prior knowledge
- **Faster and lighter under load**: HTTP/2 throughput is level with Bandit or ahead of it on the same machine, and memory under load is much lower, most of all on macOS
- **New server packages**: Dream depends on `dream_http_server` and, through it, `dream_socket_server`. Read "Upgrading" first if your project lists `mist` or `glisten` itself
- **`gleam_stdlib` 1.x**: Dream now requires `gleam_stdlib` 1.0.0 or later
- **One request body type (breaking)**: `Request.body` is a `RequestBody`: `Text`, `Bytes` or `Stream`. Binary uploads no longer arrive as `""`. New `require_json` reads and decodes a JSON body in one step
- **A failed read is a value (breaking)**: each item of a `Stream` body is a `Result`. When the connection breaks, the controller gets an `Error` item and decides the answer
- **Every method keeps its name (breaking)**: `Method` has `Connect`, `Trace` and `Other(String)`. `PURGE /` no longer runs the `GET /` controller
- **Every validation error (breaking)**: `validate_json` returns a list with one `ValidationError` for each field that failed
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

#### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L260-L274"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(Result(BitArray, BodyReadError)))
}

/// Why a read of a streamed request body failed
///
/// The server reports one cause. `MalformedBody` means that the server could
/// not read the rest of the body: the connection closed before the end of
/// the body, no data came in the read timeout, or the chunked framing was
/// not valid. The server does not tell these cases apart.
pub type BodyReadError {
  MalformedBody
}
```

On a route made with `route`, a body that is valid UTF-8 arrives as `Text`, and any other body arrives as `Bytes` with the exact bytes. On a route made with `stream_route`, the body arrives as `Stream`. Each item of the stream is `Ok(chunk)`, or `Error(MalformedBody)` when a read from the connection fails. After an `Error` item the stream ends. In Dream 2, a body that was not valid UTF-8, such as a PNG upload, reached the controller as `""` with no error. New helpers: `require_json(request, decoder)` and `body_as_string(request)`. The Migration Guide shows each change.

### Broadcaster Removes Stopped Subscribers

The broadcaster removes a subscriber when the process that subscribed stops, so a WebSocket or SSE connection no longer has to unsubscribe before it ends. New function: `broadcaster.count_subscribers`.

### Tested Docs

Every Gleam code block in the guides, the READMEs, the doc comments and SECURITY.md comes from a snippet file that the tests compile and run. Each block has a "tested snippet" badge that links to its snippet at this release's tag. Converting them found and fixed wrong examples across the docs. Every public function has a tested example in its doc comment, and every public type and constant has a doc comment.

`make check-snippets` keeps it that way. It checks that every Gleam code block has a heading with the badge and shows the same code as its snippet file. It runs in the pre-commit hook, in CI and before every publish, so a wrong example cannot ship.

Every other code block is proven too. A shell command is a line of a script that CI or a test runs, such as `scripts/check.sh` or the `test/integration/start.sh` and `readme.sh` of an example. Shown output is a file that a test compares with the real output: the integration run of each example runs the requests of its README against the running server and compares what they print. A Dockerfile, a Compose file, a Makefile, a migration, a query, a template or a script is a copy of the real file that a test or CI uses. The new `examples/deployment` has the Dockerfile and the Compose file of the deployment guide, and `make test-docker` builds and starts them. A block that nothing can run, such as a folder tree, a diagram or a command against your own accounts, is marked as an illustration. Proving the blocks found and fixed wrong commands: `make run` of `streaming_capabilities` did not start, the deployment guide ran migrations with Squirrel and built with Gleam 1.6.2, and several READMEs named ports, scripts and outputs that did not exist.

The snippet check finds 583 Gleam code blocks and 7 diff blocks, proves 47 file blocks, 142 command blocks and 82 output blocks, and counts 39 illustrations, with no problems.

The snippet check moved to the [`dream_snippets`](https://github.com/TrustBound/dream_snippets) package.

The testing guide and the contributor testing guide show tests for `dream_test` 3.0.0. Dream's own test run now measures line coverage and fails when coverage of `src/` is below 100%.

The guides are rewritten as task guides. Each of the 14 guides in `docs/guides/` walks through one task, from building your first server to deploying with Docker, with numbered steps, the real answers of an example server, the failure cases (a 404, a 400 that lists every validation error, a broken upload, a port in use, a missing certificate), a test of your own code with its real report, and the common pitfalls. The quickstart, the `docs/learn/` lessons and the older topic pages are folded into them.

Each example in the README has a "read guide" badge next to its "tested snippet" badge. The guide badge links to the docs section that shows the same example. The guides in `docs/guides/` are also pages on HexDocs.

### Modules in Their Own Repositories

The modules moved out of this repository. Each one now has its own repository and its own releases: [dream_config](https://github.com/TrustBound/dream_config), [dream_ets](https://github.com/TrustBound/dream_ets), [dream_http_client](https://github.com/TrustBound/dream_http_client), [dream_json](https://github.com/TrustBound/dream_json), [dream_mock_server](https://github.com/TrustBound/dream_mock_server), [dream_opensearch](https://github.com/TrustBound/dream_opensearch) and [dream_postgres](https://github.com/TrustBound/dream_postgres).

## Bug Fixes

### Router Falls Back to the Next Route

When a route fit the start of a path but failed deeper down, the router returned 404. It now tries the next route. With `/users/:id/posts` and `/users/**rest`, `GET /users/1/comments` now finds `/users/**rest`.

### `server.stop` Stops the Server From Any Process

`server.stop` did nothing unless the process that started the server called it. It now stops the server from any process, and returns after the server is down.

### Values That Contain `=`

A form field, query parameter or cookie value that contains `=` (`token=a=b`) was dropped or came back empty. The value is now kept (`a=b`).


### Stray 500 After a Fast Streamed Response

Over HTTP/1.1, a streamed response that finished very quickly could be followed by a stray `500 Internal Server Error`. A keep-alive client could read that 500 as the answer to its next request. The first chunk is now sent only after the server has handed the socket to the stream.

### Connection Stays Open After a Streamed Response

Over HTTP/1.1, the server closed the connection after each streamed response and each event stream, and did not send `connection: close`. A client that kept the connection for its next request got no answer. The connection now stays open for the next request. The server sends an event stream with chunked transfer encoding, so the client can see where the event stream ends.

### Server Closes the Connection When the Client Asks

Over HTTP/1.1, a request with a `connection: close` header got a `connection: keep-alive` response, and the server held the connection open until its 10 second idle timer ended. The server now sends `connection: close` in the response and closes the connection after it, as RFC 9112 section 9.6 says.

### Response Lost to a Connection Reset

Over HTTP/1.1, a response sent just before the connection closed could be lost to a connection reset. The server now reads the remaining request data before it closes.

### Cookie `Expires` Is an HTTP Date

A cookie with `expires: Some(1700000000)` was sent as `Expires=1700000000`, which browsers ignore. It is now sent as an HTTP date in UTC, `Expires=Tue, 14 Nov 2023 22:13:20 GMT`, as RFC 6265 requires.

### Real IPv6 Client Addresses

`remote_address` was `::1` for every IPv6 client. It is now the real address in the RFC 5952 form, for example `2601:282:a00:b38::421d`.

### Broken Streamed Uploads Give the Controller an Error

On a `stream_route`, when the client sent part of the body and the connection broke, the stream ended as if the body was complete, so a controller could store a truncated upload. The stream now gives one `Error(MalformedBody)` item at the failed read, and then ends. Nothing is thrown and nothing is logged: the controller gets the `Error` item and owns the answer, for example to delete the partial file and answer 400. Because each item is a `Result`, a controller that uses an item as bytes does not compile until it handles the `Error`.

### Every Method Keeps Its Name

The server adapter turned CONNECT, TRACE and every method without its own constructor into `Get`, so `PURGE /` and `TRACE /` ran the `GET /` controller and got `200`. `Method` now has `Connect`, `Trace` and `Other(String)`, and no method becomes another one. `PURGE /` and `TRACE /` now get `404 Route not found` when no route has that method, as `DELETE /` did. A route with `method: Other("PURGE")` gets `PURGE` requests. Method names are case-sensitive (RFC 9110, section 9.1): `Other` keeps the name exactly as the client sent it, so a lower-case `purge` request does not match an `Other("PURGE")` route.

### Binary Static Files

`static.serve` answered 404 for each file that is not valid UTF-8, such as a PNG. It now sends the exact bytes of the file with its content type and length.

### Escaped Directory Listings

The `static` directory listing wrote file names and the request path into the HTML as markup. A file named `<img src=x onerror=...>.txt` became an element. Names are now HTML-escaped, and each link is percent-encoded.

### A Body Over the Size Limit Gets 413

A buffered body over `max_body_size` got `400 Bad Request` with an empty body, the same answer as a body that could not be read. It now gets `413 Content Too Large` (RFC 9110, section 15.5.14) with the plain-text body `Request body too large`. A request whose `content-length` is over the limit gets the 413 before the server reads the body. A chunked HTTP/1.1 body had no limit at all: the server read it to its end and gave it to the controller. The adapter now compares its size with the limit after the read, and answers 413. A body that stops early or has malformed chunks still gets `400`, now with the plain-text body `Request body could not be read`, like the `404 Route not found` answer.

### One Message for a Missing Path Parameter

`get_param` gave `Missing required path parameter: id` for a route with no `id` parameter, and `get_int_param` and `get_string_param` gave `Missing id parameter`. All three now give `Missing required path parameter: id`, and so do `require_int` and `require_string` in their `BadRequest` error. The functions of the same names in `dream/http/transaction` give the same message.

## Known Limits

- A single HTTP/2 connection uploads large bodies at about 89% of Bandit's speed. With 8 connections it is level.
- The server does not enforce the connection-level receive window. Unread request data on one connection is limited by 100 streams of 1 MiB each.
- Over HTTP/1.1, the server reads a chunked request body on a `route` to its end before Dream compares its size with `max_body_size`. Use a `stream_route` for uploads that can be very large.
- The server packages have three new settings (read timeout, send timeout, stream window size). Dream does not expose them yet.

## Testing

- Dream's own tests use `dream_test` 3.0.0: 1129 run, 0 failed, in about 18 seconds (Apple M1 Max, OTP 29, Gleam 1.19.2)
- `gleam test` measures the line coverage of `src/` and fails below 100%. It is 1087 of 1088 lines (99.9%)
- `dream_http_server` 1.3.1: 108 passed, on Gleam 1.14.0 with OTP 28. Each of its fixes has a test that fails without the fix
- `dream_socket_server`: 6 passed
- Integration tests: eleven examples run, ten of them twice, over HTTP/1.1 and over HTTP/2 with TLS, through `dream_http_client`. Each run also runs the commands of the example's README and compares their output. `make test-tasks` runs the `tasks` example: 26 scenarios over each protocol and 26 Cypress tests pass, in about 90 seconds. `make test-docker` builds and starts `examples/deployment` in about 24 seconds with the image layers in the Docker cache, and about 31 seconds when the dependency and build layers must run again (Apple M1 Max)

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

Most projects need only the request body change in step 3. Steps 1, 2, 4, 6, 7 and 8 apply only in the cases they name.

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
+dream_http_server = ">= 1.3.1 and < 2.0.0"
```

Replace `glisten` with `dream_socket_server = ">= 1.0.0 and < 2.0.0"` in the same way. Your `import mist` and `import glisten` lines stay as they are, because the module names are the same.

#### 2. Your project still uses `gleam_stdlib` 0.x

Dream 2.4.1 accepted `gleam_stdlib` from 0.44. Dream 3.0.0 requires `>= 1.0.0 and < 2.0.0`. The diff in step 1 shows this change in Dream's own `gleam.toml`.

#### 3. Request bodies

`RequestBody` replaces `body: String` and `stream`.

**What changed.** `Request.body` is now a `RequestBody`. The `Request.stream` field is gone.

#### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L260-L274"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(Result(BitArray, BodyReadError)))
}

/// Why a read of a streamed request body failed
///
/// The server reports one cause. `MalformedBody` means that the server could
/// not read the rest of the body: the connection closed before the end of
/// the body, no data came in the read timeout, or the chunked framing was
/// not valid. The server does not tell these cases apart.
pub type BodyReadError {
  MalformedBody
}
```

- On a route made with `route`, a body that is valid UTF-8 arrives as `Text`. An empty body is `Text("")`. Any other body arrives as `Bytes`, with the exact bytes.
- On a route made with `stream_route`, the body arrives as `Stream`. Each item is `Ok(chunk)`, or one `Error(MalformedBody)` when a read from the connection fails, for example when the client closed the connection before the end of the body. The stream ends after the `Error` item.

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

Use `validate_json(text, decoder)` when you already have a `String`. It now returns a list of errors: step 8 shows the change.

**A controller that needs the body as text.** Use `body_as_string(request)`. It returns `Error(Nil)` when the body is not valid UTF-8. Before 3.0.0 a controller could read `request.body` as a `String`. Now it reads the body with `body_as_string`:

#### Read a text body with `body_as_string` <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L46-L51"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_body(request: Request, _context, _services) -> Response {
  case body_as_string(request) {
    Ok(body) -> text_response(status.ok, body)
    Error(_) -> text_response(status.bad_request, "Body is not valid UTF-8")
  }
}
```

**A controller or middleware that reads the stream.** Match `Stream` on `request.body` in place of `Some` on `request.stream`. Each item is a `Result`, so fold with `yielder.try_fold` and answer the `Error` item. The streaming example made this change:

#### Read a stream from `request.body` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-96161bd1d29b10b5817d71e3db6be67d9a8494e6ea36bc113379cb3b2743ce32"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/examples/streaming_capabilities/src/controllers/stream_controller.gleam
+++ b/examples/streaming_capabilities/src/controllers/stream_controller.gleam
@@ -17,17 +18,14 @@ pub fn upload(
-  case request.stream {
-    Some(stream) -> {
-      // Consume the stream "saving" it
-      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)
-
-      text_response(
-        status.ok,
-        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
-      )
-    }
-    None -> text_response(status.bad_request, "Expected streaming request body")
+  case request.body {
+    // Consume the stream "saving" it. try_fold stops at an Error item.
+    Stream(stream) ->
+      stream
+      |> yielder.try_fold(0, accumulate_chunk_size)
+      |> respond_to_upload
+    Text(_) | Bytes(_) ->
+      text_response(status.bad_request, "Expected streaming request body")
   }
```

The fold function gets the `Result` and stops at an `Error`. The controller answers the `Error` with 400:

#### Fold over `Result` items <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-96161bd1d29b10b5817d71e3db6be67d9a8494e6ea36bc113379cb3b2743ce32"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/examples/streaming_capabilities/src/controllers/stream_controller.gleam
+++ b/examples/streaming_capabilities/src/controllers/stream_controller.gleam
@@ -77,17 +80,33 @@ pub fn proxy(
-fn accumulate_chunk_size(acc: Int, chunk: BitArray) -> Int {
-  let size = bit_array.byte_size(chunk)
+fn accumulate_chunk_size(
+  acc: Int,
+  item: Result(BitArray, BodyReadError),
+) -> Result(Int, BodyReadError) {
+  use chunk <- result.map(item)
   // Simulate saving to disk
-  acc + size
+  acc + bit_array.byte_size(chunk)
+}
+
+fn respond_to_upload(counted: Result(Int, BodyReadError)) -> Response {
+  case counted {
+    Ok(total_bytes) ->
+      text_response(
+        status.ok,
+        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
+      )
+    // The connection broke before the client sent the whole body
+    Error(_read_error) ->
+      text_response(status.bad_request, "The upload stopped before its end")
+  }
 }
```

A controller that saves the stream to a file deletes the partial file when it gets the `Error` item. The streaming guide shows the full example.

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
+  Request(..create_request(method, path), body: Stream(yielder.map(stream, Ok)))
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
- **Cookie `Expires`.** The `Set-Cookie` header writes `expires` as an HTTP date, `Expires=Tue, 14 Nov 2023 22:13:20 GMT`. In Dream 2 it was the number of seconds, which browsers ignore, so a cookie with only `expires` now expires when you asked.
- **IPv6 `remote_address`.** An IPv6 client gives its real address, such as `2601:282:a00:b38::421d`. In Dream 2 every IPv6 client was `::1`. Code that compares `remote_address` with `"::1"` now sees the real address.
- **Binary static files.** `static.serve` sends a file that is not UTF-8 as `Bytes` with status 200. In Dream 2 it answered 404. A UTF-8 file is still `Text`.
- **Broken streamed uploads.** On a `stream_route`, when a read of the body fails before its end, the stream gives one `Error(MalformedBody)` item and then ends. The controller decides the answer. In Dream 2 the stream ended as if the body was complete.
- **Methods.** A request with CONNECT, TRACE or another method without its own constructor gets the route of that method, or 404. In Dream 2 it ran the GET route of its path.
- **Body over the size limit.** A buffered body over `max_body_size` gets `413 Content Too Large` with the body `Request body too large`. In Dream 2 it got `400` with an empty body, and a chunked body over the limit reached the controller. A body that cannot be read still gets `400`, now with the body `Request body could not be read`. A client that checks for `400` on a body that is too big must check for `413`.
- **Missing path parameter message.** `get_int_param`, `get_string_param`, `require_int` and `require_string` give `Missing required path parameter: id` for a missing parameter, the message of `get_param`. In Dream 2 they gave `Missing id parameter`. Tests or clients that match the old text must match the new one.
- **Start errors.** `listen()` panics with `Failed to start server: ` and the start error for every start error, for example `Failed to start server: InitFailed("TLS file not found: cert.pem")`. In Dream 2 an `InitFailed` error panicked with its message only. Code or log checks that match the old panic text must match the new form.

#### 6. Your tests follow the Dream 2 testing guide

The testing guide now shows tests for `dream_test` 3.0.0. Dream 3.0.0 does not need a change to your tests, and they can stay on `dream_test` 1.x. To use the code of the new guide, set `dream_test = ">= 3.0.0 and < 4.0.0"` in `[dev-dependencies]` and run `gleam deps update dream_test`. Then change your tests as the [dream_test 2.0.0 release notes](https://github.com/TrustBound/dream_test/blob/main/releases/release-2.0.0.md) and the [dream_test upgrade guide](https://github.com/TrustBound/dream_test/blob/main/docs/guides/upgrading-to-3.md) show.

#### 7. Your code has a `case` over every `Method` value

**What changed.** `Method` has three more variants: `Connect`, `Trace` and `Other(String)`. A `case` that names every `Method` value does not compile until it has a branch for each one. Dream's own `method_to_string` made this change:

#### Name the new methods <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-d379a6a5ba4353e9c995a5a5de14ccc4e089b5d9f207accfb3dfa32aba8b9445"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/src/dream/http/request.gleam
+++ b/src/dream/http/request.gleam
@@ -216,12 +359,35 @@ pub fn method_to_string(method: Method) -> String {
     Patch -> "PATCH"
     Options -> "OPTIONS"
     Head -> "HEAD"
+    Connect -> "CONNECT"
+    Trace -> "TRACE"
+    Other(name) -> name
   }
 }
```

`Other` holds the name exactly as the client sent it. `parse_method` gives `Some(Connect)` and `Some(Trace)` for those names in any case, and `Some(Other(name))` for another valid method token, such as `"PURGE"`. It gives `None` only for text that is not a method token, such as `"GET /"`. In Dream 2 it gave `None` for every name except the seven standard ones.

#### 8. Your code calls `validate_json`

**What changed.** `validate_json` returns `Result(a, List(ValidationError))`. A body with two wrong fields gives two errors, in the order of the decoder. A JSON syntax error gives a list with one error. In Dream 2 it gave only the first error. `require_json` joins the messages with `"; "` in its `BadRequest`. The module example of `dream/http/validation` made this change:

#### Answer with every validation error <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-d14b0ecd284c6857c738de35bd2a16215d846d7c64a854ea717d2481e7de9232"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/src/dream/http/validation.gleam
+++ b/src/dream/http/validation.gleam
@@ -6,44 +6,96 @@
 ////   case validation_result {
-////     Ok(user) -> create_user(services.db, user)
-////     Error(err) -> create_validation_error_response(err)
+////     Ok(user) -> response.json_response(status.created, user_to_json(user))
+////     Error(validation_errors) ->
+////       create_validation_error_response(validation_errors)
 ////   }
 //// }
-//// 
-//// fn create_validation_error_response(err: ValidationError) -> Response {
-////   response.json_response(status.bad_request, error_json(err.message))
+////
+//// // One message for each field that failed
+//// fn create_validation_error_response(
+////   validation_errors: List(ValidationError),
+//// ) -> Response {
+////   let messages = list.map(validation_errors, error_message)
+////   response.json_response(
+////     status.bad_request,
+////     json.to_string(
+////       json.object([#("errors", json.array(messages, json.string))]),
+////     ),
+////   )
+//// }
+////
+//// fn error_message(validation_error: ValidationError) -> String {
+////   validation_error.message
+//// }
```

## Acknowledgements

To Alex Manning and the contributors to mist and glisten. Problems with the HTTP server in this release belong to us: report them at [TrustBound/mist](https://github.com/TrustBound/mist/issues) or [TrustBound/dream](https://github.com/TrustBound/dream/issues), not to the mist or glisten maintainers.

## Documentation

- [dream](https://hexdocs.pm/dream) - v3.0.0
- [dream_http_server](https://hexdocs.pm/dream_http_server) - v1.3.1
- [dream_socket_server](https://hexdocs.pm/dream_socket_server) - v1.0.0
- [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/main/docs/contributing/http-server-packages.md)
- [Guides](https://github.com/TrustBound/dream/blob/main/docs/guides/index.md) - Build your first Dream server, then one guide for each task
- [HTTP/2 guide](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md)
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/streaming-api.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
