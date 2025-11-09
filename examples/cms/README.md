# CMS Example

**Complex example demonstrating Dream's clean MVC architecture with multiple services.**

This example validates Dream's architectural patterns with:
- Multiple data stores (Postgres + OpenSearch)
- Operations coordinating services
- Streaming responses (CSV export)
- Server-Sent Events (live event feed)
- Clean separation: Controllers (HTTP) → Operations (business logic) → Models (repositories) → Views (serializers)

## Architecture Demonstration

### Models (Repositories)
Data access functions that return domain types:
- `models/user/` - Postgres queries for users
- `models/post/` - Postgres queries for posts
- `models/event/` - OpenSearch queries for events

Models hide storage implementation details and return clean domain types.

### Views (Serializers)
Pure formatting functions:
- `views/user_view.gleam` - User → JSON/CSV/HTML
- `views/post_view.gleam` - Post → JSON/CSV/HTML
- `views/event_view.gleam` - Event → JSON

Views have zero HTTP knowledge, zero error handling.

### Controllers (HTTP Handlers)
HTTP request/response handling:
- `controllers/users_controller.gleam` - User endpoints
- `controllers/posts_controller.gleam` - Post endpoints with format negotiation
- `controllers/events_controller.gleam` - Event endpoints with SSE

Controllers parse requests, map errors to status codes, build responses.

### Operations (Business Logic)
Complex multi-service coordination:
- `operations/publish_post.gleam` - Publish → log event (Postgres + OpenSearch)
- `operations/export_posts.gleam` - Streaming CSV export
- `operations/enrich_events.gleam` - Fetch events + enrich with users (OpenSearch + Postgres)

Operations orchestrate multiple models and enforce business rules.

## Setup

1. **Start services:**
```bash
make db-up
```

2. **Create migrations:**
```bash
make migrate-new name=create_users
make migrate-new name=create_posts
```

Edit the generated migration files in `priv/migrations/`.

3. **Run migrations:**
```bash
make migrate-up
```

4. **Generate Squirrel functions:**
```bash
make squirrel
```

5. **Run the application:**
```bash
make run
```

## Endpoints

**Users:**
- `GET /users` - List all users
- `GET /users/:id` - Get user by ID

**Posts:**
- `GET /posts` - List all posts
- `GET /posts/:id` - Get post (supports .json, .html formats)
- `POST /posts/:id/publish` - Publish a post (logs to OpenSearch)
- `GET /posts/export` - Export posts as CSV (streaming)

**Events:**
- `GET /events` - List recent events (enriched with user data)
- `GET /events/stream` - SSE stream of live events

## Testing the Architecture

**Create some data:**
```bash
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "email": "alice@example.com"}'

curl -X POST http://localhost:3000/posts \
  -H "Content-Type: application/json" \
  -d '{"title": "First Post", "content": "Hello World", "author_id": 1}'
```

**Test multi-service operation:**
```bash
# Publishes to Postgres AND logs to OpenSearch
curl -X POST http://localhost:3000/posts/1/publish
```

**Test streaming:**
```bash
# Streams CSV data
curl http://localhost:3000/posts/export
```

**Test SSE:**
```bash
# Opens SSE connection, streams events
curl http://localhost:3000/events/stream
```

**Check event logs:**
```bash
curl http://localhost:3000/events
```

## What This Demonstrates

1. ✅ **Service-agnostic** - Uses modules (dream_postgres, dream_opensearch)
2. ✅ **Multi-store coordination** - Operations work across Postgres + OpenSearch
3. ✅ **Clean models** - Return domain types, not DB types
4. ✅ **Pure views** - Just formatting, no errors or HTTP
5. ✅ **Focused controllers** - HTTP only, delegate to operations
6. ✅ **Streaming** - Memory-efficient CSV export
7. ✅ **SSE** - Real-time event feed
8. ✅ **No nested cases** - Flat helper functions
9. ✅ **No anonymous functions** - All functions are named

