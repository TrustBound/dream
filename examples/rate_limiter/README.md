# Singleton Rate Limiter Example

Real-world rate limiting using shared ETS-backed state for global rate limiting.

## What This Demonstrates

- **Global state via ETS** - Using `dream_ets` for shared state
- **Global state management** - Shared state across all requests
- **Services pattern** - Storing ETS tables in the Services struct
- **Rate limiting middleware** - 429 responses when limit exceeded
- **Fixed window algorithm** - 10 requests per 60 seconds
- **Rate limit headers** - X-RateLimit-* headers in responses

## Running the Example

```bash
cd examples/rate_limiter
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
examples/rate_limiter/
├── gleam.toml          # Project config
├── Makefile            # Build and run commands
└── src/
    ├── main.gleam      # Application entry point
    ├── router.gleam    # Route definitions
    ├── services.gleam  # Service initialization
    ├── controllers/
    │   └── api_controller.gleam
    ├── middleware/
    │   └── rate_limit_middleware.gleam
    └── services/
        └── rate_limiter_service.gleam  # ETS-backed rate limiter service
```

## Key Concepts

- **ETS-backed shared state** - Request counters stored in ETS tables created at startup
- **dream_ets integration** - Uses dream_ets config/operations helpers
- **Fixed Window** - Simple rate limiting algorithm (count requests in time window)
- **Middleware Integration** - Rate limiting happens before controllers run

## Important Pattern

The rate limiter service is created **once** at startup in `initialize_services` and stored in the `Services` struct. Middleware reuses that instance; it does **not** create new ETS tables on each request.

```gleam
// services.gleam (simplified)
pub fn initialize_services() -> Services {
  case create_rate_limiter() {
    Ok(limiter) -> Services(rate_limiter: limiter)
    Error(_) -> panic as "Could not initialize rate limiter service"
  }
}
```

This example shows how to implement global state management and rate limiting in Dream using ETS.

