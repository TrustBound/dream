import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import links/services.{type Services}
import links/share_controller

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/items/:id/share",
    controller: share_controller.share,
    middleware: [],
  )
}
