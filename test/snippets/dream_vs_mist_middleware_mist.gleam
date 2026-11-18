//// Dream vs raw Mist: authentication with raw Mist
////
//// One handler checks the token for every route, public or not, and passes
//// the user to each route handler by hand.

import gleam/bytes_tree
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/result
import mist.{type Connection, type ResponseData}

pub type User {
  User(name: String)
}

pub fn handle_request(request: Request(Connection)) -> Response(ResponseData) {
  // Every request needs a token, so no route can be public
  case authenticate(request) {
    Ok(user) -> handle_route(request, user)
    Error(Nil) -> send_text(401, "Unauthorized")
  }
}

fn authenticate(request: Request(Connection)) -> Result(User, Nil) {
  use token <- result.try(request.get_header(request, "authorization"))
  verify_token(token)
}

fn verify_token(token: String) -> Result(User, Nil) {
  case token {
    "Bearer secret-token" -> Ok(User(name: "Ada"))
    _ -> Error(Nil)
  }
}

fn handle_route(
  request: Request(Connection),
  user: User,
) -> Response(ResponseData) {
  case request.method, request.path {
    Get, "/" -> show_home(user)
    Post, "/posts" -> create_post(request, user)
    _, _ -> send_text(404, "Not Found")
  }
}

fn show_home(user: User) -> Response(ResponseData) {
  send_text(200, "Welcome, " <> user.name)
}

fn create_post(
  _request: Request(Connection),
  user: User,
) -> Response(ResponseData) {
  send_text(201, "Post created by " <> user.name)
}

fn send_text(status: Int, text: String) -> Response(ResponseData) {
  response.new(status)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(text)))
}
