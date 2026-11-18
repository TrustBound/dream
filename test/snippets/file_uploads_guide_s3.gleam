import dream_http_client/client.{
  type ClientRequest, type SendError, add_header, body, host, method, path,
  scheme, send,
}
import gleam/http
import gleam/result

pub fn save_to_s3(
  s3_client: ClientRequest,
  filename: String,
  content: String,
) -> Result(String, SendError) {
  // Pass client.new() as s3_client, or a client with a recorder in tests.
  // For clarity, we build the URL parts directly.
  // If you need true binary uploads, consider base64 encoding the payload or
  // using a client that supports binary request bodies.
  let s3_host = "s3.amazonaws.com"
  let s3_path = "/bucket/" <> filename

  s3_client
  |> method(http.Put)
  |> scheme(http.Https)
  |> host(s3_host)
  |> path(s3_path)
  |> add_header("Content-Type", "application/octet-stream")
  |> body(content)
  |> send()
  |> result.map(fn(_body) { filename })
}
