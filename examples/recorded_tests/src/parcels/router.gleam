import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import parcels/parcels_controller
import parcels/services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/parcels/:code",
    controller: parcels_controller.show,
    middleware: [],
  )
}
