//// Rate Limit Middleware
////
//// Middleware that enforces rate limits using the singleton-based rate limiter service.
//// Demonstrates practical use of services and middleware together.

import dream/core/context.{type AppContext}
import dream_helpers/statuses.{
  convert_client_error_to_status, ok_status, too_many_requests,
}
import dream/core/http/transaction.{
  type Request, type Response, Response, add_header, get_header,
}
import dream_helpers/http.{text_response}
import services.{type Services}
import services/rate_limiter_service
import gleam/int
import gleam/option
import gleam/string

/// Rate limiting middleware
/// Checks request rate for the client IP and enforces limits
pub fn rate_limit_middleware(
  request: Request,
  context: AppContext,
  services: Services,
  next: fn(Request, AppContext, Services) -> Response,
) -> Response {
  // Extract client IP from request
  // In a real application, you'd want to check X-Forwarded-For headers
  // For this example, we'll use a simple approach
  let ip = get_client_ip(request)

  // Check rate limit via singleton service
  case
    rate_limiter_service.check_and_increment(services.rate_limiter_name, ip)
  {
    Ok(rate_limiter_service.RateLimitStatus(allowed: True, remaining:, limit:)) -> {
      // Under limit - proceed with request
      let response = next(request, context, services)
      // Add rate limit headers to response
      let updated_headers =
        response.headers
        |> add_header("X-RateLimit-Limit", int.to_string(limit))
        |> add_header("X-RateLimit-Remaining", int.to_string(remaining))
      Response(..response, headers: updated_headers)
    }
    Ok(rate_limiter_service.RateLimitStatus(allowed: False, limit:, ..)) -> {
      // Rate limit exceeded
      let response =
        text_response(
          convert_client_error_to_status(too_many_requests()),
          "Rate limit exceeded. Maximum "
            <> int.to_string(limit)
            <> " requests per minute.",
        )
      let updated_headers =
        response.headers
        |> add_header("X-RateLimit-Limit", int.to_string(limit))
        |> add_header("X-RateLimit-Remaining", "0")
        |> add_header("Retry-After", "60")
      Response(..response, headers: updated_headers)
    }
    Ok(_) -> {
      // Unexpected reply type
      text_response(ok_status(), "Unexpected rate limiter response")
    }
    Error(_err) -> {
      // Service error - fail open (allow request but log error)
      // In production, you might want to fail closed instead
      next(request, context, services)
    }
  }
}

/// Extract client IP from request
/// In production, check X-Forwarded-For, X-Real-IP, etc.
fn get_client_ip(request: Request) -> String {
  // For now, use a combination of request path and a simple identifier
  // In a real app with proper connection info, you'd extract the actual IP
  case get_header(request.headers, "X-Forwarded-For") {
    option.Some(ip) ->
      // Take first IP if there are multiple (comma-separated)
      ip |> string.split(",") |> get_first_ip
    option.None ->
      // Fallback to a test identifier
      // For demo purposes, we'll use "demo-client"
      "demo-client"
  }
}

fn get_first_ip(ips: List(String)) -> String {
  case ips {
    [first, ..] -> string.trim(first)
    [] -> "unknown"
  }
}
