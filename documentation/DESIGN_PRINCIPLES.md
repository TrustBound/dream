# Dream Framework Design Principles

## Status Note

**This document describes Dream's design philosophy and architectural vision.** Some patterns described here (such as the Services pattern, protocol-based routers, and config loading) represent future direction and are not yet fully implemented in the current codebase.

**Current Implementation Status:**
- ✅ Builder patterns for server, router, and HTTP client
- ✅ Mist HTTP server adapter
- ✅ HTTP client with streaming and non-streaming support
- ✅ Path parameter extraction
- ✅ Type-safe request/response handling
- ✅ Middleware chaining with full execution support
- ✅ Generic context system for type-safe request context
- ✅ Default AppContext with request_id
- ✅ Services pattern (implemented)
- ⏳ Protocol-based component swapping (planned)
- ⏳ Config loading from environment (planned)

This document serves as the architectural north star for all design decisions in the framework, guiding both current implementation and future development.

## Core Philosophy

### 1. Functional Architecture with Pragmatic Constraints

**Principle**: Embrace functional programming while acknowledging the reality of side effects in web applications.

- **Pure Business Logic**: Core business logic functions should be pure and deterministic
- **Isolated Side Effects**: Side effects (DB, HTTP, logging) are isolated to service boundaries
- **No Closures**: All functions use explicit parameter passing - no closures allowed
  - Rationale: Makes dependencies explicit, improves testability, prevents hidden state
- **Immutability by Default**: Data structures are immutable; transformations create new values
- **Thread-Safe by Design**: Leveraging BEAM processes and immutability for safe concurrency

**Why**: Pure functions are easier to test, reason about, and refactor. Explicit dependencies make the codebase maintainable as it scales.

### 2. Pragmatic Dependency Injection

**Principle**: Dependencies are injected explicitly, with pragmatic tradeoffs for developer velocity.

- **Services Parameter Pattern**: Controllers and middleware receive `Request`, `Context`, and `Services` as separate parameters
  - `Request` is immutable and contains only HTTP data (headers, body, method, etc.)
  - `Context` is mutable by middleware and represents per-request state
  - `Services` is immutable and contains shared application state (database, logging, etc.)
  - This separation makes dependencies explicit and enables type-safe middleware
  - Enables rapid iteration and easy addition of cross-cutting concerns
  - Prevents massive refactors when service requirements evolve
- **Services Contains Common Dependencies**: Database, logging, auth, cache, configuration
  - Services that most routes/controllers need
  - Infrastructure-level concerns, not business logic
- **Explicit Parameters for Specialized Dependencies**: Payment gateways, external APIs, domain-specific services
  - Pass explicitly when only a few controllers need them
  - Prevents Services from becoming too large
- **Minimal Global State**: Limited to BEAM-level constructs (connection pools, ETS tables)
  - Database connection pools (managed by BEAM)
  - Telemetry ETS tables (BEAM-native storage)
  - These are infrastructure-level, not application-level state

**Why**: Web applications evolve rapidly with changing cross-cutting concerns (caching, metrics, logging). The Services pattern allows adding these without touching 50+ function signatures. This prioritizes developer velocity while maintaining testability through dependency injection at the Services level.

### 3. Result-Based Error Handling

**Principle**: Errors are values, not exceptions.

- **Result Types Everywhere**: All failable operations return `Result(success, error)`
- **No Exceptions for Control Flow**: Exceptions only for truly exceptional circumstances
- **Explicit Error Propagation**: Use `try` or explicit pattern matching
- **Type-Safe Error Handling**: Error types are specific and meaningful
- **Fail Fast**: Invalid configuration or initialization errors prevent startup

**Why**: Result types make error cases visible at compile time, force developers to consider failure modes, and eliminate hidden control flow paths.

### 4. Type Safety First

**Principle**: Leverage Gleam's type system to catch errors at compile time.

- **Strong Typing Throughout**: Avoid dynamic typing patterns
- **Make Invalid States Unrepresentable**: Use types to enforce invariants
- **Phantom Types for Compile-Time Guarantees**: Where appropriate
- **No Stringly-Typed Interfaces**: Use proper enums and custom types
- **Leverage Type Inference**: But provide explicit types for public APIs

**Why**: Compile-time guarantees are cheaper than runtime errors. Types serve as living documentation.

### 5. Composability and Modularity

**Principle**: Small, focused, composable pieces that work together. **Everything is swappable**.

