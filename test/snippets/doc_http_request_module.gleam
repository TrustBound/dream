import dream/http/request.{type Request, get_int_param}
import dream/http/response.{json_response, text_response}
import dream/http/status
import gleam/json
import gleam/result

pub fn show_user(request: Request, _context, services: Services) {
  let result = {
    use id <- result.try(get_int_param(request, "id"))
    services.find_user(id)
  }

  case result {
    Ok(user) -> json_response(status.ok, user_to_json(user))
    Error(message) -> text_response(status.bad_request, message)
  }
}

pub type Services {
  Services(find_user: fn(Int) -> Result(String, String))
}

fn user_to_json(name: String) -> String {
  json.to_string(json.object([#("name", json.string(name))]))
}
