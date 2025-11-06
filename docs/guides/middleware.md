# Guide: Middleware

**Everything you need to know about intercepting requests before they hit your controllers.**

Middleware is code that runs before (and optionally after) your controller. It's how you handle cross-cutting concerns: authentication, logging, rate limiting, CORS, etc.

In Dream, middleware is just a function with a specific signature. No base classes. No magic registration. Just functions that chain together.

## Middleware Signature

```gleam
fn(Request, Context, Services, NextHandler) -> Response
```

Where `NextHandler` is:

```gleam
fn(Request, Context, Services) -> Response
```

The middleware receives:
- `request` - The HTTP request
- `context` - Per-request context (mutable by middleware)
- `services` - Application services (immutable)
- `next` - The next middleware or controller in the chain

It returns a `Response`.

## Basic Example

Here's auth middleware that checks for a token:

```gleam
import dream/core/http/statuses.{unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, get_header, text_response,
}
import gleam/option
import your_app/context.{type AuthContext}
import your_app/services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized")
    option.Some(token) -> {
      case validate_token(token) {
        option.None -> text_response(unauthorized_status(), "Invalid token")
        option.Some(user) -> {
          let updated_context = AuthContext(
            request_id: context.request_id,
            user: option.Some(user),
          )
          next(request, updated_context, services)
        }
      }
    }
  }
}
```

Middleware can:
1. **Short-circuit** - Return a response without calling `next()`
2. **Transform context** - Update context before passing to `next()`
3. **Transform response** - Call `next()` then modify its response
4. **Log/monitor** - Observe request/response without changing them

## Adding Middleware to Routes

In your router:

```gleam
import dream/core/http/transaction.{Get, Post}
import dream/core/router.{route, router}
import your_app/controllers/posts_controller
import your_app/middleware/auth_middleware.{auth_middleware}
import your_app/middleware/logging_middleware.{logging_middleware}

pub fn create_router() -> Router(AuthContext, Services) {
  router
  // No middleware - public route
  |> route(
    method: Get,
    path: "/public",
    controller: posts_controller.public,
    middleware: [],
  )
  // Single middleware
  |> route(
    method: Get,
    path: "/posts",
    controller: posts_controller.index,
    middleware: [auth_middleware],
  )
  // Multiple middleware (chains in order)
  |> route(
    method: Post,
    path: "/posts",
    controller: posts_controller.create,
    middleware: [logging_middleware, auth_middleware],
  )
}
```

Middleware executes in the order you list them. For `[logging_middleware, auth_middleware]`:

```
Request 
  → logging_middleware
    → auth_middleware
      → controller
        → Response (flows back through middleware)
```

## Execution Order

Middleware wraps like Russian nesting dolls:

```gleam
middleware: [first, second, third]
```

Becomes:

```
first(request, context, services, fn(req, ctx, svc) {
  second(req, ctx, svc, fn(req2, ctx2, svc2) {
    third(req2, ctx2, svc2, fn(req3, ctx3, svc3) {
      controller(req3, ctx3, svc3)
    })
  })
})
```

Each middleware wraps the next. The first middleware listed is the outermost wrapper.

## Common Patterns

### Logging Middleware

```gleam
import gleam/io

pub fn logging_middleware(request, context, services, next) {
  // Log before
  io.println("→ " <> request.method <> " " <> request.path)
  
  // Call next
  let response = next(request, context, services)
  
  // Log after
  io.println("← " <> int.to_string(response.status) <> " " <> request.path)
  
  response
}
```

### CORS Middleware

```gleam
import dream/core/http/transaction.{add_header}

pub fn cors_middleware(request, context, services, next) {
  let response = next(request, context, services)
  
  response
  |> add_header("Access-Control-Allow-Origin", "*")
  |> add_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  |> add_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
}
```

### Rate Limiting Middleware

```gleam
import dream/core/http/statuses.{too_many_requests_status}

pub fn rate_limit_middleware(request, context, services, next) {
  let ip = get_client_ip(request)
  let count = get_request_count(services.cache, ip)
  
  case count > 100 {
    True -> text_response(too_many_requests_status(), "Rate limit exceeded")
    False -> {
      increment_request_count(services.cache, ip)
      next(request, context, services)
    }
  }
}
```

### Request ID Middleware

```gleam
import gleam/string_builder
import youid/uuid

pub fn request_id_middleware(request, context, services, next) {
  let request_id = uuid.v4_string()
  let updated_context = Context(request_id:, ..context)
  next(request, updated_context, services)
}
```

### Error Handling Middleware

```gleam
pub fn error_handler_middleware(request, context, services, next) {
  case next(request, context, services) {
    response if response.status >= 500 -> {
      // Log error
      log_error(services.logger, request, response)
      response
    }
    response -> response
  }
}
```

## Parameterized Middleware

Want to create middleware with configuration? Use a factory function:

```gleam
pub fn require_role(required_role: String) {
  fn(request, context, services, next) {
    case context.user {
      option.None -> text_response(unauthorized_status(), "Unauthorized")
      option.Some(user) -> {
        case user.role == required_role {
          True -> next(request, context, services)
          False -> text_response(forbidden_status(), "Forbidden")
        }
      }
    }
  }
}
```

