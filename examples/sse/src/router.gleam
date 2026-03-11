import controllers/sse_controller
import dream/http/request.{Get}
import dream/router.{route, router}

pub fn create() {
  router()
  |> route(Get, "/events", sse_controller.handle_events, [])
  |> route(Get, "/events/named", sse_controller.handle_named_events, [])
}
