# Tutorial: Basic Routing

**Time:** 15 minutes  
**Prerequisites:** [Getting Started](../getting-started.md) completed  
**Example code:** `src/examples/simple/`

You know how some frameworks have you configuring routes in YAML, or decorating functions with magical annotations? We don't do that here.

Routes in Dream are just function calls. Let's build something real.

## What We're Building

A simple API with:
- A root endpoint that returns "Hello, World!"
- A parameterized endpoint `/users/:id/posts/:post_id`
- Path parameter extraction
- A bonus: making an external HTTPS request

All in about 50 lines of code. With every import shown. Because we're not hiding anything.

## Project Structure

```
src/
  your_app/
    controllers/
      posts_controller.gleam
    main.gleam
    router.gleam
    services.gleam
```

## Step 1: The Main Entry Point

Create `src/your_app/main.gleam`:

```gleam
import dream/core/context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import your_app/router.{create_router}
import your_app/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

Nothing fancy. Just wiring up the pieces. Everything explicit.

## Step 2: The Router

Create `src/your_app/router.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import your_app/controllers/posts_controller

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
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
    middleware: [],
  )
}
```

See those `:id` and `:post_id` bits? That's how you define path parameters. Dream will extract them and make them available in your controller.

The `route()` function takes:
- `method` - HTTP method (Get, Post, Put, Delete, Patch)
- `path` - URL path with optional parameters (`:param_name`)
- `controller` - Function to handle the request
- `middleware` - List of middleware (we'll cover this in another tutorial)

## Step 3: Empty Services (For Now)

Create `src/your_app/services.gleam`:

```gleam
import dream/core/router.{type EmptyServices, EmptyServices}

pub fn initialize_services() -> EmptyServices {
  EmptyServices
}
```

We don't need services yet. When you add a database or external API clients, they'll go here.

## Step 4: The Controller

Create `src/your_app/controllers/posts_controller.gleam`:

```gleam
import dream/core/context.{type AppContext}
import dream/core/http/statuses.{internal_server_error_status, ok_status}
import dream/core/http/transaction.{
  type Request, type Response, get_param, text_response,
}
import dream/core/router.{type EmptyServices}
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import gleam/http

pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  text_response(ok_status(), "Hello, World!")
}

pub fn show(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  // Extract path parameters
  let assert Ok(user_id) = get_param(request, "id")
  let assert Ok(post_id) = get_param(request, "post_id")

  // Make an HTTPS request (because why not)
  let req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Https)
    |> client.host("jsonplaceholder.typicode.com")
    |> client.path("/posts")
    |> client.add_header("User-Agent", "Dream-Tutorial")

  case fetch_module.request(req) {
    Ok(body) ->
      text_response(
        ok_status(),
        "User: "
          <> user_id
          <> ", Post: "
          <> post_id
          <> "\n\nHTTPS Response:\n\n"
          <> body,
      )
    Error(error) ->
      text_response(internal_server_error_status(), "Error: " <> error)
  }
}
```

Let's break down what's happening:

### The `index` Function

Dead simple. Returns "Hello, World!". 

Notice the signature: `fn(Request, AppContext, EmptyServices) -> Response`

That's what every controller looks like. No magic base class. No inheritance. Just a function.

### The `show` Function

More interesting. It:

1. **Extracts path parameters** using `get_param(request, "id")`
2. **Builds an HTTP client** using the builder pattern
3. **Makes an HTTPS request** to an external API
4. **Returns a response** with the data

See that `let assert Ok(...)` pattern? In production, you'd want proper error handling. But for a tutorial, we're being pragmatic. The request will only match this route if the path has those parameters, so they'll be there.

## Step 5: Run It

```bash
gleam run
```

Now test your routes:

```bash
# Root endpoint
curl http://localhost:3000/
# Output: Hello, World!

# Parameterized endpoint
curl http://localhost:3000/users/42/posts/123
# Output: User: 42, Post: 123
# 
# HTTPS Response:
# 
# [... JSON data from jsonplaceholder.typicode.com ...]
```

## How Path Parameters Work

When you define a route like `/users/:id/posts/:post_id`, Dream:

1. Compiles it into a pattern
2. Matches incoming requests against that pattern
3. Extracts the values where `:id` and `:post_id` appear
4. Makes them available via `get_param(request, "id")`

Want to extract a parameter? Use the name without the colon:

```gleam
// Route: "/users/:user_id"
let assert Ok(user_id) = get_param(request, "user_id")

