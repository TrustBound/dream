# Examples

Complete, working applications. Read the code—it's commented to explain the patterns.

---

## Learning Order

### 1. [simplest/](../examples/simplest/)
**One file. One route.**

The absolute minimum Dream app. Everything inline, no organization. Start here.

**Demonstrates:**
- Basic controller
- Router setup
- Server configuration

**Run:** `cd examples/simplest && ./run_example.sh`

---

### 2. [simple/](../examples/simple/)
**Basic routing and path parameters.**

Multiple routes, path parameters, HTTP client usage.

**Demonstrates:**
- Path parameters (`:id`)
- Multiple controllers
- HTTP client (non-streaming)

**Run:** `cd examples/simple && ./run_example.sh`

---

### 3. [database/](../examples/database/)
**Full CRUD API with PostgreSQL.**

Complete REST API with type-safe SQL, migrations, and validation.

**Demonstrates:**
- Services pattern (database connection)
- Models (data access)
- Views (JSON formatting)
- Squirrel (type-safe SQL)
- Cigogne (migrations)
- Makefile automation

**Run:** `cd examples/database && make db-up && make migrate && make run`

---

### 4. [custom_context/](../examples/custom_context/)
**Authentication with middleware.**

Custom context types and middleware for auth.

**Demonstrates:**
- Custom context (beyond AppContext)
- Middleware pattern
- Context enrichment
- Protecting routes

**Run:** `cd examples/custom_context && ./run_example.sh`

---

### 5. [cms/](../examples/cms/)
**Full application with operations.**

Complex CMS with posts, users, events, and operations.

**Demonstrates:**
- Operations pattern (business logic)
- Multiple services (DB, OpenSearch, events)
- Coordinating models
- Complex workflows

**Run:** `cd examples/cms && make db-up && make migrate && make run`

---

## Specialized Examples

### [multi_format/](../examples/multi_format/)
**JSON, HTML, CSV, HTMX responses.**

Same data in multiple formats with content negotiation.

**Demonstrates:**
- Matcha templates (HTML)
- Format detection (URL extension, Accept header)
- CSV streaming
- HTMX partials

**Run:** `cd examples/multi_format && make db-up && make migrate && make run`

---

### [streaming/](../examples/streaming/)
**HTTP client with streaming.**

Both streaming and non-streaming HTTP requests.

**Demonstrates:**
- HTTP client streaming
- Chunk processing
- Memory-efficient requests

**Run:** `cd examples/streaming && ./run_example.sh`

---

### [rate_limiter/](../examples/rate_limiter/)
**Global rate limiting with singletons.**

Rate limiting across all requests using singleton pattern.

**Demonstrates:**
- Singleton pattern (shared state)
- ETS tables
- Rate limiting middleware

**Run:** `cd examples/rate_limiter && ./run_example.sh`

---

### [static/](../examples/static/)
**Serving static files.**

File serving with security, directory listing, MIME types.

**Demonstrates:**
- Static file controller
- Security (path traversal prevention)
- Custom MIME types
- Directory listings

**Run:** `cd examples/static && ./run_example.sh`

---

## How to Use Examples

1. **Read the README** - Explains what it demonstrates
2. **Read the code** - Commented to explain patterns
3. **Run it** - See it working
4. **Modify it** - Break things and learn

Each example is self-contained with its own database (if needed), dependencies, and setup.

---

## Next Steps

- [Concepts](concepts.md) - Understand Dream's core ideas
- [Reference](reference/) - Deep dives on architecture




