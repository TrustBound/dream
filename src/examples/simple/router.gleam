import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{
  type Router, add_route, handler, method, new as route, path, router,
}
import examples/simple/controllers/posts_controller

pub fn create_router() -> Router(AppContext) {
  router
  |> add_route(
    route
    |> method(Get)
    |> path("/")
    |> handler(posts_controller.index),
  )
  |> add_route(
    route
    |> method(Get)
    |> path("/users/:id/posts/:post_id")
    |> handler(posts_controller.show),
  )
}
