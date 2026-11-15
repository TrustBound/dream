//// Example for the `dream/context` module doc: middleware that adds the user
//// to the context.

import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response, text_response}
import dream/http/status.{unauthorized}
import gleam/option.{Some}

pub fn auth_middleware(
  request: Request,
  context: MyContext,
  services: Services,
  next: fn(Request, MyContext, Services) -> Response,
) -> Response {
  case extract_token(request) {
    Ok(token) -> {
      let user = verify_token(services.database, token)
      let new_context = MyContext(..context, user: Some(user))
      next(request, new_context, services)
    }
    Error(_) -> text_response(unauthorized, "Authentication required")
  }
}

pub type MyContext {
  MyContext(request_id: String, user: option.Option(User))
}

pub type User {
  User(name: String)
}

pub type Database {
  Database(valid_token: String, token_user: User)
}

pub type Services {
  Services(database: Database)
}

fn extract_token(request: Request) -> Result(String, Nil) {
  option.to_result(get_header(request.headers, "Authorization"), Nil)
}

fn verify_token(database: Database, token: String) -> User {
  case token == database.valid_token {
    True -> database.token_user
    False -> User(name: "guest")
  }
}
