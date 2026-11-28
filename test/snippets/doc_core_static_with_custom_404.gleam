//// Example for the doc of `static.with_custom_404`.

import dream/controllers/static.{default_config, serve, with_custom_404}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status.{not_found}

fn missing_file(_request: Request, _context, _services) -> Response {
  text_response(not_found, "No such file")
}

pub fn download(request: Request, filepath: String) -> Response {
  let config =
    default_config()
    |> with_custom_404(missing_file)
  // A file that is not in ./downloads gets the "No such file" response
  serve(
    request: request,
    context: Nil,
    services: Nil,
    root: "./downloads",
    filepath: filepath,
    config: config,
  )
}
