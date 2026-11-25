# Dream 3.0.0 Release Notes

**Release Date:** not released yet (draft)

This release makes HTTP/2 work end to end in Dream's Mist server adapter, for browsers over HTTPS and for clients over plain HTTP. To ship the fixes, the adapter now uses two packages that we publish, `dream_http_server` and `dream_socket_server`.

It is a major version because a request body now has one type, `RequestBody`, for text, bytes and streams, a streamed body gives a failed read as a value, `Method` holds every HTTP method, `validate_json` returns every decode error, a known path with another method gets `405`, and the WebSocket message `ConnectionClosed` is gone. Read the Migration Guide before you upgrade. Every code example in the docs, the READMEs and the doc comments is now a tested snippet.

## Key Highlights

- **HTTP/2 works for real workloads**: Requests with bodies, large uploads, large responses, file responses, server-sent events and streamed responses all work over HTTP/2
- **HTTPS with `server.tls()`**: Browsers and other clients agree on HTTP/2 during the TLS handshake. Over plain HTTP, clients get HTTP/2 with prior knowledge
- **Faster and lighter under load**: HTTP/2 throughput is level with Bandit or ahead of it on the same machine, and memory under load is much lower, most of all on macOS
- **New server packages**: Dream depends on `dream_http_server` and, through it, `dream_socket_server`. Read "Upgrading" first if your project lists `mist` or `glisten` itself
- **`gleam_stdlib` 1.x**: Dream now requires `gleam_stdlib` 1.0.0 or later
- **One request body type (breaking)**: `Request.body` is a `RequestBody`: `Text`, `Bytes` or `Stream`. Binary uploads no longer arrive as `""`. New `require_json` reads and decodes a JSON body in one step
- **A failed read is a value (breaking)**: each item of a `Stream` body is a `Result`. When the connection breaks, the controller gets an `Error` item and decides the answer
- **Every method keeps its name (breaking)**: `Method` has `Connect`, `Trace` and `Other(String)`. `PURGE /` no longer runs the `GET /` controller
- **405 for a known path with another method (breaking)**: `DELETE /` on a router with only `GET /` gets `405 Method Not Allowed` with `Allow: GET`. A path that no route matches still gets `404`
- **A body the server did not read is never read as a request**: after an answer to a request whose body it did not read, the server closes the connection, so a body that holds a second request is never answered
- **Every validation error (breaking)**: `validate_json` returns a list with one `ValidationError` for each field that failed
- **Requests finish when the app stops**: on `SIGTERM`, the server refuses new connections and lets running requests finish, for at most 30 seconds. `server.stop_gracefully(handle, within: 30_000)` does the same from code
- **Route groups with `router.scope`**: `scope(path: "/members", with: require_member, routes: member_routes())` puts a group of routes under a prefix and an entry function. The entry function can change the context type, so a controller in the group can get, for example, a context with the signed-in user
- **`Conflict` answers 409 (breaking)**: `Error` has `Conflict(String)` for a request that clashes with the current state, such as a taken email. A `case` over every `Error` needs a new branch
- **`listen` returns a `Result` (breaking)**: a server that cannot start returns `Error`, and Dream's `src` has no `panic`. `dream.get_server` takes `RisksUnderstood`, and `response.convert` takes every body type
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

Every other client gets HTTP/1.1. Dream does not upgrade HTTP/1.1 connections with `Upgrade: h2c`: RFC 9113 deprecated it, and it can let a client get past a proxy's rules. The [HTTP/2 guide](https://hexdocs.pm/dream/3.0.0/guides/http2.html) covers HTTPS, proxies and how to check the protocol.

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

### Requests Finish When the App Stops

In Dream 2, a deploy cut off every running request: on `SIGTERM`, the Erlang VM closed the connections at once. Now a server that `listen` started drains first. It closes the listening socket and the idle keep-alive connections at once. Each running request gets its full response, with `connection: close`. Then the VM stops. The server waits at most 30 seconds, the time that Kubernetes waits after `SIGTERM`. Set a time below the grace period of your platform with `server.shutdown_timeout`. Docker waits 10 seconds.

