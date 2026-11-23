//// Doc comment example: dream/servers/mist/server.listen_with_handle

import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server
import dream_http_client/client
import gleam/http
import gleam/result

pub fn test_server(port: Int) -> Result(String, String) {
  // Start server and get handle
  let started =
    server.new()
    |> server.router(test_router())
    |> server.listen_with_handle(port)

  case started {
    Ok(handle) -> {
      // Make test requests
      let response =
        client.new()
        |> client.scheme(http.Http)
        |> client.host("localhost")
        |> client.port(port)
        |> client.path("/test")
        |> client.send()

      // Stop the server
      server.stop(handle)
      response_body(response)
    }
    Error(_start_error) -> Error("server did not start")
  }
}

fn response_body(
  response: Result(client.HttpResponse, client.SendError),
) -> Result(String, String) {
  case response {
    Ok(response) ->
      client.body_text(response)
      |> result.replace_error("the body is not text")
    Error(_send_error) -> Error("request failed")
  }
}

fn test_router() {
  router()
  |> route(method: Get, path: "/test", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(status.ok, "test passed")
}
