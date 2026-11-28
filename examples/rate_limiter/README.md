# Rate Limiter Example

A rate limit for each client: 10 requests in a window of 60 seconds, counted in ETS tables with [`dream_ets`](https://hexdocs.pm/dream_ets/3.0.0/). The guide [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html) explains each part.

## What This Demonstrates

- **A table owner** - one process makes the ETS tables at startup and lives as long as the app
- **Services pattern** - the rate limiter and the clock are in the `Services` record
- **Atomic counts** - each request adds to its count with `helpers.increment` of dream_ets, one atomic ETS step
- **Route middleware** - a `429` answer with a `Retry-After` header over the limit
- **Rate limit headers** - `X-RateLimit-Limit` and `X-RateLimit-Remaining` in each answer
- **Tests that control time** - the tests give the app a fixed clock, and never sleep

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
src/clock.gleam
src/controllers/api_controller.gleam
src/main.gleam
src/middleware/rate_limit_middleware.gleam
src/router.gleam
src/services.gleam
src/services/rate_limiter_service.gleam
src/views/api_view.gleam
```

- `src/services/rate_limiter_service.gleam`: the rate limit. It decides from the count and the start of the window.
- `src/services.gleam`: the process that owns the tables and deletes the rows of ended windows.
- `src/middleware/rate_limit_middleware.gleam`: counts each request and answers `429` over the limit.
- `src/clock.gleam`: the clock of the app. The tests give a fixed time.

## Important Pattern

The services start **once**, in `main`. `start_services` starts the process that owns the tables, and waits for the services that it makes. A request never makes a table: a table goes away when the process that made it ends.

### Start the services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/rate_limiter/src/services.gleam#L31-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn start_services(
  table_name: String,
  config: RateLimitConfig,
  clock: Clock,
) -> Result(Services, String) {
  let reply = process.new_subject()
  process.spawn(fn() { own_tables(table_name, config, clock, reply) })
  process.receive(reply, within: 5000)
  |> result.replace_error("The table owner did not start in 5 seconds")
  |> result.flatten
}
```

## Tests

`make test` runs `gleam test`. The unit tests send requests through the routes with a fixed clock. `make test-integration` starts the server and runs the Cucumber scenarios over HTTP/1.1 and HTTP/2.
