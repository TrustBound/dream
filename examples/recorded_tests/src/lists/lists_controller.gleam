//// The routes of the lists app. Each controller takes the connection from
//// services, and gives it to the model.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_int, require_json}
import dream/http/error
import dream/http/response.{json_response}
import dream/http/status
import gleam/dynamic/decode
import gleam/int
import gleam/json
import lists/list_model.{
  type ListError, type ShoppingList, ItemTooLong, NoSuchList, QueryFailed,
}
import lists/services.{type Services}

/// GET /lists: the id and the name of each list.
pub fn index(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case list_model.all(services.database) {
    Ok(lists) ->
      json_response(
        status.ok,
        json.array(lists, fn(pair) {
          json.object([
            #("id", json.int(pair.0)),
            #("name", json.string(pair.1)),
          ])
        })
          |> json.to_string,
      )
    Error(list_error) -> error_response(list_error)
  }
}

/// POST /lists: creates a list and its items, from
/// `{"name": "...", "items": ["...", ...]}`.
pub fn create(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_json(request, new_list_decoder()) {
    Error(request_error) -> bad_request(request_error)
    Ok(#(name, items)) ->
      case list_model.create(services.database, name, items) {
        Ok(shopping_list) ->
          json_response(status.created, list_json(shopping_list))
        Error(list_error) -> error_response(list_error)
      }
  }
}

/// GET /lists/:id: a list and its items.
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_int(request, "id") {
    Error(request_error) -> bad_request(request_error)
    Ok(id) ->
      case list_model.get(services.database, id) {
        Ok(shopping_list) -> json_response(status.ok, list_json(shopping_list))
        Error(list_error) -> error_response(list_error)
      }
  }
}

/// GET /lists/:id/share: the link that shares a list.
pub fn share(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_int(request, "id") {
    Error(request_error) -> bad_request(request_error)
    Ok(id) ->
      case list_model.share_token(services.database, id) {
        Ok(token) ->
          json_response(
            status.ok,
            json.object([#("url", json.string("/shared/" <> token))])
              |> json.to_string,
          )
        Error(list_error) -> error_response(list_error)
      }
  }
}

fn new_list_decoder() -> decode.Decoder(#(String, List(String))) {
  use name <- decode.field("name", decode.string)
  use items <- decode.field("items", decode.list(decode.string))
  decode.success(#(name, items))
}

fn list_json(shopping_list: ShoppingList) -> String {
  json.object([
    #("id", json.int(shopping_list.id)),
    #("name", json.string(shopping_list.name)),
    #("items", json.array(shopping_list.items, json.string)),
  ])
  |> json.to_string
}

// The cause of a failed query stays in the server: the client gets a 500
// with no SQL in it
fn error_response(list_error: ListError) -> Response {
  case list_error {
    NoSuchList(id:) ->
      json_response(
        status.not_found,
        error_json("No list " <> int.to_string(id)),
      )
    ItemTooLong ->
      json_response(
        status.unprocessable_content,
        error_json("Each item needs 1 to 40 characters"),
      )
    QueryFailed(_) ->
      json_response(status.internal_server_error, error_json("Database error"))
  }
}

fn bad_request(request_error: error.Error) -> Response {
  json_response(status.bad_request, error_json(error.message(request_error)))
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))]) |> json.to_string
}
