//// Naming conventions: variable names that are full words and short

import dream/http.{type Request, type Response}
import gleam/result
import snippets/naming_variables.{type Services, find_user, respond_with_user}

pub fn show_user(request: Request, _context, services: Services) -> Response {
  let user_result = {
    use user_id <- result.try(http.require_int(request, "id"))
    find_user(services.users, user_id)
  }
  respond_with_user(user_result)
}
