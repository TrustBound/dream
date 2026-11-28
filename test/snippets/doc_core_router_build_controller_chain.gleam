//// Example for the doc of `router.build_controller_chain`.

import dream/http/request.{type Request}
import dream/http/response.{type Response, Text, text_response}
import dream/http/status.{ok}
import dream/router.{type Middleware, Middleware, build_controller_chain}

fn controller(_request: Request, _context, _services) -> Response {
  text_response(ok, "controller")
}

fn wrap(label: String) -> Middleware(context, services) {
  Middleware(fn(request, context, services, next) {
    let response = next(request, context, services)
    case response.body {
      Text(body) -> text_response(response.status, label <> "(" <> body <> ")")
      _ -> response
    }
  })
}

pub fn handle(request: Request) -> Response {
  let chain = build_controller_chain([wrap("outer"), wrap("inner")], controller)
  // The first middleware is the outermost: "outer(inner(controller))"
  chain(request, Nil, Nil)
}
