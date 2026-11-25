<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Ricky Moony and Lucy, a moon shaped mascot for Dream with the star shaped mascot for Gleam, each with cute cartoon eyes and a smile" width="200">

<b>Clean, composable web development for Gleam. No magic.</b>

</div>

<br />

<div align="center">
  <a href="https://hex.pm/packages/dream"><img src="https://img.shields.io/hexpm/v/dream" alt="Hex Package"></a>
  <a href="https://github.com/TrustBound/dream/releases"><img src="https://img.shields.io/github/v/release/TrustBound/dream?label=Release" alt="Latest Release"></a>
  <a href="https://hexdocs.pm/dream/3.0.0/"><img src="https://img.shields.io/badge/hex-docs-lightgreen.svg" alt="HexDocs"></a>
  <a href="https://github.com/TrustBound/dream/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/TrustBound/dream/badges/coverage.json" alt="Coverage"></a>
  <a href="https://github.com/TrustBound/dream/blob/3.0.0/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://gleam.run"><img src="https://img.shields.io/badge/gleam-%E2%9C%A8-ffaff3" alt="Gleam"></a>
</div>

<br />

## What is Dream?

Dream is a web toolkit for building servers. It's not a framework—you control everything. No hidden configuration, no magic middleware appearing from nowhere. Your `main()` function shows exactly what's happening.

**Built for Gleam** (a type-safe functional language) and **runs on the BEAM** (the same runtime that powers WhatsApp, Discord, and millions of concurrent connections).

## A Quick Example

Here is the smallest useful Dream server. It responds with `"Hello, world!"`.

### Hello, world <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_hello_server.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream/blob/3.0.0/docs/guides/getting-started.md#hello-world-"><img align="right" alt="Guide: Build your first Dream server" title="Guide: Build your first Dream server" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```gleam
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

**Run this:** `gleam run` → Visit `http://localhost:3000/` → See `Hello, world!`

In words:

- `index` is a **controller**: it takes a request/context/services and
  returns a response.
- `router()` and `route(...)` define which controller handles which
  requests.
- `server.new() |> ... |> server.listen(3000)` configures and starts a
  Mist-based HTTP server using a builder pattern.

Types are omitted here for brevity – Gleam can infer them.
[Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html)
walks through a fully-typed version line by line.

Dream also includes **named HTTP status constants** (like `ok`, `not_found`, and `teapot`) so you can avoid magic numbers in responses.

## What Dream Can Do

Dream is more than "Hello, world". Here are a few small examples of
what it helps you build.

### JSON APIs <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_json_api.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream/blob/3.0.0/docs/guides/api-patterns.md#return-a-user-as-json-"><img align="right" alt="Guide: Grow a JSON API" title="Guide: Grow a JSON API" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```gleam
import dream/http.{json_response, not_found, ok}
import gleam/json
import gleam/list

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(db: List(User))
}

pub fn get_user(_request, _context, services: Services) {
  case find_user(services.db, id: 1) {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(Nil) -> json_response(not_found, "{}")
  }
}

fn find_user(db: List(User), id id: Int) -> Result(User, Nil) {
  list.find(db, fn(user) { user.id == id })
}

fn user_to_json(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string
}
```

- Use `Services` to carry dependencies like a database pool.
- Use view functions (like `user_to_json`) to keep formatting separate
  from data access.

### Streaming responses <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_streaming.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream/blob/3.0.0/docs/guides/streaming.md#stream-log-lines-"><img align="right" alt="Guide: Stream responses and uploads" title="Guide: Stream responses and uploads" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```gleam
import dream/http.{ok, stream_response}
import gleam/bit_array
import gleam/yielder

pub type Services {
  Services(log_store: List(String))
}

pub fn download_log(_request, _context, services: Services) {
  let stream = make_log_stream(services.log_store)
  stream_response(ok, stream, "text/plain")
}

fn make_log_stream(lines: List(String)) -> yielder.Yielder(BitArray) {
  yielder.from_list(lines)
  |> yielder.map(fn(line) { bit_array.from_string(line <> "\n") })
}
```

- Send large responses as a stream of chunks.
- Use the BEAM's strengths for long-running, memory-efficient
  operations.

### WebSockets <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_websocket_chat.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream/blob/3.0.0/docs/guides/websockets.md#echo-each-message-with-the-user-name-"><img align="right" alt="Guide: Build a chat with WebSockets" title="Guide: Build a chat with WebSockets" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, get_query_param}
import dream/servers/mist/websocket
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub type Dependencies {
  Dependencies(user_name: String)
}

pub fn chat(request, _context, _services) {
  websocket.upgrade_websocket(
    request,
    dependencies: make_dependencies(request),
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn make_dependencies(request: Request) -> Dependencies {
  let user_name =
    get_query_param(request.query, "user")
    |> option.unwrap("guest")
  Dependencies(user_name:)
}

fn handle_init(
  _connection: websocket.Connection,
  _deps: Dependencies,
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: websocket.Message(Nil),
  connection: websocket.Connection,
  deps: Dependencies,
) -> websocket.Action(Nil, Nil) {
  case message {
    websocket.TextMessage(text) -> {
      let _ = websocket.send_text(connection, deps.user_name <> ": " <> text)
      websocket.continue_connection(state)
    }
    _ -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: Nil, _deps: Dependencies) -> Nil {
  Nil
}
```

- Upgrade an HTTP request to a typed WebSocket connection.
- Use explicit `Dependencies` instead of closures, so it’s clear what
  each handler needs.

