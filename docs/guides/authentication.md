# Authentication

This guide shows how to implement authentication in Dream using custom context and middleware.

## Concept

In Dream, authentication is implemented using two core concepts:

1.  **Custom Context**: A type that holds per-request data, including the authenticated user.
2.  **Middleware**: A function that intercepts requests, verifies credentials, and enriches the context.

## Step 1: Define Custom Context

Define a context type that includes an `Option(User)`.

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

// Default context for unauthenticated requests
pub const context = AuthContext(request_id: "", user: None)
```

## Step 2: Create Middleware

Create middleware that checks for an Authorization header, validates the token, and updates the context.

```gleam
import context.{type AuthContext, type User, AuthContext}
import dream/http.{type Request, type Response, text_response, unauthorized, get_header}
import gleam/option.{None, Some}
import services.{type Services}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  let auth_header = get_header(request.headers, "Authorization")
  
  case auth_header {
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
      // Enrich context with authenticated user
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

// Replace with real validation logic (e.g., JWT verification)
fn validate_token(token: String) -> Option(User) {
  // ...
  None
}
```

## Step 3: Protect Routes

Apply the middleware to routes that require authentication.

```gleam
import dream/router.{type Router, route, router}
import dream/http/request.{Get, Post}
import middleware/auth_middleware.{auth_middleware}

pub fn create_router() -> Router(AuthContext, Services) {
  router()
  // Public route
  |> route(method: Get, path: "/", controller: public_index, middleware: [])
  
  // Protected routes
  |> route(method: Get, path: "/profile", controller: show_profile, middleware: [auth_middleware])
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [auth_middleware])
}
```

## Step 4: Access User in Controller

In your controller, check `context.user` to access the authenticated user.

```gleam
import dream/http.{type Request, type Response, json_response, ok}
import dream/http/error.{type Error, Unauthorized}
import context.{type AuthContext}
import gleam/option
import gleam/result
import utilities/response_helpers

pub fn show_profile(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  let result = {
    use user <- result.try(
      case context.user {
        option.Some(u) -> Ok(u)
        option.None -> Error(error.Unauthorized("Authentication required"))
      }
    )
    Ok(user)
  }
  
  case result {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

**Note:** This example shows the pattern, but in practice, if middleware is applied to the route, `context.user` should always be `Some(user)`. The `None` case is handled defensively.

## See Also

- [Learning Path: Adding Auth](../learn/03-adding-auth.md) - Step-by-step tutorial
- [Context Reference](../reference/architecture.md#context) - More on context