Use it in routes:

```gleam
router
|> route(
  method: Post,
  path: "/admin/settings",
  controller: admin_controller.update_settings,
  middleware: [auth_middleware, require_role("admin")],
)
|> route(
  method: Get,
  path: "/moderator/reports",
  controller: moderator_controller.list_reports,
  middleware: [auth_middleware, require_role("moderator")],
)
```

## Modifying Context

Middleware can update context before passing to the next handler:

```gleam
pub fn user_loader_middleware(request, context, services, next) {
  case context.user_id {
    option.None -> next(request, context, services)
    option.Some(user_id) -> {
      case user.get(services.database, user_id) {
        Ok(user) -> {
          let updated_context = Context(..context, loaded_user: option.Some(user))
          next(request, updated_context, services)
        }
        Error(_) -> next(request, context, services)
      }
    }
  }
}
```

This lets controllers access pre-loaded data without querying again.

## Short-Circuiting

Middleware can return early without calling `next()`:

```gleam
pub fn maintenance_mode_middleware(request, context, services, next) {
  case services.config.maintenance_mode {
    True ->
      text_response(
        service_unavailable_status(),
        "Service temporarily unavailable",
      )
    False -> next(request, context, services)
  }
}
```

Once middleware returns, the chain stops. No further middleware or controllers run.

## Testing Middleware

Test middleware independently:

```gleam
import gleeunit/should

pub fn auth_middleware_without_token_returns_401_test() {
  // Arrange
  let request = test_request_without_headers()
  let context = test_context()
  let services = test_services()
  let next = fn(_req, _ctx, _svc) {
    panic as "Should not call next"
  }
  
  // Act
  let response = auth_middleware(request, context, services, next)
  
  // Assert
  response.status |> should.equal(401)
}

pub fn auth_middleware_with_valid_token_calls_next_test() {
  // Arrange
  let request = test_request_with_header("Authorization", "Bearer valid-token")
  let context = test_context()
  let services = test_services()
  let mut called = False
  let next = fn(req, ctx, svc) {
    called = True
    text_response(ok_status(), "Success")
  }
  
  // Act
  let response = auth_middleware(request, context, services, next)
  
  // Assert
  called |> should.equal(True)
  response.status |> should.equal(200)
}
```

## Global vs Route-Specific Middleware

Dream doesn't have "global" middleware that runs on every request. Middleware is explicit per route.

**Why?** Because finding which middleware runs on which route shouldn't require reading the entire codebase. With per-route middleware, you look at the route definition and see exactly what runs.

For middleware you want on *most* routes, create a helper:

```gleam
pub fn standard_middleware() -> List(Middleware(Context, Services)) {
  [logging_middleware, request_id_middleware, error_handler_middleware]
}

pub fn authenticated_middleware() -> List(Middleware(Context, Services)) {
  list.append(standard_middleware(), [auth_middleware])
}
```

Use in routes:

```gleam
router
|> route(
  method: Get,
  path: "/public",
  controller: posts_controller.public,
  middleware: standard_middleware(),
)
|> route(
  method: Get,
  path: "/posts",
  controller: posts_controller.index,
  middleware: authenticated_middleware(),
)
```

Still explicit. Still readable.

## Middleware vs Controllers

**Use middleware when:**
- Logic applies to multiple routes
- Logic should run before controller logic
- Logic needs to short-circuit (prevent controller execution)
- Logic modifies context for downstream use

**Use controllers when:**
- Logic is specific to one endpoint
- Logic requires route parameters
- Logic returns different responses based on business rules

If you're debating, default to controllers. Middleware should be generic.

## Performance Considerations

Each middleware adds overhead. Keep them:
- **Fast** - Middleware runs on every matching request
- **Focused** - One responsibility per middleware
- **Minimal** - Don't check database unless necessary

Bad:

```gleam
pub fn slow_middleware(request, context, services, next) {
  // Queries database on every request, even if not needed
  let user = user.get_by_email(services.database, request.email)
  let permissions = permissions.get_all(services.database, user.id)
  let settings = settings.get(services.database, user.id)
  
  // ... uses none of this data ...
  
  next(request, context, services)
}
```

Good:

```gleam
pub fn fast_middleware(request, context, services, next) {
  // Only loads what's needed
  case context.user_id {
    option.Some(id) -> {
      let user = user.get(services.database, id)
      let updated_context = Context(..context, user:)
      next(request, updated_context, services)
    }
    option.None -> next(request, context, services)
  }
}
```

## Summary

Middleware in Dream:
- ✅ Just functions with a specific signature
- ✅ Chains in the order you list them
- ✅ Can short-circuit or transform requests/responses
- ✅ Explicitly attached to routes (no hidden global middleware)
- ✅ Testable independently
- ✅ Can be parameterized with factory functions

**Want to see examples?**

Check out `src/examples/custom_context/middleware/` for:
- Authentication middleware
- Authorization middleware
- Context transformation

---

**[← Back: Controllers and Models](controllers-and-models.md)** | **[Up: Documentation](../../README.md)** | **[Next: Testing →](testing.md)**

