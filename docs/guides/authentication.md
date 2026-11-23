# Authentication

This guide shows how to implement authentication in Dream using custom context and middleware.

If you prefer a step-by-step walkthrough, start with [Learning Path: Adding Auth](https://github.com/TrustBound/dream/blob/main/docs/learn/03-adding-auth.md) and then return to this page as a shorter reference.

## Concept

In Dream, authentication is implemented using two core concepts:

1.  **Custom Context**: A type that holds per-request data, including the authenticated user.
2.  **Middleware**: A function that intercepts requests, verifies credentials, and enriches the context.

If you keep a session ID in a cookie, make the cookie with `cookie.secure_cookie` from `dream/http/cookie`. It sets `Secure`, `HttpOnly` and `SameSite=Strict`. In the middleware, read the value back with `cookie.get_cookie_value(request.cookies, "session_id")`, which returns an `Option(String)`.

## Step 1: Define Custom Context

Define a context type that includes an `Option(User)`.

### The AuthContext type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/authentication_guide_context.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/option.{type Option, None}

pub type User {
  User(id: String, email: String, role: String)
}

pub type AuthContext {
  AuthContext(request_id: String, user: Option(User))
}

// Default context for unauthenticated requests
pub const default_context = AuthContext(request_id: "", user: None)
```

## Step 2: Create Middleware

Create middleware that checks for an Authorization header, validates the token, and updates the context. In this example, `validate_token` looks up the token in a list in `Services`.

### The auth middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/authentication_guide_app.gleam#L18-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(tokens: List(#(String, User)))
}

pub fn auth_middleware(
  request: Request,
  context: AuthContext,
  services: Services,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case get_header(request.headers, "Authorization") {
    None -> text_response(unauthorized, "Missing Authorization header")
    Some(header) -> verify_token(request, context, services, header, next)
  }
}

fn verify_token(
  request: Request,
  context: AuthContext,
  services: Services,
  header: String,
  next: fn(Request, AuthContext, Services) -> Response,
) -> Response {
  case validate_token(services, header) {
    Error(Nil) -> text_response(unauthorized, "Invalid token")
    Ok(user) -> {
      // Enrich context with authenticated user
      let updated_context = AuthContext(..context, user: Some(user))
      next(request, updated_context, services)
    }
  }
}

// Replace with real validation logic (for example, JWT verification)
fn validate_token(services: Services, header: String) -> Result(User, Nil) {
  case header {
    "Bearer " <> token -> list.key_find(services.tokens, token)
    _ -> Error(Nil)
  }
}
```

## Step 3: Protect Routes

Apply the middleware to routes that require authentication.

### Routes with the auth middleware <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/authentication_guide_app.gleam#L59-L70"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(AuthContext, Services) {
  router()
  // Public route
  |> route(method: Get, path: "/", controller: public_index, middleware: [])
  // Protected routes
  |> route(method: Get, path: "/profile", controller: show_profile, middleware: [
    auth_middleware,
  ])
  |> route(method: Post, path: "/posts", controller: create_post, middleware: [
    auth_middleware,
  ])
}
```

## Step 4: Access User in Controller

In your controller, check `context.user` to access the authenticated user.

### The show_profile controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/authentication_guide_app.gleam#L72-L81"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_profile(
  _request: Request,
  context: AuthContext,
  _services: Services,
) -> Response {
  case context.user {
    Some(user) -> json_response(ok, user_to_json(user))
    None -> text_response(unauthorized, "Authentication required")
  }
}
```

**Note:** This example shows the pattern, but in practice, if middleware is applied to the route, `context.user` should always be `Some(user)`. The `None` case is handled defensively.

## See Also

- [Learning Path: Adding Auth](https://github.com/TrustBound/dream/blob/main/docs/learn/03-adding-auth.md) - Step-by-step tutorial
- [Context Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/architecture.md#context) - More on context
