# Design Principles

**The "why" behind Dream's decisions. For when you wonder if we've lost our minds.**

Dream is intentionally designed to be simple, explicit, and composable. These principles guide every decision.

## Core Philosophy

### 1. Library, Not Framework

Dream is **not a framework**. Frameworks make decisions for you. Libraries provide tools.

**Frameworks say:** "Do it our way."  
**Dream says:** "Here are the pieces. Compose them however you want."

You're not locked into Dream's choices. Use the router with your own server. Use our HTTP client without the router. Mix and match.

### 2. Explicit Over Implicit

If something happens, it should be visible in your code.

#### Bad: a start helper hides the configuration <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_implicit.gleam#L15-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  start()
}

pub fn start() {
  let assert Ok(Nil) =
    configure_server()
    |> server.listen(8080)
}

pub fn configure_server() {
  server.new()
  |> server.services(Services(database_url: "postgres://localhost/app"))
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: show_home, middleware: []),
  )
  |> server.bind("0.0.0.0")
}
```

`main` only calls `start()`. To find the port, the bind address, the services and the routes, you must read `start` and then `configure_server`.

#### Good: main shows the configuration <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_explicit.gleam#L14-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.services(initialize_services())
    |> server.router(create_router())
    |> server.bind("localhost")
    |> server.listen(3000)
}
```

Everything your app does is right there. No hidden configuration.

### 3. No Closures

Closures hide dependencies. Explicit parameters make them visible.

#### Bad: the controller captures the database <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_closures.gleam#L22-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_controller(
  database: Database,
) -> fn(Request, EmptyContext, EmptyServices) -> Response {
  fn(request, _context, _services) {
    // database is captured: the controller's type does not show it
    show_user_name(database, request)
  }
}
```

The returned controller uses `database`, but its type, `fn(Request, EmptyContext, EmptyServices) -> Response`, does not show it.

#### Good: the database comes from Services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_closures.gleam#L31-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn controller(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let database = services.database
  show_user_name(database, request)
}
```

The signature shows that the controller reads `services`, and a test can pass in any database.

Future you will thank present you.

### 4. Type Safety First

Leverage Gleam's type system. Make invalid states unrepresentable.

**Types catch errors at compile time:**
- Wrong parameter type? Compiler error.
- Missing field? Compiler error.
- Wrong return type? Compiler error.

Runtime errors are expensive. Compile-time errors are cheap.

### 5. Composability

Small, focused pieces that work together.

- **Routers** are composable
- **Middleware** chains
- **Controllers** are just functions
- **Services** are pluggable

No base classes. No inheritance. Just functions and data.

## Architectural Decisions

### The Three-Layer Pattern

**Controllers** (HTTP) → **Models** (Data) → **Utilities** (Helpers)

This separation keeps each layer focused. Controllers don't know about database schemas. Models don't know about HTTP status codes.

**Why?** Because mixing concerns makes everything harder to test, understand, and change.

### Services Pattern (Pragmatic Tradeoff)

Services is a "god object" that holds dependencies. We know this violates single responsibility. We accept it anyway.

**Why?** Because web apps evolve fast. Adding a new cross-cutting concern (logging, caching, metrics) shouldn't require updating 50 function signatures.

**The tradeoff:**
- ✅ Easy to add new services
- ✅ Consistent controller signatures
- ❌ Controllers can access services they don't use
- ❌ Dependencies not explicit in signatures

We chose developer velocity over perfect explicitness. But we keep Services small (only common infrastructure).

### Middleware Execution Model

Middleware chains explicitly per route:

#### Middleware listed on the route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_middleware.gleam#L72-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(Context, Services) {
  router()
  |> route(
    method: Get,
    path: "/admin",
    controller: show_admin_page,
    middleware: [require_user, require_admin],
  )
}
```

No global middleware. No hidden processing.

**Why?** Because finding which middleware runs on which route shouldn't require reading the entire codebase.

**Tradeoff:** More verbose. But explicit is worth it.

### Result-Based Error Handling

Functions return `Result(success, error)`. No exceptions for control flow.

**Why?**
- Errors are values you can inspect
- Type system forces you to handle errors
- No hidden control flow paths

Exceptions are for exceptional circumstances (out of memory, etc.). Business logic errors are `Result` types.

### Builder Pattern Everywhere

Server, router, HTTP client—all use the builder pattern:

#### Configure the server step by step <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/design_principles_builder.gleam#L15-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn configure_server() {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: show_home, middleware: []),
  )
  |> server.bind("localhost")
  |> server.max_body_size(1_000_000)
}

pub fn main() {
  let assert Ok(Nil) =
    configure_server()
    |> server.listen(3000)
}
```

**Why?**
- Consistent API across components
- Fluent, readable configuration
- Type-safe at each step
- No global state

### Context vs Services Split

- **Context** - Per-request, mutable (user, request ID, session)
- **Services** - Application-level, immutable (database, config, clients)

**Why separate?** It makes the distinction clear. Context changes per request. Services are shared across all requests.

## What We Don't Do

### No Magic Configuration

You won't find YAML files that magically configure routes. You won't find decorators that register handlers. You write code that explicitly wires things up.

**Why?** Magic configuration looks nice in demos. It's hell to debug in production.

### No ORM

We use `dream_sql_generator` to generate type-safe SQL functions. You write SQL. `dream_sql_generator` makes it type-safe.

**Why no ORM?** ORMs abstract SQL until they don't. Then you're debugging query generation at 2am. Just write SQL.

### No Active Record

Models return `Result` types, not `Response` types. Controllers handle HTTP. Models handle data.

**Why?** Mixing HTTP and data concerns makes everything harder to test and understand.

### No Global State

Everything is passed explicitly. No global connection pool variable. No global config object.

**Why?** Global state is invisible dependencies. Invisible dependencies make testing hard.

## Design Tradeoffs We Accept

### Services "God Object"

**Accept:** Services contains multiple dependencies  
**Get:** Velocity - easy to add cross-cutting concerns  
**Mitigate:** Keep Services small, only common infrastructure

### Per-Route Middleware (Verbose)

**Accept:** More verbose than global middleware  
**Get:** Explicitness - see exactly what runs  
**Mitigate:** Helper functions for common middleware sets

### No Framework "Magic"

**Accept:** You wire things up manually  
**Get:** Explicit composition, no hidden behavior  
**Mitigate:** Examples show common patterns

## Success Criteria

When these principles are followed:

- ✅ New developers understand the codebase quickly
- ✅ Tests are easy to write
- ✅ Refactoring is safe
- ✅ Bugs are caught at compile time
- ✅ Dependencies are visible
- ✅ No hidden behavior

## Anti-Patterns We Avoid

**Framework lock-in:** You're never trapped by Dream's choices. Everything is pluggable.

**Clever code:** Simple is better than clever. Boring is better than surprising.

**Premature abstraction:** Solve the problem at hand. Abstract when you have three examples, not one.

**Hidden dependencies:** If a function needs something, it's in the signature.

## Summary

Dream's principles:
- **Library over framework** - Provide pieces, not opinions
- **Explicit over implicit** - Show what's happening
- **No closures** - Dependencies visible
- **Type safety** - Catch errors early
- **Composability** - Small pieces that fit together
- **Pragmatic tradeoffs** - Velocity matters

These aren't rules. They're guidelines. Break them when you have a good reason.

---

**See Also:**
- [Architecture Reference](architecture.md) - How Dream is structured
- [Dream vs Mist](dream-vs-mist.md) - What Dream provides

