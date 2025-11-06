# Simple Example

The simplest possible Dream app. Demonstrates basic routing, path parameters, and HTTP client usage.

## What This Demonstrates

- **Basic routing** - Simple GET routes
- **Path parameters** - Extracting `:id` and `:post_id` from URLs
- **HTTP client** - Making HTTPS requests to external APIs
- **Clean controller pattern** - Simple request handlers

## Running the Example

```bash
cd examples/simple
make run
```

Server starts on `http://localhost:3000`

## Endpoints

- `GET /` - Returns "Hello, World!"
- `GET /users/:id/posts/:post_id` - Demonstrates path parameters and makes an HTTPS request to jsonplaceholder.typicode.com

## Example Usage

```bash
# Simple hello world
curl http://localhost:3000/

# Path parameters with external API call
curl http://localhost:3000/users/1/posts/2
```

## Code Structure

```
examples/simple/
├── gleam.toml          # Project config with dream dependency
├── Makefile            # Build and run commands
└── src/
    ├── main.gleam     # Application entry point
    ├── router.gleam   # Route definitions
    ├── services.gleam # Empty services (no database needed)
    └── controllers/
        └── posts_controller.gleam  # Request handlers
```

## Key Concepts

- **Routes** - Defined using `route()` function calls
- **Path Parameters** - Extracted using `get_param(request, "id")`
- **HTTP Client** - Uses Dream's HTTP client builder pattern
- **Controllers** - Simple functions that take `Request`, `Context`, and `Services`

This is the perfect starting point for understanding Dream's core concepts.

