# Controller patterns

Short, focused patterns for Dream controllers. Each section:

- Explains **when** to use the pattern.
- Points to a **canonical example** in `examples/`.
- Shows a **small snippet** copied from that example.

Controllers have the conceptual shape:

```gleam
fn(Request, Context, Services) -> Response
```

Other docs (concepts, guides) should link here instead of redefining controller examples.

---

## 1. Basic controller (no operations)

**Use this when** you have simple behavior: parse a few params (or none), optionally call a service directly, and render a response. No separate operations module.

**Canonical example:** `examples/simple/src/controllers/posts_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/simple/src/controllers/posts_controller.gleam

```gleam
import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import views/post_view

/// Index action - displays hello world
pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, post_view.format_index())
}
```

This pattern is ideal for very small apps and examples, or for routes that just render a simple page with no data access.

---

## 2. Controller with path parameters

**Use this when** your controller needs path parameters like `:id` or `:post_id` from the router.

- The router declares `:id` and `:post_id` in the path.
- The controller extracts and validates the parameters using helpers like `require_string/2` or `require_int/2`.

**Canonical example:** `examples/simple/src/controllers/posts_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/simple/src/controllers/posts_controller.gleam

```gleam
/// Show action - demonstrates path parameters and makes HTTPS request
pub fn show(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let result = {
    use user_id <- result.try(http.require_string(request, "id"))
    use post_id <- result.try(http.require_string(request, "post_id"))
    Ok(#(user_id, post_id))
  }

  case result {
    Ok(#(user_id, post_id)) -> make_request_and_respond(user_id, post_id)
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

The matching route lives in `examples/simple/src/router.gleam` as `/users/:id/posts/:post_id`.

---

## 3. Thin controller that calls operations

**Use this when** your controller is coordinating non-trivial business logic: multiple models/services, complex validation, or reusable workflows.

- Controller stays thin: parse/validate input, call an operation, choose a view.
- Operation lives in `operations/` and returns `Result(_, dream.Error)`.

**Canonical example:** `examples/database/src/controllers/users_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/database/src/controllers/users_controller.gleam

```gleam
import context.{type DatabaseContext}
import dream/http.{type Request, type Response, require_int}
import dream/http/response.{json_response}
import dream/http/status
import gleam/result
import operations/user_operations
import services.{type Services}
import utilities/response_helpers
import views/user_view

/// Get a single user by ID
pub fn show(
  request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    user_operations.get_user(db, id)
  }

  case result {
    Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

This pattern appears across the `examples/database` app for both users and posts.

---

## 4. Controller with custom Context

**Use this when** your controllers need per-request data beyond the raw `Request`, such as an authenticated user or request ID.

- Middleware populates a custom `Context` type (e.g. `AuthContext`, `TasksContext`).
- Controllers receive that context and *can* use it to make decisions.

**We do not yet have a canonical example that actively reads fields from a custom Context in a controller.** Current examples (`examples/custom_context`, `examples/tasks`) show controllers that accept custom context types in their signatures but don’t inspect them.

If you’d like to contribute a full example of this pattern (e.g. a controller that branches on `context.user`), please send a pull request adding a small example app under `examples/` and update this section to point at it.

---

## 5. Controller with multi-format responses

**Use this when** you want the same controller to serve multiple formats (HTML, JSON, HTMX, CSV, streaming) based on the URL or parameters.

- The controller chooses the format from the path, from a param, or from headers.
- Views provide functions for each format.

**Canonical example:** `examples/multi_format/src/controllers/products_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/multi_format/src/controllers/products_controller.gleam

```gleam
import context.{type AppContext}
import dream/http.{type Request, type Response}
import dream/http/request.{type PathParam, get_param}
import dream/http/response.{
  html_response, json_response, stream_response, text_response,
}
import dream/http/status
import gleam/option
import gleam/result
import gleam/string
import operations/product_operations
import services.{type Services}
import types/product.{type Product}
import utilities/response_helpers
import views/products/view as product_view

/// Show single product - supports .json, .htmx, .csv extensions
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use param <- result.try(result.map_error(
      get_param(request, "id"),
      map_param_error,
    ))
    use id <- result.try(parse_int_param(param))
    let format = param.format
    let db = services.database.connection
    use product <- result.try(product_operations.get_product(db, id))
    Ok(#(product, format))
  }

  case result {
    Ok(#(product, format)) -> respond_with_format(product, format)
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

The helper `respond_with_format/2` selects between JSON, HTMX fragments, CSV, or HTML.

---

## 6. Streaming controllers

**Use this when** your controller needs to work with streaming request bodies or streaming responses.

- For ingress streaming, read from `request.stream` (a `Yielder`).
- For egress streaming, use `stream_response/3` with a `Yielder`.

**Canonical example:** `examples/streaming_capabilities/src/controllers/stream_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/streaming_capabilities/src/controllers/stream_controller.gleam

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/yielder
import services.{type Services}

/// Ingress Streaming: Receives a stream and "saves" it (logs size)
pub fn upload(
  request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    }
    None -> text_response(status.bad_request, "Expected streaming request body")
  }
}

fn accumulate_chunk_size(acc: Int, chunk: BitArray) -> Int {
  let size = bit_array.byte_size(chunk)
  // Simulate saving to disk
  acc + size
}
```

The same module shows egress streaming (`download`) and proxied streaming (`proxy`).

---

## 7. WebSocket upgrade controllers

**Use this when** a controller should upgrade the HTTP request to a WebSocket connection.

- The router calls this controller for a normal GET route.
- The controller calls `websocket.upgrade_websocket` with:
  - The `Request`,
  - A dependencies value (bundling user + services),
  - Handlers for `on_init`, `on_message`, and `on_close`.

**Canonical example:** `examples/websocket_chat/src/controllers/chat.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/websocket_chat/src/controllers/chat.gleam

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import gleam/option
import services.{type Services}

/// Dependencies for WebSocket handlers
type ChatDependencies {
  ChatDependencies(user: String, services: Services)
}

/// Handle WebSocket upgrade request for chat
pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user = request.get_query_param(request.query, "user")
  let user = option.unwrap(user, "Anonymous")

  let dependencies = ChatDependencies(user: user, services: services)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
}
```

The rest of the module shows the WebSocket handlers (`handle_websocket_init`, `handle_websocket_message`, `handle_websocket_close`) and how they integrate with `dream/services/broadcaster`.

---

## 8. Error handling via response helpers

Most non-trivial controllers in Dream use a shared response helper module to map `dream.Error` values to HTTP responses.

**Canonical example:** `examples/database/src/controllers/users_controller.gleam`  
GitHub: https://github.com/TrustBound/dream/blob/main/examples/database/src/controllers/users_controller.gleam

```gleam
case result {
  Ok(user_data) -> json_response(status.ok, user_view.to_json(user_data))
  Error(err) -> response_helpers.handle_error(err)
}
```

The actual `response_helpers.handle_error/1` function lives in `examples/database/src/utilities/response_helpers.gleam` and centralizes how errors are turned into HTTP responses. Controllers just call it instead of handling each error case inline.
