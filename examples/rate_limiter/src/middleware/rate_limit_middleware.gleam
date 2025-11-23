//// Rate Limit Middleware
////
//// Middleware that enforces rate limits using dream_ets.
//// Demonstrates practical use of services and middleware together.

import dream/context.{type EmptyContext}
import dream/http/header.{add_header, get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response, text_response}
import dream/http/status
import gleam/int
import gleam/option
import gleam/string
import services.{type Services}
import services/rate_limiter_service

/// Rate limiting middleware
/// Checks request rate for the client IP and enforces limits
pub fn rate_limit_middleware(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let ip = get_client_ip(request)

  case rate_limiter_service.check_and_increment(services.rate_limiter, ip) {
    Ok(status) ->
      handle_rate_limit_result(status, request, context, services, next)
    Error(_) -> handle_service_error(request, context, services, next)
  }
}

fn handle_rate_limit_result(
  status: rate_limiter_service.RateLimitStatus,
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let rate_limiter_service.RateLimitStatus(allowed, remaining, limit) = status

  case allowed {
    True ->
      allow_request_with_headers(
        request,
        context,
        services,
        next,
        remaining,
        limit,
      )
    False -> deny_request_with_headers(limit)
  }
}

fn allow_request_with_headers(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
  remaining: Int,
  limit: Int,
) -> Response {
  let response = next(request, context, services)
  add_rate_limit_headers(response, limit, remaining)
}

fn deny_request_with_headers(limit: Int) -> Response {
  let response =
    text_response(
      status.too_many_requests,
      "Rate limit exceeded. Maximum "
        <> int.to_string(limit)
        <> " requests per minute.",
    )

  response
  |> add_rate_limit_headers(limit, 0)
  |> add_retry_after_header
}

fn add_rate_limit_headers(
  response: Response,
  limit: Int,
  remaining: Int,
) -> Response {
  let updated_headers =
    response.headers
    |> add_header("X-RateLimit-Limit", int.to_string(limit))
    |> add_header("X-RateLimit-Remaining", int.to_string(remaining))

  Response(..response, headers: updated_headers)
}

fn add_retry_after_header(response: Response) -> Response {
  let updated_headers = response.headers |> add_header("Retry-After", "60")
  Response(..response, headers: updated_headers)
}

fn handle_service_error(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  // Service error - fail open (allow request)
  // In production, you might want to fail closed instead
  next(request, context, services)
}

/// Extract client IP from request
fn get_client_ip(request: Request) -> String {
  case get_header(request.headers, "X-Forwarded-For") {
    option.Some(ip) -> extract_first_ip(ip)
    option.None -> "demo-client"
  }
}

fn extract_first_ip(forwarded_for: String) -> String {
  case string.split(forwarded_for, ",") {
    [first, ..] -> string.trim(first)
    [] -> "unknown"
  }
}
