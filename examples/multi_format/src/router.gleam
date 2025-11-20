//// Router for multi-format example

import context.{type AppContext}
import controllers/products_controller
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import services.{type Services}

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(Get, "/products/:id", products_controller.show, [])
  |> route(Get, "/products", products_controller.index, [])
}
