//// Streaming guide: CSV export patterns
////
//// User CSV exports, buffered and streamed, as shown in the "Common Patterns"
//// and "Performance Considerations" sections of docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/yielder.{type Yielder}

pub type User {
  User(id: Int, name: String, email: String)
}

pub type Services {
  Services(list_users: fn() -> Result(List(User), String))
}

pub fn export_users_csv(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  services.list_users()
  |> result.map(yielder.from_list)
  |> result.map(users_to_csv_stream)
  |> result.map(create_csv_stream_response)
  |> result.lazy_unwrap(create_error_response)
}

fn users_to_csv_stream(users: Yielder(User)) -> Yielder(BitArray) {
  users
  |> yielder.map(user_to_csv_row)
  |> yielder.prepend("id,name,email\n")
  |> yielder.map(bit_array.from_string)
}

fn create_csv_stream_response(stream: Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}

fn create_error_response() -> Response {
  text_response(status.internal_server_error, "Could not load users")
}

fn user_to_csv_row(user: User) -> String {
  int.to_string(user.id) <> "," <> user.name <> "," <> user.email <> "\n"
}

// BAD for large exports: the whole CSV is one string in memory
pub fn export_users_buffered(users: List(User)) -> Response {
  let csv =
    string.concat(["id,name,email\n", ..list.map(users, user_to_csv_row)])
  text_response(status.ok, csv)
}

// GOOD for large exports: each row is made when the client reads it
pub fn export_users_streamed(users: Yielder(User)) -> Response {
  let csv_stream = users_to_csv_stream(users)
  stream_response(status.ok, csv_stream, "text/csv")
}
