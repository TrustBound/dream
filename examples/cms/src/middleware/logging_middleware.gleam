//// Logging Middleware
////
//// Logs all requests to OpenSearch as events.
//// Demonstrates middleware that coordinates with services.

import context.{type Context}
import dream/core/http/transaction.{
  type Method, type Request, type Response, Delete, Get, Head, Options, Patch,
  Post, Put,
}
import dream_helpers/statuses.{type Status}
import gleam/int
import gleam/option
import models/event/event as event_model
import services.{type Services}
import types/event.{type Event, Event, RequestCompleted}

pub fn logging_middleware(
  request: Request,
  ctx: Context,
  services: Services,
  next: fn(Request, Context, Services) -> Response,
) -> Response {
  // Note: Using simple timestamp - in production use proper timing
  let response = next(request, ctx, services)
  let duration_ms = 0  // Simplified for demo
  
  let log_event = create_request_event(request, response, duration_ms)
  let _ = event_model.log(services.opensearch, log_event)
  
  response
}

fn create_request_event(
  request: Request,
  response: Response,
  duration_ms: Int,
) -> Event {
  Event(
    id: generate_event_id(request.path, extract_status_code(response.status)),
    event_type: RequestCompleted,
    user_id: option.None,
    post_id: option.None,
    method: method_to_string(request.method),
    path: request.path,
    status_code: extract_status_code(response.status),
    duration_ms: duration_ms,
    timestamp: get_current_timestamp(),
  )
}

fn generate_event_id(path: String, status: Int) -> String {
  "request-" <> path <> "-" <> int.to_string(status)
}

fn method_to_string(method: Method) -> String {
  case method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Options -> "OPTIONS"
    Head -> "HEAD"
  }
}

fn extract_status_code(status: Int) -> Int {
  status
}

fn get_current_timestamp() -> String {
  "2024-01-01T00:00:00Z"
}

