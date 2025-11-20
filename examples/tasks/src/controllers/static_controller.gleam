//// Static file serving controller

import context.{type TasksContext}
import dream/controllers/static
import dream/http.{type Request, type Response}
import dream/http/error
import dream/http/request.{get_param}
import services.{type Services}
import utilities/response_helpers

/// Serve static files from /public directory
pub fn serve_public(
  request: Request,
  context: TasksContext,
  services: Services,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config(),
      )
    Error(_) -> response_helpers.handle_error(
      error.BadRequest("File path required")
    )
  }
}
