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

**Run:** `cd examples/simplest && make run`

---

### 2. [simple/](../examples/simple/)
**Basic routing and path parameters.**

Multiple routes, path parameters, HTTP client usage.

**Demonstrates:**
- Path parameters (`:id`)
- Multiple controllers
- HTTP client (non-streaming)

**Run:** `cd examples/simple && make run`
**Test:** 4 integration tests

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
**Test:** 15 integration tests with database isolation

---

### 4. [custom_context/](../examples/custom_context/)
**Authentication with middleware.**

Custom context types and middleware for auth.

**Demonstrates:**
- Custom context (beyond AppContext)
- Middleware pattern
- Context enrichment
- Protecting routes

**Run:** `cd examples/custom_context && make run`
**Test:** 8 integration tests covering authentication

---

### 5. [tasks/](../examples/tasks/)
**Full-featured task app with HTMX.**

Complete task management application with HTMX, semantic classless HTML, and composable templates.

**Demonstrates:**
- HTMX patterns (create, update, delete, toggle)
- Semantic HTML only (no divs/spans)
- Classless CSS (Pico CSS)
- Composable matcha templates (elements → components → views)
- No raw HTML in Gleam code

**Run:** `cd examples/tasks && make db-up && make migrate && make squirrel && make matcha && make run`
**Test:** Comprehensive Cucumber integration tests

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
**Test:** 12 integration tests covering all formats

---

### [streaming/](../examples/streaming/)
**HTTP client with streaming.**

Both streaming and non-streaming HTTP requests to external APIs.

**Demonstrates:**
- HTTP client streaming
- Chunk processing
- Memory-efficient requests
- External API calls

**Run:** `cd examples/streaming && make run`
**Test:** 6 integration tests

---

### [streaming_capabilities/](../examples/streaming_capabilities/)
**🔥 Advanced streaming patterns.**

Complete streaming showcase: ingress, egress, bi-directional, middleware, proxying.

**Demonstrates:**
- **Ingress streaming**: Upload large files without buffering
- **Egress streaming**: Download data generated on-the-fly
- **Bi-directional streaming**: Transform data both ways
- **Streaming middleware**: Uppercase input, transform output
- **Proxy streaming**: Stream from external sources

**Run:** `cd examples/streaming_capabilities && make run`
**Test:** Integration tests with all streaming patterns

---

### [rate_limiter/](../examples/rate_limiter/)
**Global rate limiting with singletons.**

Rate limiting across all requests using singleton pattern.

**Demonstrates:**
- Singleton pattern (shared state)
- ETS tables
- Rate limiting middleware

**Run:** `cd examples/rate_limiter && make run`
**Test:** 8 integration tests with unique IP isolation

---

### [static/](../examples/static/)
**Serving static files.**

File serving with security, directory listing, MIME types.

**Demonstrates:**
- Static file controller
- Security (path traversal prevention)
- Custom MIME types
- Directory listings

**Run:** `cd examples/static && make run`
**Test:** 10 integration tests with security validation

---

## How to Use Examples

1. **Read the README** - Explains what it demonstrates
2. **Read the code** - Commented to explain patterns
3. **Run it** - See it working
4. **Run the tests** - See comprehensive test coverage
5. **Modify it** - Break things and learn

Each example is self-contained with its own database (if needed), dependencies, and setup.

## Testing Examples

All examples include comprehensive integration tests using Cucumber (BDD framework):

```bash
# Run all example tests
make test-examples

# Run specific example tests
cd examples/database && make test-integration
```

**Total: 63 integration tests** covering:
- Error handling (400, 404, 500)
- Content validation (JSON, CSV, HTML)
- Security (auth, path traversal, rate limiting)
- Streaming (request/response, chunked transfer)
- Database (CRUD, persistence, isolation)

See [Testing Guide](contributing/testing.md) for details.

---

## Next Steps

- [Concepts](concepts.md) - Understand Dream's core ideas
- [Guides](guides/) - Build something specific  
- [Testing Guide](contributing/testing.md) - Learn about the test suite
- [Reference](reference/) - Deep dives on architecture




