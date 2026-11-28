//// Naming conventions: Module Namespace
////
//// The module name gives the namespace, so a function name does not repeat
//// it. `user` is the module in `snippets/naming_user`.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router
import snippets/naming_user.{type User} as user

pub fn show_user(id: Int) -> Result(User, Nil) {
  user.find(id)
}

pub fn app_router() {
  router.router()
  |> router.route(method: Get, path: "/", controller: index, middleware: [])
}

pub fn show_user_with_module_prefix(id: Int) -> Result(User, Nil) {
  user.user_find(id)
}

fn index(_request, _context, _services) {
  text_response(ok, "Home")
}