- **Single Responsibility**: Each function, module, and service has one clear purpose
- **Records of Functions**: Define record types with function fields, not concrete implementations
  - Router: any record with `route`, `match`, `handle` functions works
  - Server: any record with `start`, `stop` functions works  
  - Database: any record with `query`, `execute`, `transaction` functions works
  - This is the **Strategy Pattern** - swappable behavior via function fields
- **No Hardcoded Dependencies**: Even "core" components (router, server) are pluggable
- **Composable Pipelines**: Middleware chains, request transformations
- **Small Functions**: Functions should do one thing well
- **Independently Testable**: Each unit can be tested in isolation
- **Clear Interfaces**: Well-defined record types with function fields
- **Reference Implementations**: We provide good defaults, you choose whether to use them

**Why**: Composable systems are easier to understand, test, modify, and scale. Records of functions mean you're never locked into our choices. Small pieces reduce cognitive load.

**Example**: Want to use a different router? Return a `Router` record with your functions. Want a different server than Mist? Return a `Server` record with your adapter. Want custom middleware? Match the `Middleware` function signature.

## Architecture Patterns

### Service Layer Pattern

Services are initialized once at application startup and injected into the request pipeline.

**Core Services** (included in Services record):
- **Config**: Configuration data structure (not a service, but included for convenience)
- **Database Service**: Connection pool and query execution
- **Logging Service**: Structured logging with levels
- **Auth Service**: Session and JWT management
- **Cache Service**: In-memory and distributed caching (if used frequently)

**Keep Services Small**: Only include truly common dependencies. If a service is only used by 2-3 controllers, pass it as an explicit parameter instead.

**Specialized Services** (passed as explicit parameters):
- **Payment Gateways**: Only needed by payment controllers
- **Email Service**: Unless most controllers send email, pass explicitly
- **SMS Service**: Usually only needed for notifications
- **Storage Service**: Unless most controllers upload files, pass explicitly
- **External APIs**: Domain-specific integrations

**Pattern**:
```gleam
// Common services in Services record
pub type Services {
  Services(
    database: DatabaseService,
    logging: LoggingService,
    auth: AuthService,
  )
}

// Handler signature: Request, Context, Services
pub fn process_payment(
  request: Request,
  context: AppContext,
  services: Services,
) -> Response {
  // Access database via services.database
  // Access request data via request.body, request.headers, etc.
  // Access per-request state via context
}

// Specialized services as explicit parameters
pub fn process_payment(
  request: Request,
  context: AppContext,
  services: Services,
  payment_gateway: PaymentGateway,  // Specialized - explicit
) -> Response
```

**Why This Split**: Balances convenience (common services always available) with explicitness (specialized dependencies visible in signatures).

### Swappable Components via Records of Functions

**Principle**: Use records of functions for swappable implementations. Everything is pluggable.

**Note**: Gleam doesn't have protocols like Elixir. Instead, we use records that contain functions (Strategy pattern / manual dependency injection).

**Core Component Types**:

1. **Router (Record of Functions)**
```gleam
// A record type that holds functions
pub type Router {
  Router(
    route: fn(Method, String, Handler) -> Nil,
    add_middleware: fn(String, Middleware) -> Nil,
    match: fn(Request) -> Result(Handler, RouteNotFound),
    handle: fn(Services, Request) -> Response,
  )
}

// Different implementations return different Router records
pub fn tree_router() -> Router {
  Router(
    route: tree_route,
    add_middleware: tree_add_middleware,
    match: tree_match,
    handle: tree_handle,
  )
}

pub fn regex_router() -> Router {
  Router(
    route: regex_route,
    add_middleware: regex_add_middleware,
    match: regex_match,
    handle: regex_handle,
  )
}
```

2. **Server (Record of Functions)**
```gleam
pub type Server {
  Server(
    start: fn(Config, Router, Services) -> Result(Nil, ServerError),
    stop: fn() -> Nil,
  )
}

// Adapters return Server records with different implementations
pub fn mist_adapter() -> Server {
  Server(start: mist_start, stop: mist_stop)
}

pub fn custom_adapter() -> Server {
  Server(start: custom_start, stop: custom_stop)
}
```

3. **Middleware (Function Signature)**
```gleam
// Middleware type with chaining support
pub type Middleware(context) {
  Middleware(fn(Request(context), fn(Request(context)) -> Response) -> Response)
}

// Any function matching this signature works
pub fn logging_middleware(
  request: Request(AppContext),
  next: fn(Request(AppContext)) -> Response,
) -> Response {
  // ... logging logic ...
  next(request)
}

pub fn auth_middleware(
  request: Request(AuthContext),
  next: fn(Request(AuthContext)) -> Response,
) -> Response {
  // ... authentication logic ...
  next(request)
}
```

