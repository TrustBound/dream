# Dream Documentation

**Clean, composable web development for Gleam.**

Dream is a web toolkit that gets out of your way. It provides type-safe routing, explicit dependency injection, and composable middleware. No magic. No global state. Just functions and data.

---

## Explore the System

### 🚀 [Quickstart](quickstart.md)
**New to Dream?** Get a server running in 5 minutes. Copy-paste ready code to get you started immediately.

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
- [Operations](guides/operations.md) - Complex Business Logic
- [Testing](guides/testing.md) - Unit and Integration Testing

### 📚 [Reference](reference/)
**Need details?** Deep dives into the architecture and API.
- [Architecture](reference/architecture.md) - How it all fits together
- [Design Principles](reference/design-principles.md) - The "Why" behind Dream
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





