//// Example for the doc of `request.set_params`.

import dream/http/request.{type Request, set_params}

pub fn with_user_id(request: Request) -> Request {
  // The new request has params [#("id", "42")]
  set_params(request, [#("id", "42")])
}
