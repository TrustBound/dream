# Dream Documentation

**Clean, composable web development for Gleam.**

Dream is a web toolkit that gets out of your way. It provides type-safe routing, explicit dependency injection, and composable middleware. No magic. No global state. Just functions and data.

---

## Where to start

If you are new to Dream or Gleam, follow this path the first time through:

1. [Build your first Dream server](guides/getting-started.md) – from an empty folder to a tested route.
2. [The BEAM for Dream developers](guides/beam.md) – how the runtime runs your app, and the traps to avoid.
3. [Guides](guides/index.md) – one guide for each task: routing, request data, a database API, streaming, WebSockets, deployment and more.
4. [Examples](examples.md) – open a full app that matches what you are trying to build.
5. [Core Patterns](concepts/patterns.md) – skim the pattern catalog to see what Dream provides.

After that, dip into the sections below whenever you need more detail.

**Upgrading from Dream 2?** [Upgrade from Dream 2 to 3](guides/upgrading-to-3.md) gives every change, with the Dream 2 code next to the Dream 3 code.

## Explore the System

### 🛠️ [Guides](guides/index.md)
**Building something specific?** Each guide walks through one task with real code and the real answers of a running server.
- [Build your first Dream server](guides/getting-started.md)
- [The BEAM for Dream developers](guides/beam.md)
- [Route requests and add middleware](guides/routing.md)
- [Read request data safely](guides/request-data.md)
- [Send responses, cookies and files](guides/responses.md)
- [Build a database-backed JSON API](guides/database-api.md)
- [Grow a JSON API](guides/api-patterns.md)
- [Render HTML and other formats](guides/templates.md)
- [Stream responses and uploads](guides/streaming.md)
- [Push live updates with server-sent events](guides/sse.md)
- [Build a chat with WebSockets](guides/websockets.md)
- [Serve HTTPS and HTTP/2](guides/http2.md)
- [Test your controllers and your app](guides/testing.md)
- [Test a Dream app that calls other APIs](guides/testing-with-recorded-http.md)
- [Test a Dream app's database code with recorded queries](guides/testing-with-recorded-queries.md)
- [Deploy with Docker](guides/deployment.md)
- [Start, stop and troubleshoot the server](guides/operating.md)
- [Upgrade from Dream 2 to 3](guides/upgrading-to-3.md)
- [Instructions for coding agents](agents/AGENTS.md)

### 📖 [Concepts](concepts.md)
**Core concepts explained.** Understanding how Dream works.
- [How It Works](concepts/how-it-works.md) - Request flow from arrival to response
- [Project Structure](concepts/project-structure.md) - Organizing a real application
- [Core Patterns](concepts/patterns.md) - Catalog of Dream patterns: routing, context & services, middleware, MVC, operations, auth, multi-format responses, streaming, WebSockets, templates, testing
- [All Concepts](concepts.md) - Complete overview of controllers, routers, middleware, models, views

### 📚 [Reference](reference/)
**Need details?** Deep dives into the architecture and API.
- [Dream vs Mist](reference/dream-vs-mist.md) - What Dream adds to the HTTP server under it
- [Architecture](reference/architecture.md) - How it all fits together
- [Design Principles](reference/design-principles.md) - The "Why" behind Dream
- [Why the BEAM?](reference/why-beam.md) - Understanding the runtime
- [Streaming API](reference/streaming-api.md) - Every streaming type and function
- [Naming Conventions](reference/naming-conventions.md) - Code Style

### 📦 Ecosystem
Dream is the `dream` package: the router, the HTTP types, the response builders, validation and the server. The packages below work with Dream. Each one has its own repository, its own version and its own releases, separate from Dream. A new Dream release does not change them, and a new release of one of them does not change Dream. Each badge shows the current version on Hex.

**Data:**
- [`dream_postgres`](https://github.com/TrustBound/dream_postgres) [![Hex version of dream_postgres](https://img.shields.io/hexpm/v/dream_postgres?style=flat-square)](https://hex.pm/packages/dream_postgres) - PostgreSQL helpers for queries and results, and recorded queries for tests.
- [`dream_postgres_client`](https://github.com/TrustBound/pog/tree/dream-postgres-client) [![Hex version of dream_postgres_client](https://img.shields.io/hexpm/v/dream_postgres_client?style=flat-square)](https://hex.pm/packages/dream_postgres_client) - The PostgreSQL client that the guides use. A fork of `pog`.
- [`dream_postgres_driver`](https://github.com/TrustBound/pgo/tree/dream-postgres-driver) [![Hex version of dream_postgres_driver](https://img.shields.io/hexpm/v/dream_postgres_driver?style=flat-square)](https://hex.pm/packages/dream_postgres_driver) - The PostgreSQL driver under `dream_postgres_client`. A fork of `pgo`.
- [`dream_sql_generator`](https://github.com/TrustBound/squirrel/tree/dream-sql-generator) [![Hex version of dream_sql_generator](https://img.shields.io/hexpm/v/dream_sql_generator?style=flat-square)](https://hex.pm/packages/dream_sql_generator) - Makes type-safe Gleam functions from SQL files. A fork of `squirrel`.
- [`dream_opensearch`](https://github.com/TrustBound/dream_opensearch) [![Hex version of dream_opensearch](https://img.shields.io/hexpm/v/dream_opensearch?style=flat-square)](https://hex.pm/packages/dream_opensearch) - An OpenSearch client.
- [`dream_ets`](https://github.com/TrustBound/dream_ets) [![Hex version of dream_ets](https://img.shields.io/hexpm/v/dream_ets?style=flat-square)](https://hex.pm/packages/dream_ets) - ETS tables for in-memory state, such as caches and rate limits.

**Utilities:**
- [`dream_http_client`](https://github.com/TrustBound/dream_http_client) [![Hex version of dream_http_client](https://img.shields.io/hexpm/v/dream_http_client?style=flat-square)](https://hex.pm/packages/dream_http_client) - An HTTP client with streaming, and recorded responses for tests.
- [`dream_config`](https://github.com/TrustBound/dream_config) [![Hex version of dream_config](https://img.shields.io/hexpm/v/dream_config?style=flat-square)](https://hex.pm/packages/dream_config) - Configuration from environment variables and `.env` files.
- [`dream_json`](https://github.com/TrustBound/dream_json) [![Hex version of dream_json](https://img.shields.io/hexpm/v/dream_json?style=flat-square)](https://hex.pm/packages/dream_json) - JSON encoders for optional values and other common types.

**Testing and docs:**
- [`dream_test`](https://github.com/TrustBound/dream_test) [![Hex version of dream_test](https://img.shields.io/hexpm/v/dream_test?style=flat-square)](https://hex.pm/packages/dream_test) - A test framework for unit tests and Gherkin features. The testing guide uses it.
- [`dream_mock_server`](https://github.com/TrustBound/dream_mock_server) [![Hex version of dream_mock_server](https://img.shields.io/hexpm/v/dream_mock_server?style=flat-square)](https://hex.pm/packages/dream_mock_server) - A mock HTTP server for the tests of HTTP clients.
- [`dream_snippets`](https://github.com/TrustBound/dream_snippets) [![Hex version of dream_snippets](https://img.shields.io/hexpm/v/dream_snippets?style=flat-square)](https://hex.pm/packages/dream_snippets) - Checks that each code block of the docs is a tested file. Dream's docs use it.

**The HTTP server under Dream:**
- [`dream_http_server`](https://github.com/TrustBound/mist/tree/dream-http-server) [![Hex version of dream_http_server](https://img.shields.io/hexpm/v/dream_http_server?style=flat-square)](https://hex.pm/packages/dream_http_server) - The HTTP/1.1 and HTTP/2 server that Dream runs on. A fork of `mist`, with the module names of `mist`.
- [`dream_socket_server`](https://github.com/TrustBound/glisten/tree/dream-socket-server) [![Hex version of dream_socket_server](https://img.shields.io/hexpm/v/dream_socket_server?style=flat-square)](https://hex.pm/packages/dream_socket_server) - The TCP and TLS socket server under `dream_http_server`. A fork of `glisten`, with the module names of `glisten`.

Dream depends on `dream_http_server`, and `dream_http_server` depends on `dream_socket_server`, so you do not add them yourself. Add any other package to your `gleam.toml` when you need it. [Dream's HTTP server packages](contributing/http-server-packages.md) explains why the server packages are forks.

---

## Contributing
Want to help? Check out the [Contributing Guide](contributing/).

**Maintainers:** See [Publishing Strategy](contributing/publishing.md) for module publishing.





