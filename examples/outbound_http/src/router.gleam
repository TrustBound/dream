import controllers/forecasts_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get, Post}
import dream/router.{type Router, route, router}
import services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/forecasts/:city",
    controller: forecasts_controller.show,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/forecasts/:city/hourly",
    controller: forecasts_controller.hourly,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/forecasts/:city/watches",
    controller: forecasts_controller.watch,
    middleware: [],
  )
}
