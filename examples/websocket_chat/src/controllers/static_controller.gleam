import dream/context.{type EmptyContext}
import dream/controllers/static
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, html_response}
import dream/http/status
import services.{type Services}

/// Serve static assets (CSS, JS, etc.)
pub fn serve_assets(
  request: Request,
  context: EmptyContext,
  services: Services,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./assets",
        filepath: param.raw,
        config: static.default_config() |> static.without_index(),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}
