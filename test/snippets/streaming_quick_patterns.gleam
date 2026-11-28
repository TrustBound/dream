//// Streaming quick reference: response patterns
////
//// A proxy stream, a large CSV export and a controller that streams only
//// one of its formats, as shown in the Recipes section of docs/reference/streaming-api.md.

import dream/http/request.{type Request, get_query_param}
import dream/http/response.{
  type Response, json_response, stream_response, text_response,
}
import dream/http/status
import gleam/bit_array
import gleam/int
import gleam/json
import gleam/option.{Some}
import gleam/result
import gleam/yielder

pub fn proxy(_request: Request, _context, _services) -> Response {
  // Simulate proxying from external API
  let stream =
    yielder.from_list(["Chunk 1\n", "Chunk 2\n", "Chunk 3\n"])
    |> yielder.map(bit_array.from_string)

  stream_response(status.ok, stream, "text/plain")
}

pub type User {
  User(id: Int, name: String, email: String)
}

pub type Services {
  Services(list_users: fn() -> Result(List(User), String))
}

pub fn export_users(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  case services.list_users() {
    Ok(users) -> {
      let header = yielder.single(<<"id,name,email\n":utf8>>)
      let rows =
        yielder.from_list(users)
        |> yielder.map(user_to_csv_row)
        |> yielder.map(bit_array.from_string)

      let csv_stream = yielder.append(header, rows)

      stream_response(status.ok, csv_stream, "text/csv")
    }
    Error(_reason) ->
      text_response(status.internal_server_error, "Could not load users")
  }
}

fn user_to_csv_row(user: User) -> String {
  int.to_string(user.id) <> "," <> user.name <> "," <> user.email <> "\n"
}

pub fn get_users(request: Request, context, services: Services) -> Response {
  let format = get_query_param(request.query, "format")

  case format {
    Some("csv") -> export_users(request, context, services)
    Some("json") -> export_users_json(services)
    _ -> text_response(status.bad_request, "Use ?format=csv or ?format=json")
  }
}

fn export_users_json(services: Services) -> Response {
  services.list_users()
  |> result.map(users_to_json)
  |> result.map(json_response(status.ok, _))
  |> result.lazy_unwrap(fn() {
    text_response(status.internal_server_error, "Could not load users")
  })
}

fn users_to_json(users: List(User)) -> String {
  json.array(users, user_to_json)
  |> json.to_string()
}

fn user_to_json(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
}
