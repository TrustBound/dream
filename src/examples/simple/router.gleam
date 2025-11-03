import dream/core/http/transaction.{Get}
import dream/core/router.{
  type Router, add_route, handler, method, new as route, path, router,
}
import examples/simple/controllers/simple_controller

pub fn create_router() -> Router {
  router
  |> add_route(
    route
    |> method(Get)
    |> path("/")
    |> handler(simple_controller.index),
  )
  |> add_route(
    route
    |> method(Get)
    |> path("/users/:id/posts/:post_id")
    |> handler(simple_controller.show),
  )
  |> add_route(
    route
    |> method(Get)
    |> path("/fetch")
    |> handler(simple_controller.fetch),
  )
}
