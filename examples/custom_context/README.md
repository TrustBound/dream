# Custom Context Example

Authentication and authorization with custom context types and middleware.

## What This Demonstrates

- **Custom context type** - `AuthContext` with user information
- **Authentication middleware** - Validates Bearer tokens
- **Authorization middleware** - Checks user roles (admin vs regular user)
- **Middleware chaining** - Multiple middleware functions on a single route
- **Context propagation** - Custom context flows through request pipeline

## Running the Example

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/custom_context
make run
```

Server starts on `http://localhost:3001`

## Endpoints

- `GET /` - Public endpoint (no authentication required)
- `GET /users/:id/posts/:post_id` - Protected endpoint (requires authentication)
- `GET /admin` - Admin-only endpoint (requires admin role)

## Authentication

The example uses simple Bearer token authentication:

- **Regular user token**: `Bearer user-token`
- **Admin token**: `Bearer admin-token`

## Example Usage

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/custom_context/test/integration/readme.sh#L4-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Public endpoint (no auth needed)
curl http://localhost:3001/

# Protected endpoint (needs token)
curl -H "Authorization: Bearer user-token" \
  http://localhost:3001/users/1/posts/2

# Admin endpoint (needs admin token)
curl -H "Authorization: Bearer admin-token" \
  http://localhost:3001/admin

# Try without token (will get 401 Unauthorized)
curl http://localhost:3001/users/1/posts/2

# Try regular user on admin endpoint (will get 403 Forbidden)
curl -H "Authorization: Bearer user-token" \
  http://localhost:3001/admin
```

## Code Structure

```text illustration
examples/custom_context/
├── gleam.toml          # Project config
├── Makefile            # Build and run commands
└── src/
    ├── main.gleam     # Application entry point
    ├── router.gleam   # Route definitions with middleware
    ├── context.gleam  # AuthContext type definition
    ├── services.gleam  # Service initialization
    ├── controllers/
    │   └── posts_controller.gleam
    └── middleware/
        ├── auth_middleware.gleam      # Token validation
        └── admin_middleware.gleam     # Role checking
```

## Key Concepts

- **Custom Context** - Extending the base `AppContext` with user information
- **Middleware** - Functions that transform context before controllers run
- **Middleware Chaining** - Applying multiple middleware in sequence
- **Error Responses** - Returning 401/403 from middleware when auth fails

## How It Works

1. **Auth Middleware** - Validates the Bearer token and extracts user info
2. **Admin Middleware** - Checks if the user has admin role
3. **Context Transformation** - Each middleware can modify the context
4. **Controller Access** - Controllers receive the transformed context

This example demonstrates how to build authentication and authorization in Dream using middleware and custom context types.

