import dream/core/context.{AppContext}
import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/static/router.{create_router}
import examples/static/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
