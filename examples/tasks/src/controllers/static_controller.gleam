//// Static file serving controller

import context.{type TasksContext}
import dream/controllers/static
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response}
import services.{type Services}

/// Serve static files from /public directory
pub fn serve_public(
  request: Request,
  context: TasksContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "filepath")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public",
    filepath: param.raw,
    config: static.default_config(),
  )
}

