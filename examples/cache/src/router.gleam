//// The routes of the shop

import dream/context.{type EmptyContext}
import dream/http/request.{Get, Put}
import dream/router.{type Router, route, router}
import products_controller
import services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/products/:id",
    controller: products_controller.show,
    middleware: [],
  )
  |> route(
    method: Put,
    path: "/products/:id",
    controller: products_controller.update,
    middleware: [],
  )
}
