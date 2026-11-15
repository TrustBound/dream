//// Dream vs raw Mist: path parameters with raw Mist
////
//// The handler parses the path by hand, and show_user has no way to reach a
//// database.

import gleam/bytes_tree
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/string
import mist.{type Connection, type ResponseData}

pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  case request.method, parse_user_path(request.path) {
    Get, Ok(id) -> show_user(id)
    _, _ -> not_found()
  }
}

fn parse_user_path(path: String) -> Result(Int, Nil) {
  case string.split(path, "/") {
    ["", "users", id_text] -> int.parse(id_text)
    _ -> Error(Nil)
  }
}

fn show_user(id: Int) -> Response(ResponseData) {
  // How does this function reach the database? A global? The process
  // dictionary? One more argument on every function in between?
  response.new(200)
  |> response.set_body(
    mist.Bytes(bytes_tree.from_string("User " <> int.to_string(id))),
  )
}

fn not_found() -> Response(ResponseData) {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
}