4. **Database Service (Record of Functions)**
```gleam
pub type DatabaseService {
  DatabaseService(
    query: fn(String) -> Result(List(Row), DbError),
    execute: fn(String) -> Result(Int, DbError),
    transaction: fn(fn() -> Result(a, DbError)) -> Result(a, DbError),
  )
}

// Different implementations
pub fn postgres_service(config: DbConfig) -> DatabaseService {
  DatabaseService(
    query: postgres_query,
    execute: postgres_execute,
    transaction: postgres_transaction,
  )
}

pub fn sqlite_service(config: DbConfig) -> DatabaseService {
  DatabaseService(
    query: sqlite_query,
    execute: sqlite_execute,
    transaction: sqlite_transaction,
  )
}

pub fn mock_database() -> DatabaseService {
  DatabaseService(
    query: fn(_) { Ok([]) },
    execute: fn(_) { Ok(0) },
    transaction: fn(f) { f() },
  )
}
```

**Composition in main()**:
```gleam
pub fn main() {
  // 1. Load config
  let assert Ok(config) = config.load_from_env()
  
  // 2. Choose your implementations
  let router = tree_router.new()  // or any router implementation
  let server = mist_adapter.new()  // or any server adapter
  let database = postgres_service.new(config.database_url)  // or any DB
  let auth = jwt_auth_service.new(config.jwt_secret)  // or any auth
  
  // 3. Initialize services with your choices
  let assert Ok(services) = Services(
    config: config,
    database: database,
    logging: console_logging.new(),
    auth: auth,
  )
  
  // 4. Configure routes (using your chosen router)
  configure_routes(router, services)
  
  // 5. Start server (using your chosen server with your chosen router)
  server.start(config, router, services)
  process.sleep_forever()
}

pub fn configure_routes(router: Router, services: Services) {
  router.route(Get, "/", home_controller)
  router.route(Get, "/users/:id", get_user_controller)
  router.add_middleware("/admin/*", authentication_middleware)
}
```

**Benefits**:
- Swap router without touching controllers
- Swap HTTP server without changing application code
- Swap database implementation (Postgres → SQLite) without changing business logic
- Easy to mock any component for testing
- No vendor lock-in to Dream's implementations
- Mix and match: use Dream's router with your custom server, or vice versa

**How This Works**:
- Define record types that hold functions (like `Router`, `Server`, `DatabaseService`)
- Different implementations return records with different function implementations
- Your code uses the record fields, not caring about the underlying implementation
- This is the **Strategy Pattern** from OOP, adapted for functional programming

**What Dream Provides**:
- Record type definitions (like `Router`, `Server`, `DatabaseService`)
- Reference implementations (tree router, Mist adapter, etc.)
- Common middleware (logging, auth, etc.)
- Helper functions and utilities

**What You Provide**:
- Your choice of which implementations to use
- Custom implementations if you want them (just return a record with your functions)
- Application-specific business logic

### Request Pipeline Pattern

**Middleware Signature**:
```gleam
fn(Request, Context, Services, fn(Request, Context, Services) -> Response) -> Response
```
- Receives request, context, services, and next handler
- Can modify context before passing to next
- Can transform response after next returns
- Can short-circuit pipeline (auth, rate limiting)

**Controller Signature**:
```gleam
fn(Request, Context, Services) -> Response

// Or with specialized dependencies:
fn(Request, Context, Services, SpecializedService) -> Response
```
- Receives request (immutable HTTP data), context (mutable per-request state), and services (immutable shared state)
- Specialized services can be added as explicit parameters
- Returns response
- Contains business logic

**Controller Pattern - Model-Based Architecture**:

Controllers are thin HTTP orchestration layers. Data operations live in model modules.

