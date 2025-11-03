import dream/core/http/transaction.{Get}
import dream/core/router.{type Router, Route, Router, add_route, middleware}
import examples/custom_context/context.{type AuthContext}
import examples/custom_context/controllers/posts_controller
import examples/custom_context/middleware/auth_middleware.{auth_middleware}

pub fn create_router() -> Router(AuthContext) {
  Router(routes: [])
  |> add_route(
    Route(
      method: Get,
      path: "/",
      handler: posts_controller.index,
      middleware: [],
    ),
  )
  |> add_route(
    Route(
      method: Get,
      path: "/users/:id/posts/:post_id",
      handler: posts_controller.show,
      middleware: [],
    )
    |> middleware([auth_middleware]),
  )
}
