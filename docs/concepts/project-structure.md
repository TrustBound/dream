# Project Structure

**How to organize a real Dream application.**

Here's a complete Dream app structure with models, views, controllers, and more:

```
your_app/
├── src/
│   ├── main.gleam          # Application entry point
│   ├── router.gleam        # Route definitions
│   ├── services.gleam      # Shared dependencies (database, cache, etc.)
│   ├── context.gleam       # Per-request context types
│   ├── config.gleam        # Configuration loading
│   │
│   ├── controllers/        # Request handlers
│   │   ├── users_controller.gleam
│   │   └── tasks_controller.gleam
│   │
│   ├── middleware/         # Cross-cutting concerns
│   │   └── logging_middleware.gleam
│   │
│   ├── models/             # Data access layer
│   │   ├── user/
│   │   │   ├── user_model.gleam
│   │   │   └── sql.gleam   # Squirrel-generated SQL queries
│   │   └── task/
│   │       ├── task_model.gleam
│   │       └── sql.gleam
│   │
│   ├── views/              # Response formatting
│   │   ├── user_view.gleam
│   │   └── task_view.gleam
│   │
│   ├── operations/         # Complex business logic
│   │   └── reorder_tasks.gleam
│   │
│   ├── templates/          # HTML templates (optional)
│   │   ├── components/     # Reusable UI components
│   │   ├── elements/        # Low-level HTML elements
│   │   ├── layouts/        # Page layouts (nav, footer)
│   │   └── pages/          # Full page templates
│   │
│   ├── services/           # Service initialization
│   │   └── database.gleam
│   │
│   └── types/              # Domain types
│       └── user.gleam
│
└── gleam.toml
```

## What Goes Where?

### `main.gleam`
Sets up the server, initializes services, creates the router, and starts listening.

### `router.gleam`
Defines all routes: which paths map to which controllers, and what middleware to run.

### `controllers/`
Functions that handle HTTP requests. They extract parameters, call models/operations, call views, and return responses.

### `models/`
Data access functions. They take a database connection, run queries, and return domain types.

### `views/`
Formatting functions. They take domain types and return strings (JSON, HTML, CSV, etc.).

### `operations/`
Complex business logic that coordinates multiple models or services. Testable without HTTP.

### `middleware/`
Cross-cutting concerns like authentication, logging, rate limiting.

### `templates/`
HTML templates for server-side rendering. Optional—use if you want SSR.

### `services/`
Initialization of shared dependencies (database connections, HTTP clients, caches).

### `types/`
Domain types that represent your business entities.

## This is a Suggestion, Not a Requirement

Dream doesn't enforce this structure. You can:
- Put everything in one file (see `examples/simplest/`)
- Organize however makes sense for your project
- Skip patterns you don't need (no database? Skip models)

But this structure works. We use it in production. It scales.

## Examples

- **Simplest**: `examples/simplest/` - Everything in one file
- **Simple**: `examples/simple/` - Basic routing and HTTP client
- **Full App**: `examples/tasks/` - Complete structure with database, templates, operations

## Next Steps

- Components - Learn about controllers, models, views
- [Concepts Overview](../concepts.md) - All Dream concepts explained
- [Examples](../examples.md) - See real project structures

