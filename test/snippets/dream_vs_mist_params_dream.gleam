import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, json_response, ok, require_int, text_response,
}
import dream/http/error.{type Error, NotFound}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server
import gleam/json
import gleam/list
import gleam/result

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(users: List(User))
}

pub fn show_user(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user_result = {
    use id <- result.try(require_int(request, "id"))
    find_user(services.users, id)
  }

  case user_result {
    Ok(user) -> json_response(ok, user_to_json(user))
    Error(http_error) ->
      text_response(error.to_status_code(http_error), error.message(http_error))
  }
}

fn find_user(users: List(User), id: Int) -> Result(User, Error) {
  list.find(users, fn(user) { user.id == id })
  |> result.replace_error(NotFound("User not found"))
}

fn user_to_json(user: User) -> String {
  json.object([#("id", json.int(user.id)), #("name", json.string(user.name))])
  |> json.to_string()
}

pub fn initialize_services() -> Services {
  Services(users: [User(id: 1, name: "Ada")])
}

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/users/:id",
    controller: show_user,
    middleware: [],
  )
}

pub fn main() {
  server.new()
  |> server.services(initialize_services())
  |> server.router(create_router())
  |> server.listen(3000)
}
