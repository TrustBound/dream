import dream/http.{type Request, type Response, method_to_string}
import gleam/io
import gleam/json

pub fn log_request(request: Request, response: Response, duration_ms: Int) {
  format_request_line(request, response, duration_ms)
  |> io.println
}

pub fn format_request_line(
  request: Request,
  response: Response,
  duration_ms: Int,
) -> String {
  json.object([
    #("type", json.string("request")),
    #("method", json.string(method_to_string(request.method))),
    #("path", json.string(request.path)),
    #("status", json.int(response.status)),
    #("duration_ms", json.int(duration_ms)),
  ])
  |> json.to_string
}
