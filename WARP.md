# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Development commands

This repository is a Gleam library. Use the `gleam` CLI and the top-level `Makefile` when developing.

### Core workflows

- **Build the library**
  - `gleam build`
  - or `make build`

- **Run the full test suite**
  - `gleam test`
  - or `make test`

- **Type-check without building artifacts**
  - `gleam check`

- **Format the codebase**
  - `gleam format`
  - `make format` does the same across the project.

- **Run CI-style checks locally** (format check, build, unit tests with the 100% line coverage gate, docs code block check)
  - `make check`

- **Check the docs code blocks against their tested snippets**
  - `make check-snippets`

- **Clean build artifacts**
  - `make clean`

- **Build local documentation**
  - `gleam docs build`
  - or `make docs`

### Running specific tests

Tests live under `test/` and mirror the `src/` structure.

- **Test entrypoint**
  - `test/dream_test.gleam` runs all test modules with the `dream_test` runner and measures line coverage of `src/`. A new test module runs only after it is added to that list.

Some examples under `examples/` define additional targets (e.g. to run servers) in their own `Makefile` and `README.md`. When working inside an example, `cd` into that directory and use its documented commands.

## Testing expectations

The project has strong testing requirements:

- Tests follow a **black-box** philosophy: test public interfaces and observable behavior, not private functions or implementation details.
- Unit tests must be isolated (no network, filesystem, or real databases), fast, and deterministic.
- `src/dream/` is expected to have **100% test coverage**. If a private function cannot be reached via public APIs, it is treated as dead code.
- Tests use `dream_test` (`describe`/`group` and `it`), not `_test` functions. Name the `group` for the function and each `it` for the expected result and the condition (see `docs/contributing/contributing.md`, "Test Naming").
- Test layout mirrors `src/` structure (e.g. `test/dream/router_test.gleam` exercises `src/dream/router.gleam`).

For integration-style tests (real databases, HTTP, etc.), follow the patterns documented in `docs/contributing/testing.md`, `docs/guides/testing.md` and the `test/integration/` directory of each example.

## Architecture overview

Dream is a **composable web library for Gleam/BEAM**, not a framework. It provides explicit building blocks (types and functions) rather than an opinionated application skeleton.

### Core library (`src/dream`)

The core `dream` package lives under `src/dream` and is what consumers depend on from Hex.pm.

Key concepts, as implemented here and described in `docs/reference/architecture.md`:

- **Router (`router.gleam` + `router/` submodules)**
  - Holds a list of `Route(context, services)` values.
  - Matches requests by HTTP method and path pattern (including parameters like `:id` and wildcards `*` / `**`).
  - Associates each route with a controller function and a chain of middleware.
  - Builds a controller/middleware chain so middleware wrap controllers in a predictable order.

- **Dream server (`dream/dream.gleam`)**
  - Defines the opaque `Dream(server, context, services, router)` type encapsulating:
    - The underlying HTTP server implementation (Mist builder).
    - The router instance.
    - A "template" context value cloned per request.
    - Optional services (application dependencies).
    - Server configuration such as `max_body_size`.
  - Exposes `route_request/4`, which finds the matching route, attaches path params to the request, builds the middleware chain, and returns a `Response` (404 when no route has the path, 405 when a route has the path but not the method).

- **HTTP convenience layer (`http.gleam` + `http/` submodules)**
  - Re-exports HTTP types (`Request`, `Response`, `Method`, `Header`, `Cookie`, `PathParam`, etc.).
  - Centralizes common helpers:
    - Response builders (`text_response`, `json_response`, `html_response`, etc.).
    - Status values (`ok`, `not_found`, etc.).
    - Parameter access/validation (`get_param`, `require_int`, etc.).
    - Header and cookie utilities.
  - Controllers in examples typically import `dream/http` and work only with these abstractions.

- **Context and services (`context.gleam` and user-defined types)**
  - `Context` is **per-request** data (e.g. `AppContext` with `request_id` and optionally user info).
  - `Services` are **application-wide** dependencies injected at startup (DB pools, HTTP clients, caches, config, etc.).
  - Both are fully typed and are threaded explicitly through middleware and controllers, so dependencies are never hidden.

- **Middleware**
  - Modeled as functions that wrap a `NextHandler` and can:
    - Enrich/transform the `Request` or `Context` on the way in.
    - Short-circuit with an early `Response`.
    - Observe/modify the `Response` on the way out.
  - Middleware are attached per-route (no global middleware list), so behavior is clear from the router definition.

Together, these pieces implement a predictable pipeline:

> request → context creation → router match → middleware chain → controller → response

### Application patterns encouraged by Dream

While Dream is a library, the docs and examples promote a set of scalable patterns:

- **MVC-style separation**
  - **Controllers**: HTTP-facing functions that parse/validate params, call models/operations, and map results to `Response`s.
  - **Models**: Data access functions (in the examples, generated by `dream_model` from `.sql` files, with `dream_postgres`) returning domain types and `dream.Error` values.
  - **Views**: Pure formatting layer (HTML, JSON, CSV, etc.) that takes domain types and returns strings, often delegating to template components.

