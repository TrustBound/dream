# Example Projects

**Working code you can actually run. Because reading is nice, but running is better.**

All examples are in `src/examples/` and are fully working applications you can run locally.

## Simple Example

**Location:** `src/examples/simple/`  
**Tutorial:** [Basic Routing](tutorials/basic-routing.md)

The simplest possible Dream app. Two routes, path parameters, and an HTTP client call.

**What it demonstrates:**
- Basic routing with `GET` requests
- Path parameter extraction (`/users/:id/posts/:post_id`)
- HTTP client usage (non-streaming)
- Clean controller pattern

**Run it:**

```bash
cd src/examples/simple
gleam run
```

Visit: `http://localhost:3000/`

## Database Example

**Location:** `src/examples/database/`  
**Tutorial:** [Database CRUD](tutorials/database-crud.md)

Full CRUD operations with PostgreSQL, type-safe SQL queries, and JSON validation.

**What it demonstrates:**
- PostgreSQL connection with Pog
- Type-safe SQL with Squirrel
- Model-Controller pattern
- JSON request validation
- Database error handling
- Complete REST API

**Run it:**

```bash
make db-up       # Start PostgreSQL
make migrate     # Run migrations
cd src/examples/database
gleam run
```

Visit: `http://localhost:3002/users`

**API Endpoints:**
- `GET /users` - List all users
- `GET /users/:id` - Get one user
- `POST /users` - Create user (JSON body: `{"name":"Alice","email":"alice@example.com"}`)
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user
- `GET /users/:user_id/posts` - List user's posts
- `GET /posts/:id` - Get one post
- `POST /users/:user_id/posts` - Create post

## Custom Context Example

**Location:** `src/examples/custom_context/`  
**Tutorial:** [Authentication](tutorials/authentication.md)

Authentication and authorization with custom context types and middleware.

**What it demonstrates:**
- Custom context type (`AuthContext` with user info)
- Authentication middleware (validates tokens)
- Authorization middleware (checks roles)
- Middleware chaining
- Context propagation through request pipeline

**Run it:**

```bash
cd src/examples/custom_context
gleam run
```

Visit: `http://localhost:3001/`

**Test authentication:**

```bash
# Public endpoint (no auth)
curl http://localhost:3001/public

# Protected endpoint (needs token)
curl -H "Authorization: Bearer user-token" http://localhost:3001/posts

# Admin endpoint (needs admin token)
curl -H "Authorization: Bearer admin-token" http://localhost:3001/admin
```

**Test Tokens:**
- `Bearer user-token` - Regular user
- `Bearer admin-token` - Admin user

## Singleton Rate Limiter Example

**Location:** `src/examples/singleton/`

Real-world rate limiting using the singleton pattern for global state management.

**What it demonstrates:**
- Singleton pattern with `dream/core/singleton`
- Global state management across requests
- Services pattern with process Name storage
- Rate limiting middleware with 429 responses
- Fixed window rate limiting algorithm
- Rate limit headers (X-RateLimit-*)

**Run it:**

```bash
gleam run -m examples/singleton/main
```

**Test rate limiting:**

```bash
# First 10 requests succeed, last 2 are rate limited
for i in {1..12}; do 
  echo "Request $i:"
  curl -i http://localhost:3000/api | head -5
done
```

**Endpoints:**
- `GET /` - Welcome page (no rate limit)
- `GET /api` - Rate-limited API endpoint
- `GET /api/status` - Rate limit status (also rate-limited)

**Key Pattern:** The `process.Name` must be created once at startup and stored in the Services struct. Calling `process.new_name()` repeatedly creates different name objects that won't reference the same singleton.

## Streaming Example

**Location:** `src/examples/streaming/`  
**Tutorial:** [HTTP Client](tutorials/http-client.md)

HTTP client with both streaming and non-streaming requests.

**What it demonstrates:**
- HTTP client builder pattern
- Non-streaming requests (fetch full response)
- Streaming requests (process chunks as they arrive)
- HTTPS support
- External API calls

**Run it:**

```bash
cd src/examples/streaming
gleam run
```

Visit: `http://localhost:3003/`

**Endpoints:**
- `GET /` - Info page
- `GET /fetch` - Non-streaming HTTP request to httpbin.org
- `GET /stream` - Streaming HTTP request to httpbin.org

## Static File Serving Example

**Location:** `src/examples/static/`

Secure static file serving with directory listing, extension filtering, and custom 404 handlers.

**What it demonstrates:**
- Static file controller with path traversal prevention
- Multiple static directories with different configurations
- Directory listing (when enabled)
- Extension-based filtering using router patterns (`*.{jpg,png}`)
- Custom 404 handlers
- Automatic MIME type detection using marceau
- Wildcard routing (`**filepath`)

**Run it:**

```bash
gleam run -m examples/static/main
```

Visit: `http://localhost:3000/public/`

**Test URLs:**
- `http://localhost:3000/public/` - Serves index.html
- `http://localhost:3000/public/about/` - Nested index.html
- `http://localhost:3000/public/images/` - Directory listing
- `http://localhost:3000/public/styles.css` - CSS file
- `http://localhost:3000/public/script.js` - JavaScript file
- `http://localhost:3000/public/images/cat.svg` - SVG image
- `http://localhost:3000/images/cat.svg` - Via extension-filtered route
- `http://localhost:3000/assets/data.json` - JSON from assets directory
- `http://localhost:3000/custom/missing.html` - Custom 404 page

**Security tests:**
- `http://localhost:3000/public/../../../etc/passwd` - Should return 404 (path traversal blocked)

## Running All Examples

You can run all examples simultaneously on different ports:

```bash
# Terminal 1
gleam run -m examples/static/main  # Port 3000

# Terminal 2
cd src/examples/custom_context && gleam run  # Port 3001

# Terminal 3
cd src/examples/database && gleam run  # Port 3002

# Terminal 4
cd src/examples/streaming && gleam run  # Port 3003
```

Note: The simple and singleton examples also use port 3000, so run only one at a time.

## Common Patterns Across Examples

All examples follow the same structure:

```
src/examples/[example_name]/
  controllers/      # HTTP request handlers
  models/          # Data operations (database example only)
  middleware/      # Custom middleware (auth example only)
  sql/            # SQL files (database example only)
  context.gleam   # Context type definition
  main.gleam      # Application entry point
  router.gleam    # Route definitions
  services.gleam  # Service initialization
```

This consistency makes it easy to understand any example once you've seen one.

## Tips for Exploring Examples

1. **Start with simple** - Get the basics down
2. **Read the tutorial first** - Context helps
3. **Run the code** - See it work
4. **Modify and experiment** - Break things, fix them, learn
5. **Check the tests** - See how we test each pattern

## Next Steps

After exploring the examples:

- Read the [Guides](../README.md#guides) for deep dives
- Check the [Reference](../README.md#reference) for complete API docs
- Build your own app using these patterns

---

**[← Back: Documentation](../README.md)**

