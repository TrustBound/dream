//// The users controller that the testing guide's controller test tests.

import dream/context.{type AppContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, json_response}
import dream/http/status.{ok}
import dream/router.{type EmptyServices}

pub fn index(
  _request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  json_response(ok, "[{\"id\":1,\"name\":\"Alice\"}]")
}