// Route: "/products/:category/:id"
let assert Ok(category) = get_param(request, "category")
let assert Ok(product_id) = get_param(request, "id")
```

Simple. Explicit. No surprises.

## HTTP Methods

We've only used `Get` so far. Dream supports all the standard HTTP methods:

```gleam
import dream/core/http/transaction.{Get, Post, Put, Delete, Patch}
import dream/core/router.{route, router}

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(method: Get, path: "/users", controller: users.index, middleware: [])
  |> route(method: Post, path: "/users", controller: users.create, middleware: [])
  |> route(method: Get, path: "/users/:id", controller: users.show, middleware: [])
  |> route(method: Put, path: "/users/:id", controller: users.update, middleware: [])
  |> route(method: Delete, path: "/users/:id", controller: users.delete, middleware: [])
}
```

Same path, different methods. REST at its finest.

## Building Responses

We've been using `text_response()`. There are others:

```gleam
import dream/core/http/statuses.{
  ok_status, 
  created_status, 
  not_found_status,
  bad_request_status,
  internal_server_error_status,
}
import dream/core/http/transaction.{
  json_response,
  text_response,
  html_response,
  empty_response,
}

// Text response
text_response(ok_status(), "Plain text")

// JSON response
json_response(ok_status(), "{\"message\": \"Hello\"}")

// HTML response
html_response(ok_status(), "<h1>Hello</h1>")

// Empty response (for DELETE, etc.)
empty_response(ok_status())

// Custom status codes
text_response(not_found_status(), "Not found")
text_response(created_status(), "{\"id\": 42}")
```

Each status function returns a `Status` type with the appropriate code, message, and description. The response function combines the status and body.

## The HTTP Client Bonus

Notice we made an HTTPS request right from our controller? Dream includes an HTTP client with a builder pattern:

```gleam
import dream/utilities/http/client
import dream/utilities/http/client/fetch as fetch_module
import gleam/http

let request =
  client.new
  |> client.method(http.Get)
  |> client.scheme(http.Https)
  |> client.host("api.example.com")
  |> client.port(443)
  |> client.path("/api/v1/users")
  |> client.query("page=1&limit=10")
  |> client.add_header("Authorization", "Bearer token")
  |> client.add_header("Accept", "application/json")

case fetch_module.request(request) {
  Ok(body) -> // Handle response
  Error(error) -> // Handle error
}
```

Same builder pattern you've seen everywhere else. Consistent API. No surprises.

## Common Patterns

### Multiple Parameters

```gleam
// Route: "/api/:version/users/:user_id/posts/:post_id"
let assert Ok(version) = get_param(request, "version")
let assert Ok(user_id) = get_param(request, "user_id")
let assert Ok(post_id) = get_param(request, "post_id")
```

### Optional Query Parameters

Path parameters are required. Query parameters are optional:

```gleam
import dream/utilities/http/query.{get_query_param}

// URL: /search?q=gleam&page=2
let query = get_query_param(request, "q")        // Option(String)
let page = get_query_param(request, "page")      // Option(String)
```

### Parameter Validation

Path parameters are strings. Convert them as needed:

```gleam
import gleam/int
import gleam/result

let assert Ok(id_str) = get_param(request, "id")
let id = int.parse(id_str) |> result.unwrap(0)  // Default to 0 if invalid

// Or handle errors properly:
case int.parse(id_str) {
  Ok(id) -> // Use the valid ID
  Error(_) -> text_response(bad_request_status(), "Invalid ID")
}
```

## What's Next?

You've learned:
- ✅ How to define routes with the builder pattern
- ✅ How to extract path parameters
- ✅ How to handle different HTTP methods
- ✅ How to build responses
- ✅ How to make external HTTP requests

**Ready for more?**

- [Tutorial: Database CRUD](database-crud.md) - Real database operations
- [Tutorial: Authentication](authentication.md) - Custom context and middleware
- [Guide: Controllers and Models](../guides/controllers-and-models.md) - Architecture patterns

**Want to see the full example?**

Check out `src/examples/simple/` in the Dream repository. It's the complete working code for everything in this tutorial.

---

**[← Back: Getting Started](../getting-started.md)** | **[Up: Documentation](../../README.md)** | **[Next: Database CRUD →](database-crud.md)**

