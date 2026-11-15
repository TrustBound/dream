# Lesson 3: Adding Auth

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

### The AuthContext type <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/learn_adding_auth_context.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/option.{type Option, None}

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

pub const context = AuthContext(request_id: "", user: None)
```

**What changed:**

In Lesson 1, you used `EmptyContext` (Dream's default, which holds no data). In Lesson 2, `DatabaseContext` held only a request ID.

Now you have `AuthContext` with:
- `request_id` - For tracking requests
- `user` - Added for authenticated user info

This is **per-request data** - it changes for each request. The user making request A is different from request B.

**Context vs Services:**

- **Context** = per-request (user, session) - changes every request
- **Services** = shared (database, cache) - same for all requests

## Step 2: Create Auth Middleware

Create `src/middleware/auth_middleware.gleam`:

### The auth middleware <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/learn_adding_auth_middleware.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{
  type Request, type Response, get_header, text_response, unauthorized,
}
import gleam/option.{type Option, None, Some}
import snippets/learn_adding_auth_context.{
  type AuthContext, type User, AuthContext, User,
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: services,
  next: fn(Request, AuthContext, services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(token) -> verify_token(request, context, services, token, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: services,
  token: String,
  next: fn(Request, AuthContext, services) -> Response,
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

The tested snippet imports the context from `snippets/learn_adding_auth_context`.
In your app, import it from the `context` module. The middleware does not
use `services`, so its type is the type variable `services`: the middleware
works with any services type.

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

From this step on, the lesson uses the app in
[examples/custom_context](https://github.com/TrustBound/dream/tree/2.5.0/examples/custom_context/src).
Its `context.gleam` and `auth_middleware.gleam` are almost the same as
the files from Steps 1 and 2. Its middleware uses the app's own
`Services` type in place of the type variable `services`. The app has
no database, so its routes are not the users routes from Lesson 2. To
protect your users API, put `[auth_middleware]` on the users routes
that change data in the same way.

Update `src/router.gleam`:

### Routes with and without middleware <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/custom_context/src/router.gleam#L1-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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

Notice:
- `Router(AuthContext, Services)` - Using custom context now
- `[auth_middleware]` - Applied to the protected route
- `[auth_middleware, admin_middleware]` - Two middleware on the admin route
- Public route has `[]` - no middleware

## Step 4: Read the User from Context

After `auth_middleware` runs, `context.user` holds the authenticated
user. The next middleware or the controller reads it from there. The
example's `src/middleware/admin_middleware.gleam` reads the user's
role:

### Reading the user from context <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/custom_context/src/middleware/admin_middleware.gleam#L13-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check user role from context (auth_middleware should have populated this)
  case context.user {
    option.None ->
      text_response(status.unauthorized, "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) ->
      check_role(role, request, context, services, next)
  }
}
```

**What's happening:**

1. `auth_middleware` ran first, and put the user into the context.
2. If `context.user` is `None`, the request has no authenticated user,
   so the middleware returns `401 Unauthorized`.
3. If `context.user` is `Some(User(...))`, the middleware takes the
   role from it, and `check_role` lets only the `admin` role through.
   Other roles get `403 Forbidden`.

A controller reads `context.user` in the same way, with a `case` on
the `Option`.

## Step 5: Update Main

Update `src/main.gleam`:

### Main with a custom context <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/custom_context/src/main.gleam#L3-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import context as app_context
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import gleam/io
import gleam/option
import router as app_router
import services as app_services

pub fn main() {
  // Initialize services
  let app_services = app_services.initialize_services()

  // Start the server
  dream.new()
  |> context(app_context.AuthContext(request_id: "", user: option.None))
  |> services(app_services)
  |> router(app_router.create_router())
  |> bind("localhost")
  |> listen(3001)

  io.println("Custom context example server listening on http://localhost:3001")
  io.println("Try:")
  io.println("  GET /                          - Public endpoint")
  io.println(
    "  GET /users/1/posts/2           - Requires auth (Bearer user-token)",
  )
  io.println(
    "  GET /admin                     - Requires admin (Bearer admin-token)",
  )
}
```

`context(...)` gives the server the starting context for each request:
no request ID and no user. The module `context.gleam` also defines
this value as the constant `context`.

Test it:

```bash
# Public route - succeeds
curl http://localhost:3001/

# Without token - fails with 401
curl http://localhost:3001/users/1/posts/2

# With valid token - succeeds
curl http://localhost:3001/users/1/posts/2 \
  -H "Authorization: Bearer user-token"

# User token on the admin route - fails with 403
curl http://localhost:3001/admin \
  -H "Authorization: Bearer user-token"

# Admin token on the admin route - succeeds
curl http://localhost:3001/admin \
  -H "Authorization: Bearer admin-token"
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

You can chain middleware. The example's admin route uses two:

### Two middleware on one route <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/custom_context/src/router.gleam#L23-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  |> route(
    method: Get,
    path: "/admin",
    controller: posts_controller.index,
    middleware: [auth_middleware, admin_middleware],
  )
```

They run in order:
```
Request → auth → admin → controller → admin → auth → Response
```

`admin_middleware` needs the user that `auth_middleware` put into the
context, so `auth_middleware` must come first.

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

