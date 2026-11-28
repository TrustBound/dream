//// SSE guide: the router
////
//// A router that sends GET /events to the SSE controller, as shown in
//// docs/guides/sse.md.

import dream/http/request.{Get}
import dream/router.{route, router}
import snippets/sse_guide_controller as sse_controller

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/events",
    controller: sse_controller.handle_events,
    middleware: [],
  )
}
