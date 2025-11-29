# Core Patterns

**The core patterns Dream provides for building reliable web applications.**

Dream is deliberately small. Instead of a large framework with many
magical features, it gives you a handful of **reliable patterns** that
compose well together. This page is an overview of those patterns and
where to learn more about each.


## 1. Router + Thin Controllers

**What it is**

- The router maps `(method, path)` to a controller function.
- Controllers are small functions that:
  - Validate/parse input.
  - Call models and/or operations.
  - Call views to format a response.
  - Map domain errors to HTTP responses.

**Why**

- Keeps HTTP concerns (status codes, headers) in one place.
- Lets you test business logic separately.
- Makes routes easy to scan: "this path calls this function".

**Learn more**

- [Hello World](../learn/01-hello-world.md)
- [Controllers & Models Guide](../guides/controllers-and-models.md)


## 2. Context & Services

**What it is**

- `Context` – **per-request** data (request id, authenticated user,
  locale, etc.).
- `Services` – **application-wide** dependencies (database pool, HTTP
  client, caches, broadcaster, etc.).
- Both are passed explicitly into middleware and controllers.

**Why**

- No hidden globals or process dictionary tricks.
- The type system ensures every controller has the dependencies it
  expects.
- Makes unit tests easy: construct a `Services` value and call the
  function.

**Learn more**

- [Building an API](../learn/02-building-api.md)
- [Architecture Reference – Context & Services](architecture.md#4-context-system)


## 3. Middleware Onion

**What it is**

- Middleware wraps controllers: `fn(Request, Context, Services, Next) -> Response`.
- Each middleware can:
  - Enrich context (e.g., add `user` from auth token).
  - Transform requests or responses.
  - Short-circuit and return early.

**Why**

- Encapsulates cross-cutting concerns (logging, auth, rate limiting).
- Lets each route declare exactly which middleware it uses.
- Keeps controllers focused on their main job.

**Learn more**

- [Adding Auth](../learn/03-adding-auth.md)
- [Authentication Guide](../guides/authentication.md)


## 4. MVC: Controllers, Models, Views

**What it is**

- **Controllers** – HTTP layer: parse params, call models/operations,
  call views, return `Response`.
- **Models** – data access layer: talk to the database, return domain
  types and `dream.Error`.
- **Views** – presentation layer: turn domain types into strings
  (JSON/HTML/CSV) or templates.

**Why**

- Clear separation of concerns.
- Each layer is easy to test in isolation.
- Views can support multiple formats without touching models.

**Learn more**

- [Controllers & Models Guide](../guides/controllers-and-models.md)
- [Multiple Formats Guide](../guides/multiple-formats.md)


## 5. Operations (Business Logic)

**What it is**

- Operations are functions that encapsulate complex workflows:
  validation, multiple model calls, external services, side effects.
- Controllers become thin: "extract params → call operation → map
  errors → return response".

**Why**

- Keeps business logic out of controllers.
- Easy to test (no HTTP types involved).
- Reusable from REST, GraphQL, jobs, CLI, etc.

**When to use**

- Coordinating 2+ models or services.
- Complex business rules.
- Side effects (emails, search indexing, events).

**Learn more**

- [Advanced Patterns](../learn/04-advanced-patterns.md)
- [Operations Guide](../guides/operations.md)


## 6. Multi-Format Responses (JSON, HTML, HTMX, CSV)

**What it is**

- Single controller that can respond with different formats based on
  `request.format`, headers, or query params.
- Views provide `to_json`, `to_html`, `card`, `to_csv`, etc.

**Why**

- One backend for browsers, API clients, and HTMX.
- Shared business logic and models.
- Avoids duplicating controllers/routes by format.

**Learn more**

- [Multiple Formats Guide](../guides/multiple-formats.md)
- [multi_format example](../examples.md#multi_format)


## 7. Auth via Custom Context + Middleware

**What it is**

- Define `AuthContext` with a `user: Option(User)` field.
- Auth middleware validates credentials and populates `context.user`.
- Controllers pattern-match on `context.user` for auth/authorization
  decisions.

**Why**

- Auth logic is written once and applied to many routes.
- Controllers can assume `context.user` is set on protected routes.
- Easy to test: build an `AuthContext` with or without a user.

**Learn more**

- [Lesson 3: Adding Auth](../learn/03-adding-auth.md)
- [Authentication Guide](../guides/authentication.md)
- [custom_context example](../examples.md#4-custom_context)


## 8. Streaming (Ingress, Egress, SSE)

**What it is**

- **Ingress streaming** – `request.stream : Option(Yielder(BitArray))`
  for large request bodies (uploads, proxying).
- **Egress streaming** – `ResponseBody.Stream` for large responses or
  long-running streams.
- **Server-Sent Events** – a specialized streaming pattern for
  one-way, event-style updates.

**Why**

- Handle large or long-lived payloads without loading everything into
  memory.
- Fit naturally with the BEAM's concurrency model.

**Learn more**

- [Streaming Guide](../guides/streaming.md)
- [Streaming Quick Reference](../guides/streaming-quick-reference.md)
- [streaming_capabilities example](../examples.md#streaming_capabilities)


## 9. WebSockets + Broadcaster

**What it is**

- WebSocket upgrade pattern using
  `dream/servers/mist/websocket.upgrade_websocket`.
- Broadcaster service (`dream/services/broadcaster`) for pub/sub style
  fan-out.
- Handlers: `on_init`, `on_message`, `on_close` work with typed
  `Message(custom)` and `Action(state, custom)`.

**Why**

- Typed, testable WebSocket handling with no closures capturing hidden
  dependencies.
- Easy fan-out to many connected clients.

**Learn more**

- [WebSockets Guide](../guides/websockets.md)
- [websocket_chat example](../examples.md#websocket_chat)


## 10. Template Layering (Elements → Components → Pages → Layouts)

**What it is**

- Layered server-side rendering using Matcha + Gleam:
  - Elements (small `.matcha` templates).
  - Components (Gleam functions composing elements).
  - Pages (templates or Gleam functions composing components).
  - Layouts (outer shell: nav, footer, `<html>`/`<body>`).

**Why**

- No duplicated HTML snippets.
- Type-safe templates compiled to Gleam.
- Scales well as the UI grows.

**Learn more**

- [Template Composition Guide](../guides/templates.md)
- [tasks example](../examples.md#5-tasks)


## 11. Testing: Black Box + Unified Errors

**What it is**

- Test **public interfaces** only (controllers, operations, views).
- Use `dream.Error` everywhere in models/operations.
- Centralize error → response mapping in a helper (e.g.
  `response_helpers.handle_error`).

**Why**

- Tests survive refactors as long as behavior stays the same.
- Controllers stay thin and uniform.
- Assertion style remains consistent across your app.

**Learn more**

- [Testing Guide](../guides/testing.md)
- [REST API Guide – Error Handling](../guides/rest-api.md#error-handling)


## Next Steps

Use this page as a map of Dream's patterns:

- When you feel a controller getting big – reach for **Operations**.
- When you want HTML + JSON from one endpoint – use **Multi-Format**.
- When many routes share auth logic – use **Context + Middleware**.
- When payloads are large – use **Streaming**.
- When you need real-time features – use **WebSockets + Broadcaster**.
- When HTML grows – use **Template Layering**.

For deeper explanations and complete examples, follow the links in each
section or browse the [Guides](../guides/index.md) and
[Examples](../examples.md).

