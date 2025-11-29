# Router patterns

Short, focused patterns for defining routers in Dream. Each section:

- Explains **when** to use the pattern.
- Points to a **canonical example** in `examples/`.
- Shows a **small snippet** copied from that example.

This file is the single source of truth for router patterns. Other docs (concepts, guides) should link here instead of re-defining router examples.

---

## 1. Basic route

**Use this when** you just need a simple `(method, path) → controller` mapping with no params and no middleware.

**Canonical example:** `examples/simple/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/simple/src/router.gleam

```gleam
import controllers/posts_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/",
    controller: posts_controller.index,
    middleware: [],
  )
}
```

---

## 2. Route with path parameters

**Use this when** you need typed path parameters like `/users/:id` or `/users/:id/posts/:post_id`.

- Router declares the pattern with `:param_name`.
- Controller extracts values using helpers like `require_int/2` or `require_string/2`.

**Canonical example:** `examples/simple/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/simple/src/router.gleam

```gleam
// Inside create_router()
router()
|> route(
  method: Get,
  path: "/users/:id/posts/:post_id",
  controller: posts_controller.show,
  middleware: [],
)
```

The matching controller lives in `examples/simple/src/controllers/posts_controller.gleam` and uses `require_string(request, "id")` and `require_string(request, "post_id")` to read parameters.

---

## 3. Route with middleware

**Use this when** a route needs additional cross-cutting behavior such as authentication, admin checks, logging, or rate limiting.

- Middleware runs **before** the controller.
- Each route defines its own middleware chain; there is no hidden global middleware list.

**Canonical examples:**

- Auth + admin: `examples/custom_context/src/router.gleam`  
  GitHub: https://github.com/TrustBound/dream/blob/main/examples/custom_context/src/router.gleam
- Rate limiting: `examples/rate_limiter/src/router.gleam`  
  GitHub: https://github.com/TrustBound/dream/blob/main/examples/rate_limiter/src/router.gleam

```gleam
// examples/custom_context/src/router.gleam
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

---

## 4. Router with custom Context and Services

**Use this when** your application has non-trivial per-request `Context` and shared `Services` types.

- The router is typed as `Router(Context, Services)`.
- The same `Context` and `Services` types appear in every controller signature.

**Canonical example:** `examples/custom_context/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/custom_context/src/router.gleam

```gleam
import context.{type AuthContext}
import services.{type Services}
import dream/router.{type Router, route, router}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  |> route(...)
}
```

The `AuthContext` and `Services` types are defined in:

- `examples/custom_context/src/context.gleam`
- `examples/custom_context/src/services.gleam`

---

## 5. Wildcard routes

**Use this when** you need to serve static assets or match arbitrary trailing path segments.

- `**name` matches one or more path segments and binds them to `name`.
- Commonly used for static file serving, CDNs, or catch-all routes.

**Canonical example:** `examples/websocket_chat/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/websocket_chat/src/router.gleam

```gleam
import controllers/static_controller
import dream/http/request.{Get}
import dream/router.{route, router}

pub fn create() {
  router()
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
}
```

The controller can then use the `filepath` param to locate the asset.

---

## 6. Streaming routes

**Use this when** you want to stream large request bodies (uploads), large responses (downloads), or proxied streams.

- Use `stream_route/4` for streaming handlers.
- You can still attach middleware, including streaming-aware middleware.

**Canonical example:** `examples/streaming_capabilities/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/streaming_capabilities/src/router.gleam

```gleam
import controllers/stream_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get, Post}
import dream/router.{type Router, router, stream_route}
import middleware/transform_middleware
import services.{type Services}

pub fn create() -> Router(EmptyContext, Services) {
  router()
  // Ingress streaming (uploads)
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: stream_controller.upload,
    middleware: [],
  )
  // Egress streaming (downloads)
  |> router.route(
    method: Get,
    path: "/download",
    controller: stream_controller.download,
    middleware: [],
  )
  // Bi-directional streaming with middleware
  |> stream_route(
    method: Post,
    path: "/echo_transform",
    controller: stream_controller.echo_transform,
    middleware: [
      transform_middleware.uppercase_incoming,
      transform_middleware.replace_space_outgoing,
    ],
  )
}
```

See the `streaming_capabilities` example for full controller and middleware implementations.

---

## 7. WebSocket routes

**Use this when** a normal HTTP route should upgrade the connection to a WebSocket.

- From the router's perspective, this is just a regular `route` entry.
- The controller calls `upgrade_websocket` and hands control to a WebSocket handler.

**Canonical example:** `examples/websocket_chat/src/router.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/websocket_chat/src/router.gleam

```gleam
import controllers/chat
import controllers/home
import controllers/static_controller
import dream/http/request.{Get}
import dream/router.{route, router}

pub fn create() {
  router()
  |> route(Get, "/", home.show, [])
  |> route(Get, "/chat", chat.handle_chat_upgrade, [])
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
}
```

See the `examples/websocket_chat` app and the WebSockets guide for how `chat.handle_chat_upgrade` uses `upgrade_websocket` to start a WebSocket connection.
