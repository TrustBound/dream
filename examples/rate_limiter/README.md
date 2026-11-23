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

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Send 15 requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme.sh#L3-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Make multiple requests to trigger rate limiting
for i in {1..15}; do 
  echo "Request $i:"
  curl -i http://localhost:3000/api | head -5
  echo ""
done
```

The first 10 requests will succeed with `200 OK`. Requests 11-15 will return `429 Too Many Requests` with rate limit headers.

The output of requests 10 and 11:

### Requests 10 and 11 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme_output.txt#L64-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Request 10:
HTTP/1.1 200 OK
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 11:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
```

## Rate Limit Headers

Responses include rate limit information:

### The headers of the first request <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme_output.txt#L2-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```http
HTTP/1.1 200 OK
x-ratelimit-remaining: 9
x-ratelimit-limit: 10
```

## Example Usage

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme.sh#L10-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Public endpoint (no rate limit)
curl http://localhost:3000/

# Rate-limited endpoint
curl -i http://localhost:3000/api

# Check rate limit status
curl -i http://localhost:3000/api/status
```

## Code Structure

The example has these source files:

### List the source files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme.sh#L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find src -type f | sort
```

### The source files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/test/integration/readme_output.txt#L134-L141"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
src/controllers/api_controller.gleam
src/main.gleam
src/middleware/rate_limit_middleware.gleam
src/router.gleam
src/services.gleam
src/services/rate_limiter_service.gleam
src/utilities/response_helpers.gleam
src/views/api_view.gleam
```

- `src/services/rate_limiter_service.gleam`: the rate limiter, backed by ETS.
- `src/middleware/rate_limit_middleware.gleam`: counts each request and answers `429` over the limit.
- `src/controllers/api_controller.gleam`: the API routes.

## Key Concepts

- **ETS-backed shared state** - Request counters stored in ETS tables created at startup
- **dream_ets integration** - Uses dream_ets config/operations helpers
- **Fixed Window** - Simple rate limiting algorithm (count requests in time window)
- **Middleware Integration** - Rate limiting happens before controllers run

## Important Pattern

The rate limiter service is created **once** at startup in `initialize_services` and stored in the `Services` struct. Middleware reuses that instance; it does **not** create new ETS tables on each request.

### Service initialization <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services.gleam#L17-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn initialize_services() -> Services {
  case create_rate_limiter() {
    Ok(limiter) -> Services(rate_limiter: limiter)
    Error(_) -> panic as "Could not initialize rate limiter service"
  }
}
```

This example shows how to implement global state management and rate limiting in Dream using ETS.