```gleam
// Model layer - handles data operations
// examples/database/models/user.gleam
pub fn list(db: pog.Connection) -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError)
pub fn get(db: pog.Connection, id: Int) -> Result(pog.Returned(sql.GetUserRow), pog.QueryError)
pub fn create(db: pog.Connection, name: String, email: String) -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError)
pub fn decoder() -> decode.Decoder(#(String, String))
pub fn encode(user: sql.GetUserRow) -> json.Json

// Controller layer - HTTP orchestration only
// examples/database/controllers/users_controller.gleam
pub fn index(_request: Request, _context: DatabaseContext, services: Services) -> Response {
  let db = services.database.connection
  user.list(db) |> response.many_rows(user.encode_list)
}

pub fn create(request: Request, _context: DatabaseContext, services: Services) -> Response {
  let db = services.database.connection
  case validate_or_respond(request.body, user.decoder()) {
    Error(response) -> response
    Ok(data) -> {
      let #(name, email) = data
      user.create(db, name, email) |> response.one_row(user.encode_create)
    }
  }
}
```

**Pattern Benefits**: 
- **Controllers**: Focus on HTTP (params, validation, responses)
- **Models**: Focus on data (queries, encoding, decoding)
- **Utilities**: Reusable helpers (response builders, json encoders, validators)
- **Separation of concerns**: HTTP logic vs data logic vs infrastructure
- **Type-safe composition**: Each layer explicitly typed
- **Easy to test**: Models testable without HTTP, controllers testable with mock models

### Initialization Flow

**Five-Stage Composable Startup**:

1. **Config Loading** (`config.gleam`)
   ```gleam
   pub fn load_from_env() -> Result(Config, ConfigError) {
     // Parse and validate environment variables
     // Only function allowed to touch environment
   }
   ```

2. **Services Assembly** (`services.gleam`)
   ```gleam
   pub fn initialize_services() -> Services {
     case init_database() {
       Ok(database_service) ->
         Services(database: database_service)
       Error(error) ->
         panic as "Failed to initialize services"
     }
   }
   ```

3. **Route Configuration** (`router.gleam`)
   ```gleam
   pub fn create_router() -> Router(AppContext, Services) {
     router
     |> route(
       method: Get,
       path: "/",
       controller: home_controller.index,
       middleware: [],
     )
   }
   ```

4. **Server Startup** (`main.gleam`)
   ```gleam
   import dream/core/context
   import dream/servers/mist/server.{bind, context, listen, router, services} as dream
   import examples/database/router.{create_router}
   import examples/database/services.{initialize_services}
   
   pub fn main() {
     dream.new()
     |> context(context.AppContext(request_id: ""))
     |> services(initialize_services())
     |> router(create_router())
     |> bind("localhost")
     |> listen(3000)
   }
   ```

**Why This Flow**: 
- **Explicit Choice**: You see exactly which implementations are being used
- **Composable**: Swap any component by changing one line in main()
- **Dependencies flow in one direction**: config → implementations → services → routes → server
- **main() is composition root**: Only place that wires everything together
- **Testable**: Easy to substitute mock implementations for any protocol
- **No hidden dependencies**: Everything is passed explicitly
- **Fail fast**: Invalid config or initialization errors prevent startup

## Configuration Management

**Principle**: All configuration through environment variables; no configuration files.

- **Environment Variables Only**: `DATABASE_URL`, `JWT_SECRET`, etc.
- **Validated at Startup**: Invalid config prevents application start
- **No Runtime Configuration Changes**: Configuration is immutable after startup
- **Sensible Defaults**: Where appropriate, with ability to override
- **Type-Safe Configuration**: Parse and validate into typed structures
- **Config is Data, Not a Service**: Config is loaded in `main()`, then injected into `initialize_services()`
- **Only main() Touches Environment**: All other functions receive config as a parameter

**Pattern**:
```gleam
// config.gleam
pub type Config {
  Config(
    database_url: String,
    database_pool_size: Int,
    jwt_secret: String,
    port: Int,
    // ...
  )
}

pub fn load_from_env() -> Result(Config, ConfigError) {
  use database_url <- result.try(require_env("DATABASE_URL"))
  use jwt_secret <- result.try(require_env("JWT_SECRET"))
  
  Ok(Config(
    database_url: database_url,
    database_pool_size: get_env_int("DATABASE_POOL_SIZE", 10),
    jwt_secret: jwt_secret,
    port: get_env_int("PORT", 8000),
  ))
}
```

**Usage in main()**:
```gleam
// app.gleam
pub fn main() {
  // Load config - this is the ONLY place that reads environment variables
  let assert Ok(config) = config.load_from_env()
  
  // Inject config into services initialization
  let assert Ok(services) = initialize_services(config)
  
  // Continue with router and server
  let router = initialize_router(services)
  start_server(services, router)
}
```