See the [guides](https://github.com/TrustBound/dream/blob/3.0.0/docs/index.md)
for complete examples of JSON APIs, streaming, and WebSockets.

## Why This Approach?

**Everything is explicit.** You can see exactly where your database connection comes from. No globals, no hidden state, no framework magic.

**Controller actions are just functions.** No base classes, no decorators, no inheritance. Extract parameters, do work, return a response.

**Type-safe controllers.** The compiler verifies your context and services types match across all controllers. However, path parameters are validated at runtime, not compile-time—this trade-off favors API ergonomics over compile-time safety. See [Discussion #15](https://github.com/TrustBound/dream/discussions/15) for details.

**Composable, not opinionated.** Use Dream's patterns, or build your own. It's just functions and data.

## Guides

Upgrading from Dream 2? [Upgrade from Dream 2 to 3](https://hexdocs.pm/dream/3.0.0/guides/upgrading-to-3.html) gives every change, with the Dream 2 code next to the Dream 3 code.

- [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) - From an empty folder to a tested route.
- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html) - How the runtime runs your app, and the common traps, each with its fix.
- [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) - Path parameters, custom methods, context and middleware.
- [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) - Query strings, JSON that reports every error, and forms.
- [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) - Redirects, downloads, cookies and static files.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) - PostgreSQL with `dream_model`, migrations and operations.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html) - Pagination, errors, versioning, filtering and CORS.
- [Load configuration and fail early](https://hexdocs.pm/dream/3.0.0/guides/configuration.html) - Typed settings read one time at startup with `dream_config`, a clear error, and secrets kept out of logs.
- [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html) - `dream_http_client` in an app: timeouts, typed errors, 502 and 504 answers, JSON and a streamed reply.
- [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html) - Shared state in ETS with `dream_ets`: a cache with expiry, and a per-client limit that answers 429.
- [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html) - Answer 202 at once, and run the job in a supervised worker with a bounded queue, timeouts and a clean stop.
- [Add search to a Dream app](https://hexdocs.pm/dream/3.0.0/guides/search.html) - An OpenSearch index beside the system of record, and the answers when search is down.
- [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html) - Matcha templates, and one route in many formats.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) - Streamed downloads and uploads, and a broken upload.
- [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html) - Typed SSE actors and a broadcaster.
- [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) - Typed WebSocket actors and a chat room.
- [Serve HTTPS and HTTP/2](https://hexdocs.pm/dream/3.0.0/guides/http2.html) - TLS, ALPN and prior knowledge.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) - Dream Test for controllers, middleware, routes and servers.
- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) - Recorded HTTP calls, with the base request in services.
- [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html) - Recorded PostgreSQL queries, with the connection in services.
- [Test a Dream app against a fake API](https://hexdocs.pm/dream/3.0.0/guides/testing-with-a-fake-api.html) - A fake service from `dream_mock_server`: error statuses, timeouts, streams and a contract test.
- [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html) - The image, Compose, migrations and health checks.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html) - Start errors, body limits and stopping.

## Learn More

- 🤖 [Instructions for coding agents](https://github.com/TrustBound/dream/blob/3.0.0/docs/agents/AGENTS.md) - A template `AGENTS.md` that keeps the coding agents of your Dream app on Dream's patterns. Copy it to the root of your project and fill in the marked sections.
- 📚 [Complete Documentation](https://github.com/TrustBound/dream/blob/3.0.0/docs/index.md) - Guides, tutorials, and concepts
- 📖 [API Reference](https://hexdocs.pm/dream/3.0.0/) - Complete API documentation on HexDocs
- 🚀 [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) - Get a server running
- 💡 [Examples](https://github.com/TrustBound/dream/tree/3.0.0/examples) - Working code you can run

## Why Gleam? Why the BEAM?

**Gleam** is a type-safe functional language. You get compile-time error checking, no nulls, and a modern syntax. Learn it in a weekend.

**The BEAM** is the runtime that powers Erlang and Elixir. It was built for reliability and concurrency:

- **Millions of concurrent connections** per server (WhatsApp: 2.8M per server)
- **Fault tolerance** - processes crash in isolation, the rest keep running
- **Hot code reloading** - update code without dropping connections

**Real-world results:**

- Discord: 12M+ concurrent users, 26M WebSocket events/sec with ~5 engineers
- Remote: Grew from zero to unicorn (~$3B) in ~2 years with Elixir
- BBC: Elixir serving almost all BBC web and app traffic

Gleam gives you the BEAM's superpowers with type safety. You write functions. The BEAM handles concurrency, fault tolerance, and scaling.

[Read more about why Gleam and the BEAM →](https://github.com/TrustBound/dream/blob/3.0.0/docs/index.md)

## Philosophy

Dream is **explicitly not a framework**. We provide:

✅ Clean interfaces and types  
✅ Common patterns (controllers, models, middleware)  
✅ Useful utilities (validation, response builders)  
✅ Working examples

You provide:

🎯 Your application structure  
🎯 Your router configuration  
🎯 Your controllers and models  
🎯 Your business logic

**No magic. No hidden behavior. Everything explicit.**

## Contributing

See the [Contributing Guide](https://github.com/TrustBound/dream/blob/3.0.0/docs/index.md#contributing) for guidelines.

---

## License

MIT — see [LICENSE.md](LICENSE.md)

## Third-party code

Dream's server adapter is built on [mist](https://github.com/rawhat/mist) and
[glisten](https://github.com/rawhat/glisten), by Alex Manning and
contributors (Apache-2.0).

Right now it uses our own builds of both,
[`dream_http_server`](https://hex.pm/packages/dream_http_server) and
[`dream_socket_server`](https://hex.pm/packages/dream_socket_server), which
add the HTTP/2 fixes we needed. They use the same module names as mist and
glisten, so don't add `mist` or `glisten` to a project that uses Dream.

[More about the server packages →](https://github.com/TrustBound/dream/blob/3.0.0/docs/contributing/http-server-packages.md)

---

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a> ❤️</sub>
</div>
