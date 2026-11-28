import dream/http.{ok, text_response}
import dream/http/request.{Delete, Get, Post, Put}
import dream/router.{route, router}

pub fn user_router() {
  router()
  |> route(method: Get, path: "/users", controller: list_users, middleware: [])
  |> route(
    method: Post,
    path: "/users",
    controller: create_user,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/users/:id",
    controller: update_user,
    middleware: [],
  )
  |> route(
    method: Delete,
    path: "/users/:id",
    controller: delete_user,
    middleware: [],
  )
}

fn list_users(_request, _context, _services) {
  text_response(ok, "List users")
}

fn create_user(_request, _context, _services) {
  text_response(ok, "Create user")
}

fn update_user(_request, _context, _services) {
  text_response(ok, "Update user")
}

fn delete_user(_request, _context, _services) {
  text_response(ok, "Delete user")
}
