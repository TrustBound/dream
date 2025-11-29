# Dream Documentation

**Clean, composable web development for Gleam.**

Dream is a web toolkit that gets out of your way. It provides type-safe routing, explicit dependency injection, and composable middleware. No magic. No global state. Just functions and data.

---

## Where to start

If you are new to Dream or Gleam, follow this path the first time through:

1. [Quickstart](quickstart.md) – run a tiny app in a few minutes.
2. [Learning Path](learn/) – work through the four short lessons.
3. [Guides](guides/) – look up a specific task (auth, templates, streaming, WebSockets, etc.).
4. [Examples](examples.md) – open a full app that matches what you are trying to build.
5. [Core Patterns](concepts/patterns.md) – skim the pattern catalog to see what Dream provides.

After that, dip into the sections below whenever you need more detail.

## Explore the System

### 🚀 [Quickstart](quickstart.md)
**New to Dream?** Get a server running quickly. Copy-paste ready code to get you started immediately.

### 🎓 [Learning Path](learn/)
**Want to understand the system?** A structured 2-hour course taking you from "Hello World" to advanced production patterns.
- [Hello World](learn/01-hello-world.md)
- [Building an API](learn/02-building-api.md)
- [Adding Auth](learn/03-adding-auth.md)
- [Advanced Patterns](learn/04-advanced-patterns.md)

### 🛠️ [Guides](guides/)
**Building something specific?** Task-based guides for common requirements.
- [Authentication](guides/authentication.md) - JWT, Sessions, Context
- [Controllers & Models](guides/controllers-and-models.md) - MVC Patterns
- [Multiple Formats](guides/multiple-formats.md) - JSON, HTML, HTMX
- [Streaming](guides/streaming.md) - File uploads, SSE, large responses
- [Operations](guides/operations.md) - Complex Business Logic
- [Testing](guides/testing.md) - Unit and Integration Testing
- [REST API](guides/rest-api.md) - Production API patterns
- [Deployment](guides/deployment.md) - Production deployment

### 📖 [Concepts](concepts/)
**Core concepts explained.** Understanding how Dream works.
- [How It Works](concepts/how-it-works.md) - Request flow from arrival to response
- [Project Structure](concepts/project-structure.md) - Organizing a real application
- [Core Patterns](concepts/patterns.md) - Catalog of Dream patterns: routing, context & services, middleware, MVC, operations, auth, multi-format responses, streaming, WebSockets, templates, testing

### 📚 [Reference](reference/)
**Need details?** Deep dives into the architecture and API.
- [Architecture](concepts/architecture.md) - How it all fits together
- [Design Principles](concepts/design-principles.md) - The "Why" behind Dream
- [Why the BEAM?](concepts/why-beam.md) - Understanding the runtime
- [Naming Conventions](reference/naming-conventions.md) - Code Style
- [dream_standards](reference/dream_standards.md) - Hard coding rules for Dream core and modules

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

See the [Architecture Reference](concepts/architecture.md#modules-ecosystem) for detailed module documentation and usage examples.

---

## Contributing
Want to help? Check out the [Contributing Guide](contributing/).

**Maintainers:** See [Publishing Strategy](contributing/publishing.md) for module publishing.





