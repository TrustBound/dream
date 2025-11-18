# Lesson 3: Adding Auth

**Time:** 30 minutes  
**Goal:** Learn custom context and middleware for authentication

You'll add authentication to protect your API routes.

## What You'll Learn

- Custom context types for user info
- Middleware for cross-cutting concerns
- How middleware enriches context
- Protecting routes

## Prerequisites

- [Lesson 2: Building an API](02-building-api.md) completed

## The Problem

Right now, anyone can create or delete users. You need:
- Authentication (who is making the request?)
- Authorization (are they allowed to do this?)

## Step 1: Define Custom Context

Create `src/context.gleam`:

```gleam
import gleam/option.{type Option, None, Some}

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(
    request_id: String,
    user: Option(User),
  )
}

pub const context = AuthContext(request_id: "", user: None)
```

**What changed:**

In Lessons 1-2, you used `AppContext` (Dream's default with just `request_id`).

Now you have `AuthContext` with:
- `request_id` - Still here for tracking requests
- `user` - Added for authenticated user info

This is **per-request data** - it changes for each request. The user making request A is different from request B.

**Context vs Services:**

- **Context** = per-request (user, session) - changes every request
- **Services** = shared (database, cache) - same for all requests

## Step 2: Create Auth Middleware

Create `src/middleware/auth_middleware.gleam`:

```gleam
import context.{type AuthContext, type User}
import dream/http/response.{text_response}
import dream/http/status.{unauthorized}
import dream/http/transaction.{type Request, type Response, get_header}
import gleam/option.{None, Some}
import services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(token) -> verify_token(request, context, services, token, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: Services,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(token) {
    None -> text_response(unauthorized, "Invalid token")
    Some(user) -> {
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

fn validate_token(token: String) -> Option(User) {
  case token {
    "Bearer admin-token" ->
      Some(User(id: "1", email: "admin@example.com", role: "admin"))
    "Bearer user-token" ->
      Some(User(id: "2", email: "user@example.com", role: "user"))
    _ -> None
  }
}
```

**What's happening here:**

Middleware wraps controllers:

```
Request → Middleware → Controller → Middleware → Response
```

The middleware:
1. Receives the request and context
2. Checks for Authorization header
3. Validates the token
4. **Enriches context** with user info
5. Calls `next()` (the controller or next middleware)
6. Returns the response

**Why middleware?**

Authentication is a **cross-cutting concern** - multiple routes need it. Without middleware, you'd duplicate the auth check in every controller.

Middleware lets you write it once and apply to any route.

## Step 3: Use Middleware in Routes

Update `src/router.gleam`:

```gleam
import dream/http/transaction.{Delete, Get, Post}
import dream/router.{type Router, route, router}
import context.{type AuthContext}
import controllers/users_controller.{index, show, create, delete}
import middleware/auth_middleware.{auth_middleware}
import services.{type Services}

pub fn create_router() -> Router(AuthContext, Services) {
  router
  // Public route - no auth needed
  |> route(method: Get, path: "/users", controller: index, middleware: [])
  
  // Protected routes - auth required
  |> route(method: Get, path: "/users/:id", controller: show, middleware: [auth_middleware])
  |> route(method: Post, path: "/users", controller: create, middleware: [auth_middleware])
  |> route(method: Delete, path: "/users/:id", controller: delete, middleware: [auth_middleware])
}
```

Notice:
- `Router(AuthContext, Services)` - Using custom context now
- `[auth_middleware]` - Applied to protected routes
- Public route has `[]` - no middleware

## Step 4: Access User in Controller

Update `src/controllers/users_controller.gleam`:

```gleam
import dream/http/response.{json_response, text_response}
import dream/http/status.{unauthorized, bad_request, created, internal_server_error}
import dream/http/transaction.{type Request, type Response}
import dream/http/validation.{validate_json}
import context.{type AuthContext, type User}
import models/user.{decoder, create}
import services.{type Services}
import views/user_view.{to_json}

pub fn create(
  request: Request,
  context: AuthContext,
  services: Services,
) -> Response {
  case context.user {
    None -> text_response(unauthorized, "Unauthorized")
    Some(user) -> create_with_user(request, user, services)
  }
}

fn create_with_user(
  request: Request,
  user: User,
  services: Services,
) -> Response {
  case validate_json(request.body, decoder()) {
    Error(_) -> json_response(bad_request, "{\"error\": \"Invalid request data\"}")
    Ok(data) -> create_user(services, data)
  }
}

fn create_user(services: Services, data: #(String, String)) -> Response {
  let #(name, email) = data
  case create(services.db, name, email) {
    Ok(created) -> json_response(created, to_json(created))
    Error(_) -> json_response(internal_server_error, "{\"error\": \"An error occurred\"}")
  }
}
```

**What's happening:**

The middleware populated `context.user`, so the controller can check:
- `None` - Middleware didn't run or auth failed (shouldn't happen if middleware is on the route)
- `Some(user)` - User is authenticated, proceed

## Step 5: Update Main

Update `src/main.gleam`:

```gleam
import dream/servers/mist/server.{bind, context, listen, new, router, services} as server
import context.{context}
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  server.new()
  |> context(context)              // Custom context, not AppContext
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

Test it:

```bash
# Without token - fails
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@example.com"}'

# With valid token - succeeds
curl -X POST http://localhost:3000/users \
  -H "Authorization: Bearer admin-token" \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@example.com"}'
```

## How Middleware Works

When a request hits a route with `[auth_middleware]`:

```
1. Request arrives
2. Router creates empty context: AuthContext(request_id: "abc", user: None)
3. Middleware runs: Checks auth, enriches context with user
4. Controller runs with enriched context: AuthContext(..., user: Some(User))
5. Response returned
```

Middleware can:
- Modify request going in
- Enrich context going in
- Modify response coming out
- Short-circuit (return early without calling next)

## Multiple Middleware

You can chain middleware:

```gleam
route(method: Post, path: "/admin/users", controller: users_controller.create, middleware: [
  auth_middleware,
  admin_middleware,
  logging_middleware,
])
```

They run in order:
```
Request → auth → admin → logging → controller → logging → admin → auth → Response
```

Each wraps the next, creating an onion of concerns.

## What You Learned

✅ Custom context types for per-request data  
✅ Middleware wraps controllers for cross-cutting concerns  
✅ Middleware can enrich context with user info  
✅ Routes specify which middleware to apply  
✅ Context vs Services: per-request vs shared

## Next Lesson

Your API has auth, but what happens when controllers get complex? When you need to coordinate multiple services, update database + search index + send events?

Continue to [Lesson 4: Advanced Patterns](04-advanced-patterns.md) to learn the operations pattern.

---

**Working example:** See [examples/custom_context/](../../examples/custom_context/) for the complete runnable code.

