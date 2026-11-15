//// Naming conventions: variable names that are too long (bad)

import dream/http.{type Request, type Response}
import gleam/result
import snippets/naming_variables.{type Services, find_user, respond_with_user}

pub fn show_user(
  incoming_http_request: Request,
  _request_context_value,
  application_services_record: Services,
) -> Response {
  let user_lookup_result_from_services = {
    use user_identifier_from_path_parameters <- result.try(http.require_int(
      incoming_http_request,
      "id",
    ))
    find_user(
      application_services_record.users,
      user_identifier_from_path_parameters,
    )
  }
  // When you get the message, hang up!
  respond_with_user(user_lookup_result_from_services)
}
