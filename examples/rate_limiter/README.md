# Singleton Rate Limiter Example

Real-world rate limiting using the singleton pattern for global state management.

## What This Demonstrates

- **Singleton pattern** - Using `dream/singleton` for global state
- **Global state management** - Shared state across all requests
- **Services pattern** - Storing process Names in Services struct
- **Rate limiting middleware** - 429 responses when limit exceeded
- **Fixed window algorithm** - 10 requests per 60 seconds
- **Rate limit headers** - X-RateLimit-* headers in responses

## Running the Example

```bash
cd examples/singleton
make run
```

Server starts on `http://localhost:3000`

## Endpoints

- `GET /` - Welcome page (no rate limit)
- `GET /api` - Rate-limited API endpoint (10 requests per 60 seconds)
- `GET /api/status` - Rate limit status endpoint (also rate-limited)

## Testing Rate Limiting

```bash
# Make multiple requests to trigger rate limiting
for i in {1..15}; do 
  echo "Request $i:"
  curl -i http://localhost:3000/api | head -5
  echo ""
done
```

The first 10 requests will succeed with `200 OK`. Requests 11-15 will return `429 Too Many Requests` with rate limit headers.

## Rate Limit Headers

Responses include rate limit information:

```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 5
X-RateLimit-Reset: 60
```

## Example Usage

```bash
# Public endpoint (no rate limit)
curl http://localhost:3000/

# Rate-limited endpoint
curl -i http://localhost:3000/api

# Check rate limit status
curl -i http://localhost:3000/api/status
```

## Code Structure

```
examples/singleton/
├── gleam.toml          # Project config
├── Makefile            # Build and run commands
└── src/
    ├── main.gleam     # Application entry point
    ├── router.gleam   # Route definitions
    ├── services.gleam  # Service initialization
    ├── controllers/
    │   └── api_controller.gleam
    ├── middleware/
    │   └── rate_limit_middleware.gleam
    └── services/
        └── rate_limiter_service.gleam  # Singleton service
```

## Key Concepts

- **Singleton Pattern** - One instance shared across all requests
- **Process Names** - Must be created once and stored in Services
- **Fixed Window** - Simple rate limiting algorithm (count requests in time window)
- **Middleware Integration** - Rate limiting happens before controllers run

## Important Pattern

The `process.Name` must be created **once** at startup and stored in the Services struct. Calling `process.new_name()` repeatedly creates different name objects that won't reference the same singleton.

```gleam
// ✅ Correct - name created once at startup
let rate_limiter_name = process.new_name("rate_limiter")
Services(rate_limiter: rate_limiter_name)

// ❌ Wrong - creates new name each time
fn get_rate_limiter() {
  process.new_name("rate_limiter")  // Different name each call!
}
```

This example shows how to implement global state management and rate limiting in Dream.

