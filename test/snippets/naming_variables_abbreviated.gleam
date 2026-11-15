//// Naming conventions: abbreviated variable names (bad)

import dream/http.{type Request, type Response}
import gleam/result
import snippets/naming_variables.{type Services, find_user, respond_with_user}

pub fn show_user(req: Request, _ctx, svcs: Services) -> Response {
  let res = {
    use uid <- result.try(http.require_int(req, "id"))
    find_user(svcs.users, uid)
  }
  respond_with_user(res)
}