**Why**: 
- 12-factor app methodology
- Works well with containers
- Explicit about requirements
- No config file parsing complexity
- Config-first initialization prevents circular dependencies
- **Only `main()` touches global state (environment)** - everything else receives config explicitly
- **Easy to test** - just pass a different Config to `initialize_services()`

## Code Organization Principles

### File Structure
- `app.gleam`: Application entry point and initialization
- `config.gleam`: Configuration type and environment variable loading
- `services.gleam`: Service initialization and Services record definition
- `router.gleam`: Route definitions and middleware pipeline
- `controllers/`: Controller functions organized by domain
- `middleware/`: Reusable middleware functions
- `models/`: Data types and domain models
- `services/`: Individual service implementations

### Naming Conventions
- **Services**: `*_service.gleam` (e.g., `database_service.gleam`)
- **Controllers**: `*_controller.gleam` (e.g., `user_controller.gleam`)
- **Middleware**: `*_middleware.gleam` (e.g., `auth_middleware.gleam`)
- **Models**: Domain name (e.g., `user.gleam`, `post.gleam`)

## Testing Philosophy

- **Unit Tests**: Test pure functions in isolation
- **Integration Tests**: Test service interactions with real dependencies
- **Controller Tests**: Test with mock Services record
- **Middleware Tests**: Test with mock Services and mock next functions
- **No Mocking for Pure Functions**: They don't need it
- **Test at the Boundaries**: Heavy testing where side effects occur

### Testing Pattern with Services

```gleam
// Helper to create test Services with sensible defaults
pub fn test_services() -> Services {
  Services(
    config: test_config(),
    database: mock_database(),
    logging: mock_logging(),
    auth: mock_auth(),
  )
}

// Override specific services when needed
pub fn test_services_with_db(db: DatabaseService) -> Services {
  Services(
    config: test_config(),
    database: db,
    logging: mock_logging(),
    auth: mock_auth(),
  )
}

// Test becomes simple
pub fn test_create_post() {
  let mock_db = DatabaseService(...)
  let services = test_services_with_db(mock_db)
  
  let response = create_post(services, test_request)
  
  // Assert...
}
```

This pattern keeps tests maintainable even with the Services god object.

## What Success Looks Like

When these principles are followed:
- ✅ New developers can understand the codebase quickly
- ✅ Tests are easy to write and maintain
- ✅ Refactoring is safe and straightforward
- ✅ Bugs are caught at compile time, not runtime
- ✅ Adding new features doesn't break existing ones
- ✅ Code reviews focus on business logic, not architecture debates
- ✅ The codebase scales gracefully as the team grows
- ✅ **You can swap any component** (router, server, database) without rewriting business logic
- ✅ **No vendor lock-in** - you're never trapped by Dream's choices
- ✅ **Gradual adoption** - you can use just the parts you need
- ✅ **Mix and match** - Dream's router with your server, or vice versa

## Non-Goals

What Dream intentionally does NOT do:
- ❌ Support for closures or higher-order functions that hide dependencies in business logic
- ❌ Global service locator with runtime lookup (services are injected, not discovered)
- ❌ Runtime configuration changes (config is immutable after startup)
- ❌ Dynamic code loading or hot reloading (use BEAM mechanisms instead)
- ❌ Magic or convention over configuration (explicit is better)
- ❌ Pure explicit DI for all services (too much refactoring cost - we use Services pattern)
- ❌ Dictate which router, server, or database you must use (everything is protocol-based)
- ❌ Force an "opinionated" way of doing things (we provide interfaces, you compose)

## Acknowledged Tradeoffs

The Services "god object" pattern is an **intentional compromise**:

**We Accept**:
- ✅ Services contains multiple dependencies (not pure single responsibility)
- ✅ Controllers can access services they don't use (trust over enforcement)
- ✅ Function signatures don't show exact dependencies (convention over type safety)

**We Get**:
- ✅ Rapid iteration without constant refactoring
- ✅ Easy addition of cross-cutting concerns (logging, caching, metrics)
- ✅ Simple, consistent controller and middleware signatures
- ✅ Reasonable testing ergonomics with helper functions

**We Mitigate**:
- ✅ Extract dependencies at function start (readability)
- ✅ Keep Services small (only common infrastructure)
- ✅ Use explicit parameters for specialized services (partial explicitness)
- ✅ Document what controllers use (via extraction pattern or comments)

---

**Remember**: These principles exist to make the codebase maintainable, testable, and scalable. When in doubt, favor explicitness, type safety, and simplicity over cleverness.