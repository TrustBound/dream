Request 1:
HTTP/1.1 200 OK
x-ratelimit-remaining: 9
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 2:
HTTP/1.1 200 OK
x-ratelimit-remaining: 8
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 3:
HTTP/1.1 200 OK
x-ratelimit-remaining: 7
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 4:
HTTP/1.1 200 OK
x-ratelimit-remaining: 6
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 5:
HTTP/1.1 200 OK
x-ratelimit-remaining: 5
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 6:
HTTP/1.1 200 OK
x-ratelimit-remaining: 4
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 7:
HTTP/1.1 200 OK
x-ratelimit-remaining: 3
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 8:
HTTP/1.1 200 OK
x-ratelimit-remaining: 2
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

Request 9:
HTTP/1.1 200 OK
x-ratelimit-remaining: 1
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 127

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

Request 12:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8

Request 13:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8

Request 14:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8

Request 15:
HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8

Welcome to the Rate Limiter Example!

Endpoints:
  GET /      - This welcome page (no rate limit)
  GET /api   - Rate-limited API endpoint
  GET /api/status - Rate limit status (also rate-limited)

The rate limiter uses ETS-backed shared state (via dream_ets)
to track requests across all clients. Try making multiple
rapid requests to /api to see it in action!HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 52
date: (the time of the request)
connection: keep-alive

Rate limit exceeded. Maximum 10 requests per minute.HTTP/1.1 429 Too Many Requests
retry-after: 60
x-ratelimit-remaining: 0
x-ratelimit-limit: 10
content-type: text/plain; charset=utf-8
content-length: 52
date: (the time of the request)
connection: keep-alive

Rate limit exceeded. Maximum 10 requests per minute.
src/controllers/api_controller.gleam
src/main.gleam
src/middleware/rate_limit_middleware.gleam
src/router.gleam
src/services.gleam
src/services/rate_limiter_service.gleam
src/utilities/response_helpers.gleam
src/views/api_view.gleam
