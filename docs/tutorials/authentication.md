# Tutorial: Authentication with Custom Context

**Time:** 25 minutes  
**Prerequisites:** [Database CRUD](database-crud.md) completed  
**Example code:** `src/examples/custom_context/`

Time to build something you've definitely debugged at 2am: authentication middleware.

We're going to create custom context that tracks authenticated users, middleware that validates tokens, and authorization that checks roles. All with explicit dependency passing. No magic sessions appearing from thin air.

## What We're Building

An API with:
- **Custom context** that holds authenticated user info
- **Auth middleware** that validates tokens and populates context
- **Admin middleware** that checks user roles
- **Protected routes** that require authentication
- **Admin-only routes** that require admin role

All type-safe. All explicit.

## The Authentication Flow

1. Request arrives with `Authorization: Bearer <token>` header
2. Auth middleware intercepts it
3. Middleware validates the token
4. Middleware creates a `User` and adds it to context
5. Request flows to the next middleware/controller
6. Controller accesses user from context

No sessions in Redis. No cookies. Just simple token validation for this tutorial. You can swap in JWT, OAuth, whatever—the pattern stays the same.

## Project Structure

```
src/
  your_app/
    controllers/
      posts_controller.gleam
    middleware/
      auth_middleware.gleam
      admin_middleware.gleam
    context.gleam
    main.gleam
    router.gleam
    services.gleam
```

## Step 1: Define Custom Context

Create `src/your_app/context.gleam`:

```gleam
import gleam/option

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: option.Option(User))
}

pub const context = AuthContext(request_id: "", user: option.None)
```

