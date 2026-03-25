import dream_http_client/client.{
  type HttpResponse, type SendError, auto_redirect, host, path, port, scheme,
  send,
}
import gleam/http

pub fn no_auto_redirect() -> Result(HttpResponse, SendError) {
  client.new()
  |> scheme(http.Http)
  |> host("localhost")
  |> port(9876)
  |> path("/text")
  |> auto_redirect(False)
  |> send()
}
