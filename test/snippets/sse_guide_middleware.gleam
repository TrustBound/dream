//// SSE guide: middleware
////
//// A router that adds a CORS header to the SSE response, as shown in
//// docs/guides/sse.md.

import dream/http/header.{Header}
import dream/http/request.{Get}
import dream/http/response.{Response}
import dream/router.{route, router}
import snippets/sse_guide_controller as sse_controller

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/events",
    controller: sse_controller.handle_events,
    middleware: [cors_middleware],
  )
}

fn cors_middleware(request, context, services, next) {
  let response = next(request, context, services)
  Response(..response, headers: [
    Header("Access-Control-Allow-Origin", "*"),
    ..response.headers
  ])
}
