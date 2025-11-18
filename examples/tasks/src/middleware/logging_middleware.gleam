//// Logging middleware - request/response logging

import context.{type TasksContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import gleam/int
import gleam/io
import services.{type Services}

pub fn logging_middleware(
  request: Request,
  context: TasksContext,
  services: Services,
  next: fn(Request, TasksContext, Services) -> Response,
) -> Response {
  // Log request
  io.println(request.path <> " → processing...")

  // Call next middleware/controller
  let response = next(request, context, services)

  // Log response
  io.println(request.path <> " → " <> int.to_string(response.status))

  response
}
