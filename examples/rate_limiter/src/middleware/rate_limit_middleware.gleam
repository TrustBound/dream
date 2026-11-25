//// Counts each request of a client, and answers `429 Too Many Requests`
//// with a `Retry-After` header over the limit.

import clock
import dream/context.{type EmptyContext}
import dream/http/header.{add_header, get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response, text_response}
import dream/http/status
import gleam/int
import gleam/option
import gleam/string
import services.{type Services}
import services/rate_limiter_service.{Allowed, Denied, StoreFailed}

pub fn rate_limit_middleware(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let client = identify_client(request)
  let now = clock.read_time(services.clock)
  case rate_limiter_service.count_request(services.rate_limiter, client, now) {
    Ok(Allowed(limit:, remaining:)) ->
      next(request, context, services)
      |> add_rate_limit_headers(limit, remaining)
    Ok(Denied(limit:, retry_after_seconds:)) ->
      deny_request(limit, retry_after_seconds)
    Error(StoreFailed(reason:)) ->
      text_response(
        status.service_unavailable,
        "The rate limit store failed: " <> reason,
      )
  }
}

fn deny_request(limit: Int, retry_after_seconds: Int) -> Response {
  let response =
    text_response(
      status.too_many_requests,
      "Rate limit exceeded. Maximum "
        <> int.to_string(limit)
        <> " requests per minute.",
    )
    |> add_rate_limit_headers(limit, 0)
  Response(
    ..response,
    headers: add_header(
      response.headers,
      "Retry-After",
      int.to_string(retry_after_seconds),
    ),
  )
}

fn add_rate_limit_headers(
  response: Response,
  limit: Int,
  remaining: Int,
) -> Response {
  let headers =
    response.headers
    |> add_header("X-RateLimit-Limit", int.to_string(limit))
    |> add_header("X-RateLimit-Remaining", int.to_string(remaining))
  Response(..response, headers:)
}

/// The first address of `X-Forwarded-For`, or the address of the
/// connection. Trust `X-Forwarded-For` only behind your own proxy: a client
/// can send any value in it.
fn identify_client(request: Request) -> String {
  case get_header(request.headers, "X-Forwarded-For") {
    option.Some(forwarded_for) -> first_address(forwarded_for)
    option.None -> option.unwrap(request.remote_address, "unknown")
  }
}

fn first_address(forwarded_for: String) -> String {
  case string.split(forwarded_for, ",") {
    [first, ..] -> string.trim(first)
    [] -> forwarded_for
  }
}
