//// Architecture reference: why no closures
////
//// Two controllers that return the same answer. The first one hides the
//// database in a closure. The second one gets it from Services.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, ok, text_response}
import dream/router.{type EmptyServices}
import gleam/int
import gleam/list

pub type Database {
  Database(user_names: List(String))
}

pub type Services {
  Services(database: Database)
}

// Bad: the closure hides the database
pub fn create_handler(
  database: Database,
) -> fn(Request, EmptyContext, EmptyServices) -> Response {
  fn(_request, _context, _services) { count_users(database) }
}

// Good: the database comes in as a parameter
pub fn handle_request(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let database = services.database
  count_users(database)
}

fn count_users(database: Database) -> Response {
  let count = list.length(database.user_names)
  text_response(ok, int.to_string(count))
}
