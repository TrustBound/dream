import dream_http_client/client.{
  type HttpResponse, type SendError, connect_timeout, host, path, port, scheme,
  send,
}
import gleam/http

pub fn fast_timeout() -> Result(HttpResponse, SendError) {
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> connect_timeout(5000)
  |> send()
}
