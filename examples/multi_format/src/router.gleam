//// Router for multi-format example

import dream/core/http/transaction.{Get}
import dream/core/router.{type Router, route, router}
import context.{type AppContext}
import controllers/products_controller
import services.{type Services}

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(Get, "/products/:id", products_controller.show, [])
  |> route(Get, "/products", products_controller.index, [])
}
