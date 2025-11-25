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

- **Run CI-style checks locally** (format check + build + tests)
  - `make check`

- **Clean build artifacts**
  - `make clean`

- **Build local documentation**
  - `gleam docs build`
  - or `make docs`

### Running specific tests

Tests live under `test/` and mirror the `src/` structure.

- **Test entrypoint**
  - `test/dream_test.gleam` runs all test modules via `gleeunit.main()`.

- **Run tests for a single module** (example from this repo)
  - `gleam test --module dream/router_test`

- **Watch tests on file changes**
  - `gleam test --watch`

Some examples under `examples/` define additional targets (e.g. to run servers) in their own `Makefile` and `README.md`. When working inside an example, `cd` into that directory and use its documented commands.

## Testing expectations

The project has strong testing requirements:

- Tests follow a **black-box** philosophy: test public interfaces and observable behavior, not private functions or implementation details.
- Unit tests must be isolated (no network, filesystem, or real databases), fast, and deterministic.
- `src/dream/` is expected to have **100% test coverage**. If a private function cannot be reached via public APIs, it is treated as dead code.
- Test naming convention:
  - `function_name_with_condition_returns_expected_result_test()`
- Test layout mirrors `src/` structure (e.g. `test/dream/router_test.gleam` exercises `src/dream/router.gleam`).

For integration-style tests (real databases, HTTP, etc.), follow the patterns documented in `docs/guides/testing.md` and the `examples/tasks` project (which uses a dedicated `test/integration/` directory).

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

- **Dream server (`dream.gleam`)**
  - Defines the generic `Dream(server, context, services)` type encapsulating:
    - The underlying HTTP server implementation (Mist builder).
    - The router instance.
    - A "template" context value cloned per request.
    - Optional services (application dependencies).
    - Server configuration such as `max_body_size`.
  - Exposes `route_request/4`, which finds the matching route, attaches path params to the request, builds the middleware chain, and returns a `Response` (404 if unmatched).

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
  - **Models**: Data access functions (often using `dream_postgres` + `squirrel` in consuming apps) returning domain types and `dream.Error` values.
  - **Views**: Pure formatting layer (HTML, JSON, CSV, etc.) that takes domain types and returns strings, often delegating to template components.

- **Operations**
  - Encapsulate non-trivial business workflows that may touch multiple models and services.
  - Intended to be reusable across HTTP controllers, background jobs, and CLIs.

- **Template layering for SSR** (demonstrated in `examples/tasks`)
  - Elements → Components → Pages → Layouts to keep HTML DRY and type-safe while supporting server-side rendering.

These patterns are described in the top-level `README.md` and `docs/reference/architecture.md`; when editing code, keep new APIs and examples consistent with those documents.

### Modules ecosystem (`modules/`)

Additional functionality lives in separate Gleam packages under `modules/`, each with its own `gleam.toml`, `manifest.toml`, and `Makefile`. They follow the same design principles (explicit dependencies, builder patterns, strong typing).

At a high level:

- **`modules/postgres`** – Postgres helpers (query/result helpers, error mapping) designed to work with Squirrel-generated SQL.
- **`modules/http_client`** – A builder-style HTTP client on top of Erlang's `httpc`, supporting streaming and non-streaming HTTP(S) requests.
- **`modules/config`** – Configuration loading helpers (environment variables, `.env`, typed config loading).
- **`modules/opensearch`** – OpenSearch client and document helpers.
- **`modules/ets`** – ETS utilities for in-memory state such as caches or rate limiters.
- **`modules/helpers` and other utilities** – Shared helpers and optional conveniences.

Consumers can depend on these modules individually (e.g. via Hex or local `path` dependencies), and the `docs/reference/architecture.md` file documents typical usage patterns.

### Examples (`examples/`)

`examples/` contains full, runnable Gleam projects illustrating how to use Dream in different scenarios (simple apps, multi-format responses, streaming, tasks app with SSR, custom context, database-backed apps, rate limiting, etc.). Each example is its own Gleam project with:

- A `gleam.toml` and `manifest.toml`.
- A local `Makefile` and `README.md` explaining how to run and test that example.

When you need a concrete usage pattern (e.g. SSR, operations, multi-format responses, or database access), prefer to base new code and docs on the closest existing example.

### Documentation layout (`docs/`)

The `docs/` tree is the canonical source for user-facing concepts and should stay in sync with the code:

- `docs/quickstart.md` – 5-minute introduction to building a Dream app.
- `docs/learn/` – Learning path from "hello world" to production patterns.
- `docs/guides/` – Focused guides (authentication, controllers & models, operations, multiple formats, testing, deployment, etc.).
- `docs/reference/` – Technical reference, including `architecture.md`, `design-principles.md`, `dream-vs-mist.md`, and `naming-conventions.md`.
- `docs/contributing/` – Docs-specific contribution guidelines and tone.

When changing APIs or patterns in `src/dream` or `modules/`, look for corresponding guides or reference docs and update them together.

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
    - Example usage (including relevant imports) where appropriate.
    - Any non-obvious notes or caveats.

- **Project structure expectations**
  - `src/dream/` defines core types, servers, routing, HTTP utilities, and related helpers.
  - `test/dream/` mirrors that structure.
  - `modules/` and `examples/` are separate Gleam projects and should remain loosely coupled building blocks or demos rather than tightly integrated framework code.

When modifying or generating code, align with these existing patterns and keep the documentation and examples consistent with the behavior of the library.