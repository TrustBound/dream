import dream/http/request.{type Request, get_int_param}
import dream/http/response.{type Response}
import dream/http/status

pub type Services {
  Services(delete_user: fn(Int) -> Nil)
}

pub fn delete_user(request: Request, _context, services: Services) -> Response {
  case get_int_param(request, "id") {
    Ok(user_id) -> {
      // After successful deletion, return 204 with no body
      services.delete_user(user_id)
      response.empty_response(status.no_content)
    }
    Error(message) -> response.text_response(status.bad_request, message)
  }
}