- **Operations**
  - Encapsulate non-trivial business workflows that may touch multiple models and services.
  - Intended to be reusable across HTTP controllers, background jobs, and CLIs.

- **Template layering for SSR** (demonstrated in `examples/tasks`)
  - Elements → Components → Pages → Layouts to keep HTML DRY and type-safe while supporting server-side rendering.

These patterns are described in the top-level `README.md` and `docs/reference/architecture.md`; when editing code, keep new APIs and examples consistent with those documents.

### Modules ecosystem

Additional functionality lives in separate Gleam packages, each in its own repository with its own `gleam.toml`, `manifest.toml`, and `Makefile`. They follow the same design principles (explicit dependencies, builder patterns, strong typing).

At a high level:

- **[`dream_postgres`](https://github.com/TrustBound/dream_postgres)** – Postgres helpers (query/result helpers, error mapping, `check_schema`). The model modules that `dream_model` generates use its `dream_postgres/client` module.
- **[`dream_http_client`](https://github.com/TrustBound/dream_http_client)** – A builder-style HTTP client, supporting streaming and non-streaming HTTP(S) requests.
- **[`dream_config`](https://github.com/TrustBound/dream_config)** – Configuration loading helpers (environment variables, `.env`, typed config loading).
- **[`dream_opensearch`](https://github.com/TrustBound/dream_opensearch)** – OpenSearch client and document helpers.
- **[`dream_ets`](https://github.com/TrustBound/dream_ets)** – ETS utilities for in-memory state such as caches or rate limiters.
- **[`dream_json`](https://github.com/TrustBound/dream_json)** – JSON encoding helpers.
- **[`dream_mock_server`](https://github.com/TrustBound/dream_mock_server)** – A mock HTTP server for tests.

Consumers depend on these modules individually from Hex, and the `docs/reference/architecture.md` file documents typical usage patterns.

### Examples (`examples/`)

`examples/` contains full, runnable Gleam projects illustrating how to use Dream in different scenarios (simple apps, multi-format responses, streaming, tasks app with SSR, custom context, database-backed apps, rate limiting, etc.). Each example is its own Gleam project with:

- A `gleam.toml` and `manifest.toml`.
- A local `Makefile` and `README.md` explaining how to run and test that example.

When you need a concrete usage pattern (e.g. SSR, operations, multi-format responses, or database access), prefer to base new code and docs on the closest existing example.

### Documentation layout (`docs/`)

The `docs/` tree is the canonical source for user-facing concepts and should stay in sync with the code:

- `docs/guides/` – Task guides (getting started, routing, request data, responses, database API, JSON APIs, templates, streaming, SSE, WebSockets, HTTP/2, testing, deployment, operating, upgrading to 3).
- `docs/concepts/` – Concepts and patterns.
- `docs/reference/` – Technical reference, including `architecture.md`, `design-principles.md`, `dream-vs-mist.md`, and `naming-conventions.md`.
- `docs/contributing/` – Contribution rules: code style, the docs code block check, testing, publishing and tone.

Every code block in the docs is an exact copy of a tested file, with a "tested snippet" badge. `make check-snippets` fails otherwise. Read `docs/contributing/contributing.md`, "Code Blocks in READMEs and Guides", before you add a code block.

When changing APIs or patterns in `src/dream`, look for corresponding guides or reference docs and update them together.

## Conventions and code style specific to this repo

These rules come from `CONTRIBUTING.md` and `docs/reference/naming-conventions.md` and should guide how Warp edits or generates code here.

- **Philosophy**
  - Dream is a **library, not a framework**: provide composable primitives and patterns, not rigid structure.
  - Favor **explicit over implicit** behavior (no hidden globals, avoid magic).
  - Prioritize **simple, obvious code** over cleverness.
  - Avoid capturing important dependencies in **closures**; pass them explicitly via parameters or the `Services` type.

- **Naming**
  - Functions generally follow a `{verb}_{noun}` pattern with clear, non-abbreviated names (e.g. `parse_cookie_string`, `match_path`, `route_request`).
  - Do not prefix function names with their module name (`router.route`, not `router_add_route`).
  - Domain-standard abbreviations like `http`, `json`, `id`, `url` are acceptable; arbitrary short forms (`req`, `resp`, `cfg`) are not.
  - Builder-style APIs are allowed to use concise verbs without nouns when context is obvious (e.g. `bind`, `listen`, `method`, `path` on a builder).

- **Documentation**
  - All **public functions** should have Gleam doc comments that include:
    - A concise description of behavior.
    - Example usage (including relevant imports) where appropriate. The example is a tested snippet with a heading and a badge, like every other docs code block.
    - Any non-obvious notes or caveats.

- **Project structure expectations**
  - `src/dream/` defines core types, servers, routing, HTTP utilities, and related helpers.
  - `test/dream/` mirrors that structure.
  - `examples/` holds separate Gleam projects. They should remain loosely coupled demos rather than tightly integrated framework code.

When modifying or generating code, align with these existing patterns and keep the documentation and examples consistent with the behavior of the library.