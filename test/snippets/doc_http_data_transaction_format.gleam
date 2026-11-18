import dream/http/transaction.{type PathParam, type Request, get_param}
import gleam/option

pub fn describe_id(request: Request) -> String {
  // Request to /users/123.json
  let result = get_param(request, "id")

  case result {
    Ok(param) -> {
      // param.value is "123"
      // param.format is Some("json")
      // param.as_int is Ok(123)
      use_param_data(param)
    }
    Error(message) -> handle_param_error(message)
  }
}

fn use_param_data(param: PathParam) -> String {
  param.value <> " as " <> option.unwrap(param.format, "html")
}

fn handle_param_error(message: String) -> String {
  "Error: " <> message
}