In code, `server.stop_gracefully(handle, within: 30_000)` drains the same way and returns when the server is down. `server.stop(handle)` still stops at once. See [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html#stopping-in-production).

### Dream's HTTP Server Packages

Dream's router, controllers and HTTP types do not depend on any web server. The server is an adapter, and the one Dream ships today is built on [mist](https://github.com/rawhat/mist), the HTTP server, and mist is built on [glisten](https://github.com/rawhat/glisten), the socket server. Both are by Alex Manning (rawhat) and their contributors. We chose mist for the adapter because we would rather support the libraries the Gleam community already shares than go our own way.

The adapter needed many HTTP/2 fixes in mist and one fix in glisten. We are giving all of them back upstream, which takes time for this many changes. Until upstream releases contain them, the adapter uses two forks that we publish:

| Package | What it is |
|---------|------------|
| [`dream_http_server`](https://hex.pm/packages/dream_http_server) | mist 6.0.3 plus fixes, most of them for HTTP/2, and HTTP/2 over TLS |
| [`dream_socket_server`](https://hex.pm/packages/dream_socket_server) | glisten 9.0.1 plus a socket buffer fix |

Both keep the upstream module names (`mist`, `glisten`). They are named for what they do, so they do not appear when people search Hex for mist or glisten. They are temporary: when upstream releases contain the fixes, Dream goes back to `mist` and `glisten`. See [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/3.0.0/docs/contributing/http-server-packages.md) for the reasons and for how to go back.

### Streaming Uses Chunked Responses

Dream's streaming adapter now uses the server's actor-based chunked responses. Dream's public streaming API (`stream_response`, `sse_response`, `ResponseBody.Stream`) is unchanged.

### One Request Body Type

`Request.body` is now a `RequestBody`, and the `Request.stream` field is gone.

#### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L262-L276"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Route Groups With `router.scope`

`router.scope(path:, with:, routes:)` adds every route of a second router under a path prefix. `with` has the shape of a middleware, but its `next` can take another context type. It runs before the middleware of each route. Use `path: ""` for a group with no prefix. Scoped routes give the same `404` and `405` answers as other routes and keep their streaming flag. Step 7 of [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) shows a member area whose controllers get the signed-in user.

### A `Conflict` Error

`Error` has `Conflict(String)`, which answers `409 Conflict`. Use it for a request that clashes with the current state, such as an email that is already taken or an edit against an old version. Before, apps answered these with `422` or `500`.

### No `panic` in Dream

`server.listen` returns `Result(Nil, actor.StartError)`. It blocks while the server runs, and returns `Error` when the server cannot start. End `main` with `let assert Ok(Nil) = ... |> server.listen(3000)`, so a failed start stops the program with a non-zero exit code. `dream.get_server` takes the value `RisksUnderstood` in place of a `Bool`, and `response.convert` takes every body type, so neither can fail.

### Tested Docs

Every Gleam code block in the guides, the READMEs, the doc comments and SECURITY.md comes from a snippet file that the tests compile and run. Each block has a "tested snippet" badge that links to its snippet at this release's tag. Converting them found and fixed wrong examples across the docs. Every public function has a tested example in its doc comment, and every public type and constant has a doc comment.

`make check-snippets` keeps it that way. It checks that every Gleam code block has a heading with the badge and shows the same code as its snippet file. It runs in the pre-commit hook, in CI and before every publish, so a wrong example cannot ship.

Every other code block is proven too. A shell command is a line of a script that CI or a test runs, such as `scripts/check.sh` or the `test/integration/start.sh` and `readme.sh` of an example. Shown output is a file that a test compares with the real output: the integration run of each example runs the requests of its README against the running server and compares what they print. A Dockerfile, a Compose file, a Makefile, a migration, a query, a template or a script is a copy of the real file that a test or CI uses. The new `examples/deployment` has the Dockerfile and the Compose file of the deployment guide, and `make test-docker` builds and starts them. A block that nothing can run, such as a folder tree, a diagram or a command against your own accounts, is marked as an illustration. Proving the blocks found and fixed wrong commands: `make run` of `streaming_capabilities` did not start, the deployment guide ran migrations with Squirrel and built with Gleam 1.6.2, and several READMEs named ports, scripts and outputs that did not exist.

The snippet check finds 770 code blocks and 1 diff block in 100 files, proves 75 file blocks, 150 command blocks and 130 output blocks, and counts 40 illustrations, with no problems.

The snippet check moved to the [`dream_snippets`](https://github.com/TrustBound/dream_snippets) package.

The testing guide and the contributor testing guide show tests for `dream_test` 3.0.0. Dream's own test run now measures line coverage and fails when coverage of `src/` is below 100%.

The guides are rewritten as task guides. Each of the 24 guides in `docs/guides/` walks through one task, from building your first server to deploying with Docker, adding search, running background work and testing against recorded traffic, with numbered steps, the real answers of an example server, the failure cases (a 404, a 400 that lists every validation error, a broken upload, a port in use, a missing certificate), a test of your own code with its real report, and the common pitfalls. The quickstart, the `docs/learn/` lessons and the older topic pages are folded into them.

Each example in the README has a "read guide" badge next to its "tested snippet" badge. The guide badge links to the docs section that shows the same example. The guides in `docs/guides/` are also pages on HexDocs, and each one starts with a breadcrumb back to the README and the guide list. `AGENTS.md` keeps coding agents on Dream's patterns, and `docs/agents/AGENTS.md` is a template for the agents of your own Dream app.

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

The server adapter turned CONNECT, TRACE and every method without its own constructor into `Get`, so `PURGE /` and `TRACE /` ran the `GET /` controller and got `200`. `Method` now has `Connect`, `Trace` and `Other(String)`, and no method becomes another one. `PURGE /` and `TRACE /` now get `405 Method Not Allowed` with `Allow: GET` when `/` has only a `GET` route, as `DELETE /` does. A route with `method: Other("PURGE")` gets `PURGE` requests. Method names are case-sensitive (RFC 9110, section 9.1): `Other` keeps the name exactly as the client sent it, so a lower-case `purge` request does not match an `Other("PURGE")` route.

### Binary Static Files

`static.serve` answered 404 for each file that is not valid UTF-8, such as a PNG. It now sends the exact bytes of the file with its content type and length.

### Escaped Directory Listings

The `static` directory listing wrote file names and the request path into the HTML as markup. A file named `<img src=x onerror=...>.txt` became an element. Names are now HTML-escaped, and each link is percent-encoded.

### A Body Over the Size Limit Gets 413

A buffered body over `max_body_size` got `400 Bad Request` with an empty body, the same answer as a body that could not be read. It now gets `413 Content Too Large` (RFC 9110, section 15.5.14) with the plain-text body `Request body too large`. A request whose `content-length` is over the limit gets the 413 before the server reads the body. A chunked HTTP/1.1 body had no limit at all: the server read it to its end and gave it to the controller. The server now stops reading it when it grows over the limit, and Dream answers 413. A body that stops early or has malformed chunks still gets `400`, now with the plain-text body `Request body could not be read`, like the `404 Route not found` answer.

### A Known Path With Another Method Gets 405

A request whose path matches a route, but with a method that no route of that path has, got `404 Route not found`, the same answer as a path with no route. It now gets `405 Method Not Allowed` with an `Allow` header that lists the methods of the routes that match the path, in alphabetical order, and the plain-text body `Method not allowed` (RFC 9110, sections 15.5.6 and 10.2.1). `DELETE /` on a router with `GET /` and `POST /` gets `Allow: GET, POST`. A path that no route matches still gets `404`. `HEAD` and `OPTIONS` are methods like any other: a path with only a `GET` route gets `405` for them, as it got `404` before. The server and `dream.route_request` give the same answer, and the new `router.allowed_methods` gives the list. A route lookup that finds a route costs the same as before: the methods are looked up only when no route matched.

### A Body the Server Did Not Read Is Never Read as a Request

Over HTTP/1.1, when Dream answered without reading the request body (a `404`, a `413` for a body over the limit, or a `stream_route` controller that did not read the stream), the server kept the connection and read the body as the next request. A client could hide a second request in the body, and the server answered it (request smuggling). `dream_http_server` 2.0.0 closes the connection after such an answer and sends `connection: close`. A request with no body, and a body that Dream read to its end, keep the connection as before.

### One Message for a Missing Path Parameter

`get_param` gave `Missing required path parameter: id` for a route with no `id` parameter, and `get_int_param` and `get_string_param` gave `Missing id parameter`. All three now give `Missing required path parameter: id`, and so do `require_int` and `require_string` in their `BadRequest` error. The functions of the same names in `dream/http/transaction` give the same message.

## Known Limits

- A single HTTP/2 connection uploads large bodies at about 89% of Bandit's speed. With 8 connections it is level.
- The server does not enforce the connection-level receive window. Unread request data on one connection is limited by 100 streams of 1 MiB each.
- The server packages have three new settings (read timeout, send timeout, stream window size). Dream does not expose them yet.

## Testing

- Dream's own tests use `dream_test` 3.0.0: 1162 run, 0 failed, in about 22 seconds (Apple M1 Max, OTP 29, Gleam 1.19.2, with other tests running on the machine)
- `gleam test` measures the line coverage of `src/` and fails below 100%. It is 1138 of 1138 lines (100%)
- `dream_http_server` 2.1.0: 134 run, 0 failed, on Gleam 1.19.2 with OTP 29. Each of its fixes has a test that fails without the fix
- `dream_socket_server` 1.0.1: 7 run, 0 failed
- Through a real Dream server, a request whose body holds a second request gets exactly one answer, and then the server closes the connection: after a `404`, a `405`, a `413` for a `content-length` over the limit, a `413` for a chunked body over the limit, and a `stream_route` controller that does not read the body. A body that the controller reads, and then a real second request, get two answers on one connection
- Integration tests: eleven examples run, ten of them twice, over HTTP/1.1 and over HTTP/2 with TLS, through `dream_http_client`. Each run also runs the commands of the example's README and compares their output. `make test-tasks` runs the `tasks` example: 26 scenarios over each protocol and 26 Cypress tests pass, in about 90 seconds. `make test-docker` builds the image of `examples/deployment` with no network, so it asks Hex for nothing, starts it, and checks that the app stops on `SIGTERM` with exit status 0 (about 0.2 seconds). It takes about 29 seconds (Apple M1 Max)

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

[Upgrade from Dream 2 to 3](https://hexdocs.pm/dream/3.0.0/guides/upgrading-to-3.html) gives each step, with the Dream 2 code next to the Dream 3 code. Most projects need only the request body change. The other steps apply only when your code uses what they name:

1. Update the `dream` requirement, and `gleam_stdlib` to 1.x. If your app used the Dream modules by path (`deps/dream/modules/*`), move them to Hex now (step 14).
2. Replace `mist` with `dream_http_server`, and `glisten` with `dream_socket_server`.
3. Read request bodies as a `RequestBody`: `Text`, `Bytes` or `Stream`. Use `require_json` or `body_as_string`, and answer the `Error` item of a stream.
4. Call `context()` and `services()` before `router()`, and add the fourth type parameter where you write the `Dream` type.
5. Add branches for `Connect`, `Trace` and `Other(String)` to a `case` over every `Method`.
6. Answer the list of errors that `validate_json` returns.
7. Move the work of a `ConnectionClosed` branch to `on_close`.
8. Move from `pog` and `squirrel` to `dream_postgres_client` and `dream_sql_generator`, to follow the guides.
9. Handle the `Result` of `listen`. A `main` with no return type still compiles when it ends with `listen`, and then a failed start ends the program with exit code 0. Search your code for `listen(`.
10. Update calls of `get_server` (it takes `RisksUnderstood`) and `response.convert`.
11. Add a `Conflict` branch to a `case` over every `Error`.
12. Check the behavior changes that tests and clients can see, such as `405` for a wrong method and `413` for a body over the limit.
13. Optionally, update your tests to `dream_test` 3.
14. Replace path dependencies on the Dream modules with the Hex packages.
15. Upgrade the Dream modules to their new major versions. The guide has a table with the main changes of each module and a link to its release notes.

## Acknowledgements

To Alex Manning and the contributors to mist and glisten. Problems with the HTTP server in this release belong to us: report them at [TrustBound/mist](https://github.com/TrustBound/mist/issues) or [TrustBound/dream](https://github.com/TrustBound/dream/issues), not to the mist or glisten maintainers.

## Documentation

- [dream](https://hexdocs.pm/dream/3.0.0/) - v3.0.0
- [dream_http_server](https://hexdocs.pm/dream_http_server/2.1.0/) - v2.1.0
- [dream_socket_server](https://hexdocs.pm/dream_socket_server/1.0.1/) - v1.0.1
- [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/3.0.0/docs/contributing/http-server-packages.md)
- [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) - Build your first Dream server, then one guide for each task
- [Upgrade from Dream 2 to 3](https://hexdocs.pm/dream/3.0.0/guides/upgrading-to-3.html)
- [HTTP/2 guide](https://hexdocs.pm/dream/3.0.0/guides/http2.html)
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/streaming-api.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/3.0.0/docs)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/3.0.0/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/3.0.0/CHANGELOG.md)
