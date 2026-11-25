import controllers/news_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import services.{type Services}

pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/headlines",
    controller: news_controller.headlines,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/live",
    controller: news_controller.live,
    middleware: [],
  )
}