Our context has two fields:
- `request_id` - For logging/tracing (you'd generate a unique ID in production)
- `user` - Either `Some(User)` if authenticated, or `None`

Middleware will populate the `user` field. Controllers can then check it.

## Step 2: Create Auth Middleware

Create `src/your_app/middleware/auth_middleware.gleam`:

```gleam
import dream/core/http/statuses.{unauthorized_status}
import dream/core/http/transaction.{
  type Request, type Response, get_header, text_response,
}
import gleam/option
import your_app/context.{type AuthContext, type User, AuthContext, User}
import your_app/services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  _services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check for Authorization header
  case get_header(request.headers, "Authorization") {
    option.None ->
      text_response(
        unauthorized_status(),
        "Unauthorized: Missing Authorization header",
      )
    option.Some(token) ->
      validate_and_authenticate(request, context, token, next)
  }
}

fn validate_and_authenticate(
  request: Request,
  context: AuthContext,
  token: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Validate token and get user
  case validate_token(token) {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Invalid token")
    option.Some(user) -> {
      // Update context with authenticated user
      let updated_context =
        AuthContext(request_id: context.request_id, user: option.Some(user))
      // Continue to next middleware/controller with updated context
      next(request, updated_context, _services)
    }
  }
}

// In production, this would check JWT, query database, etc.
fn validate_token(token: String) -> option.Option(User) {
  case token {
    "Bearer admin-token" ->
      option.Some(User(id: "1", email: "admin@example.com", role: "admin"))
    "Bearer user-token" ->
      option.Some(User(id: "2", email: "user@example.com", role: "user"))
    _ -> option.None
  }
}
```

Middleware signature: `fn(Request, Context, Services, NextHandler) -> Response`

That `next` parameter is the key. It's the next middleware or controller in the chain. We can:
- **Call it** to continue processing: `next(request, updated_context, services)`
- **Skip it** and return early: `text_response(unauthorized_status(), "Nope")`

This is how middleware chains work. Each middleware can pass control to the next, or short-circuit and return immediately.

## Step 3: Create Admin Middleware

Create `src/your_app/middleware/admin_middleware.gleam`:

```gleam
import dream/core/http/statuses.{forbidden_status, unauthorized_status}
import dream/core/http/transaction.{type Request, type Response, text_response}
import gleam/option
import your_app/context.{type AuthContext, User}
import your_app/services.{type Services}

pub fn admin_middleware(
  request: Request,
  context: AuthContext,
  _services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  // Check if user is authenticated
  case context.user {
    option.None ->
      text_response(unauthorized_status(), "Unauthorized: Not authenticated")
    option.Some(User(_id, _email, role)) -> check_role(role, request, context, next)
  }
}

fn check_role(
  role: String,
  request: Request,
  context: AuthContext,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case role {
    "admin" -> next(request, context, services)
    _ ->
      text_response(
        forbidden_status(),
        "Forbidden: Admin access required. Your role: " <> role,
      )
  }
}
```

This middleware assumes auth middleware already ran (we'll chain them in the router). It checks the `context.user` field and validates the role.

Notice: `unauthorized_status()` (401) for not authenticated, `forbidden_status()` (403) for authenticated but wrong role. HTTP semantics matter.

## Step 4: Create a Controller

Create `src/your_app/controllers/posts_controller.gleam`:

```gleam
import dream/core/http/statuses.{ok_status}
import dream/core/http/transaction.{type Request, type Response, text_response}
import gleam/option
import your_app/context.{type AuthContext}
import your_app/services.{type Services}

pub fn index(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  // This route requires authentication
  let assert option.Some(user) = context.user
  text_response(ok_status(), "Hello, " <> user.email <> "!")
}

pub fn admin_only(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  // This route requires admin role
  let assert option.Some(user) = context.user
  text_response(
    ok_status(),
    "Admin panel. Welcome, " <> user.email <> " (role: " <> user.role <> ")",
  )
}

pub fn public(
  _request: Request,
  _context: AuthContext,
  _services: Services,
) -> Response {
  text_response(ok_status(), "Public endpoint - no auth required")
}
```

See how controllers access the user from context? Middleware already validated everything. Controllers just use the data.

The `let assert option.Some(user) = context.user` will panic if user is `None`—but that's fine because the middleware guarantees it's `Some` for protected routes.

## Step 5: Wire Up the Router

Create `src/your_app/router.gleam`:

```gleam
import dream/core/http/transaction.{Get}
import dream/core/router.{type Router, route, router}
import your_app/context.{type AuthContext}
import your_app/controllers/posts_controller
import your_app/middleware/admin_middleware.{admin_middleware}
import your_app/middleware/auth_middleware.{auth_middleware}
import your_app/services.{type Services}

pub fn create_router() -> Router(AuthContext, Services) {
  router
  // Public route - no middleware
  |> route(
    method: Get,
    path: "/public",
    controller: posts_controller.public,
    middleware: [],
  )
  // Protected route - requires auth
  |> route(
    method: Get,
    path: "/posts",
    controller: posts_controller.index,
    middleware: [auth_middleware],
  )
  // Admin route - requires auth AND admin role
  |> route(
    method: Get,
    path: "/admin",
    controller: posts_controller.admin_only,
    middleware: [auth_middleware, admin_middleware],
  )
}
```

Middleware executes in the order you list them:
1. `auth_middleware` runs first (validates token, populates user)
2. `admin_middleware` runs second (checks role)
3. Controller runs last

If any middleware short-circuits (returns early), the chain stops. No controller call. Just the middleware's response.

## Step 6: Services Boilerplate

Create `src/your_app/services.gleam`:

```gleam
pub type Services {
  Services
}

pub fn initialize_services() -> Services {
  Services
}
```

We're not using any services in this example, but the router needs them.

## Step 7: Update Main

Create `src/your_app/main.gleam`:

```gleam
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import your_app/context
import your_app/router.{create_router}
import your_app/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(context.context)
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3001)
}
```

## Step 8: Test It

Run your server:

```bash
gleam run
```

Test the public endpoint (no auth):

```bash
curl http://localhost:3001/public
# Output: Public endpoint - no auth required
```

Test protected endpoint without token (401):

```bash
curl http://localhost:3001/posts
# Output: Unauthorized: Missing Authorization header
```

Test protected endpoint with valid token (200):

```bash
curl -H "Authorization: Bearer user-token" http://localhost:3001/posts
# Output: Hello, user@example.com!
```

Test admin endpoint with user token (403):

```bash
curl -H "Authorization: Bearer user-token" http://localhost:3001/admin
# Output: Forbidden: Admin access required. Your role: user
```

Test admin endpoint with admin token (200):

```bash
curl -H "Authorization: Bearer admin-token" http://localhost:3001/admin
# Output: Admin panel. Welcome, admin@example.com (role: admin)
```

## How Middleware Chaining Works

When you define a route with middleware:

```gleam
route(
  method: Get,
  path: "/admin",
  controller: posts_controller.admin_only,
  middleware: [auth_middleware, admin_middleware],
)
```

Dream builds a chain:

```
Request 
  → auth_middleware(request, context, services, |next|)
    → admin_middleware(request, updated_context, services, |next|)
      → posts_controller.admin_only(request, final_context, services)
        → Response
```

Each middleware can:
- **Continue**: Call `next(request, updated_context, services)`
- **Short-circuit**: Return `text_response(status, message)`

If `auth_middleware` returns early, `admin_middleware` never runs. If `admin_middleware` returns early, the controller never runs.

## Real-World Token Validation

In production, you'd validate tokens properly:

```gleam
import gleam/json
import gleam/http/request
import your_app/jwt  // JWT library

fn validate_token(token: String) -> option.Option(User) {
  // Remove "Bearer " prefix
  let token_value = string.replace(token, "Bearer ", "")
  
  // Verify JWT signature and decode
  case jwt.verify_and_decode(token_value, jwt_secret) {
    Ok(claims) -> {
      // Extract user from claims
      case extract_user_from_claims(claims) {
        Ok(user) -> option.Some(user)
        Error(_) -> option.None
      }
    }
    Error(_) -> option.None
  }
}
```

Or query a database:

```gleam
fn validate_token(db: pog.Connection, token: String) -> option.Option(User) {
  case sql.get_session_by_token(db, token) {
    Ok(returned) if list.length(returned.rows) > 0 -> {
      let assert [session] = returned.rows
      option.Some(User(
        id: session.user_id,
        email: session.email,
        role: session.role,
      ))
    }
    _ -> option.None
  }
}
```

The pattern stays the same. Just swap out `validate_token()`.

## Multiple Authentication Strategies

Want to support multiple auth methods? Chain them:

```gleam
pub fn auth_middleware(request, context, services, next) {
  // Try JWT first
  case validate_jwt(request) {
    option.Some(user) -> next(request, update_context(context, user), services)
    option.None -> {
      // Try API key
      case validate_api_key(request) {
        option.Some(user) -> next(request, update_context(context, user), services)
        option.None -> {
          // Try session cookie
          case validate_session(request, services) {
            option.Some(user) -> next(request, update_context(context, user), services)
            option.None -> text_response(unauthorized_status(), "Unauthorized")
          }
        }
      }
    }
  }
}
```

## Common Patterns

### Optional Authentication

Some routes work better with auth, but don't require it:

```gleam
pub fn optional_auth_middleware(request, context, services, next) {
  case get_header(request.headers, "Authorization") {
    option.None -> next(request, context, services)  // Continue without user
    option.Some(token) -> {
      case validate_token(token) {
        option.None -> next(request, context, services)  // Invalid token, continue anyway
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

Then your controller checks:

```gleam
pub fn index(request, context, services) {
  case context.user {
    option.Some(user) -> text_response(ok_status(), "Hello, " <> user.email)
    option.None -> text_response(ok_status(), "Hello, guest!")
  }
}
```

### Permission-Based Authorization

Instead of role strings, use proper permission types:

```gleam
pub type Permission {
  ReadPosts
  WritePosts
  DeletePosts
  ManageUsers
}

pub type User {
  User(id: String, email: String, permissions: List(Permission))
}

pub fn require_permission(permission: Permission) {
  fn(request, context, services, next) {
    case context.user {
      option.None -> text_response(unauthorized_status(), "Unauthorized")
      option.Some(user) -> {
        case list.contains(user.permissions, permission) {
          True -> next(request, context, services)
          False -> text_response(forbidden_status(), "Insufficient permissions")
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
  method: Delete,
  path: "/posts/:id",
  controller: posts_controller.delete,
  middleware: [auth_middleware, require_permission(DeletePosts)],
)
```

### Rate Limiting

Middleware can do more than auth:

```gleam
pub fn rate_limit_middleware(request, context, services, next) {
  let ip = get_client_ip(request)
  let requests = get_request_count(services.cache, ip)
  
  case requests > 100 {
    True -> text_response(too_many_requests_status(), "Rate limit exceeded")
    False -> {
      increment_request_count(services.cache, ip)
      next(request, context, services)
    }
  }
}
```

## What's Next?

You've learned:
- ✅ How to create custom context types
- ✅ How to write authentication middleware
- ✅ How to chain multiple middleware
- ✅ How to pass context through the request pipeline
- ✅ How to access user data in controllers

**Ready for more?**

- [Tutorial: HTTP Client](http-client.md) - Making external requests
- [Guide: Middleware](../guides/middleware.md) - Deep dive into middleware patterns
- [Guide: Testing](../guides/testing.md) - Testing middleware and controllers

**Want to see the full example?**

Check out `src/examples/custom_context/` in the Dream repository for complete working code with more advanced patterns.

---

**[← Back: Database CRUD](database-crud.md)** | **[Up: Documentation](../../README.md)** | **[Next: HTTP Client →](http-client.md)**

