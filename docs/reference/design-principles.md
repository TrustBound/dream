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

**Bad (implicit):**

```gleam
pub fn main() {
  Framework.start()  // What does this do? Who knows!
}
```

**Good (explicit):**

```gleam
pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

Everything your app does is right there. No hidden configuration. No magic.

### 3. No Closures

Closures hide dependencies. Explicit parameters make them visible.

**Bad (closure):**

```gleam
pub fn make_controller(db: Database) -> fn(Request) -> Response {
  fn(request) {
    // db is captured - not obvious from signature
    query_database(db, request.params)
  }
}
```

**Good (explicit):**

```gleam
pub fn controller(request: Request, context: Context, services: Services) -> Response {
  let db = services.database  // Dependency explicit
  query_database(db, request.params)
}
```

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

```gleam
route(
  method: Get,
  path: "/admin",
  controller: admin_controller,
  middleware: [auth, admin_check],
)
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

```gleam
thing.new() |> configure(...) |> configure(...) |> finalize()
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

We use Squirrel to generate type-safe SQL functions. You write SQL. Squirrel makes it type-safe.

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

**[← Back: Documentation](../../README.md)** | **[Next: Architecture Reference →](architecture.md)**

