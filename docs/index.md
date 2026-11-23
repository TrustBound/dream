# Dream Documentation

**Clean, composable web development for Gleam.**

Dream is a web toolkit that gets out of your way. It provides type-safe routing, explicit dependency injection, and composable middleware. No magic. No global state. Just functions and data.

---

## Where to start

If you are new to Dream or Gleam, follow this path the first time through:

1. [Build your first Dream server](guides/getting-started.md) – from an empty folder to a tested route.
2. [Guides](guides/index.md) – one guide for each task: routing, request data, a database API, streaming, WebSockets, deployment and more.
3. [Examples](examples.md) – open a full app that matches what you are trying to build.
4. [Core Patterns](concepts/patterns.md) – skim the pattern catalog to see what Dream provides.

After that, dip into the sections below whenever you need more detail.

## Explore the System

### 🛠️ [Guides](guides/index.md)
**Building something specific?** Each guide walks through one task with real code and the real answers of a running server.
- [Build your first Dream server](guides/getting-started.md)
- [Route requests and add middleware](guides/routing.md)
- [Read request data safely](guides/request-data.md)
- [Send responses, cookies and files](guides/responses.md)
- [Build a database-backed JSON API](guides/database-api.md)
- [Grow a JSON API](guides/api-patterns.md)
- [Render HTML and other formats](guides/templates.md)
- [Stream responses and uploads](guides/streaming.md)
- [Push live updates with server-sent events](guides/sse.md)
- [Build a chat with WebSockets](guides/websockets.md)
- [Serve HTTPS and HTTP/2](guides/http2.md)
- [Test your controllers and your app](guides/testing.md)
- [Deploy with Docker](guides/deployment.md)
- [Start, stop and troubleshoot the server](guides/operating.md)

### 📖 [Concepts](concepts.md)
**Core concepts explained.** Understanding how Dream works.
- [How It Works](concepts/how-it-works.md) - Request flow from arrival to response
- [Project Structure](concepts/project-structure.md) - Organizing a real application
- [Core Patterns](concepts/patterns.md) - Catalog of Dream patterns: routing, context & services, middleware, MVC, operations, auth, multi-format responses, streaming, WebSockets, templates, testing
- [All Concepts](concepts.md) - Complete overview of controllers, routers, middleware, models, views

### 📚 [Reference](reference/)
**Need details?** Deep dives into the architecture and API.
- [Architecture](reference/architecture.md) - How it all fits together
- [Design Principles](reference/design-principles.md) - The "Why" behind Dream
- [Why the BEAM?](reference/why-beam.md) - Understanding the runtime
- [Naming Conventions](reference/naming-conventions.md) - Code Style

### 📦 Ecosystem
Dream is modular. You use what you need:

**Core:**
- `dream` - Router, HTTP types, response builders, validation

**Data:**
- `dream_postgres` - PostgreSQL utilities, query helpers
- `dream_opensearch` - OpenSearch client for search

**Utilities:**
- `dream_http_client` - HTTP client with streaming support
- `dream_config` - Configuration management (env vars, .env files)
- `dream_json` - JSON encoding utilities
- `dream_ets` - ETS (Erlang Term Storage) for in-memory storage

See the [Architecture Reference](reference/architecture.md#modules-ecosystem) for detailed module documentation and usage examples.

---

## Contributing
Want to help? Check out the [Contributing Guide](contributing/).

**Maintainers:** See [Publishing Strategy](contributing/publishing.md) for module publishing.





