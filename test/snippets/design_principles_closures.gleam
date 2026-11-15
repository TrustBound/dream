//// Design principles: no closures
////
//// Two controllers that find a user name by id. The first one captures the
//// database in a closure. The second one gets it from Services.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, not_found, ok, require_string, text_response,
}
import dream/router.{type EmptyServices}
import gleam/list
import gleam/result

pub type Database {
  Database(user_names_by_id: List(#(String, String)))
}

pub type Services {
  Services(database: Database)
}

pub fn create_controller(
  database: Database,
) -> fn(Request, EmptyContext, EmptyServices) -> Response {
  fn(request, _context, _services) {
    // database is captured: the controller's type does not show it
    show_user_name(database, request)
  }
}

pub fn controller(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let database = services.database
  show_user_name(database, request)
}

fn show_user_name(database: Database, request: Request) -> Response {
  let user_name = {
    use id <- result.try(
      require_string(request, "id") |> result.replace_error(Nil),
    )
    list.key_find(database.user_names_by_id, id)
  }
  case user_name {
    Ok(name) -> text_response(ok, name)
    Error(Nil) -> text_response(not_found, "User not found")
  }
}
