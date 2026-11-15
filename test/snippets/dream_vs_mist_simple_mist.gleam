import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import mist.{type Connection, type ResponseData}

pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  case mist.read_body(request, max_body_limit: 1_000_000) {
    Ok(request_with_body) -> route_request(request_with_body)
    Error(_read_error) ->
      response.new(400)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}

fn route_request(request: Request(BitArray)) -> Response(ResponseData) {
  case request.method, request.path {
    Get, "/" ->
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello, World!")))
      |> response.set_header("content-type", "text/plain")
    _, _ ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
  }
}

pub fn main() {
  let started =
    mist.new(handle_request)
    |> mist.port(3000)
    |> mist.start()

  case started {
    Ok(_server) -> process.sleep_forever()
    Error(_start_error) -> io.println("The server did not start")
  }
}
