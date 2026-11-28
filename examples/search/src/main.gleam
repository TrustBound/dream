//// Notes with search: a Dream app that keeps its notes in a store, and a
//// copy of them in an OpenSearch index.
////
//// Start OpenSearch on port 9200, run it with `gleam run -m main`, then:
////
////   curl -i -X POST localhost:3000/notes -d '{"title":"Water the garden","body":"Every morning"}'
////   curl -i 'localhost:3000/search?q=garden'

import dream/servers/mist/server
import dream_opensearch/client
import gleam/io
import gleam/result
import notes/router.{create_router}
import notes/search_index
import notes/services.{type Services}

pub fn main() -> Nil {
  case start_services() {
    Ok(services) -> start_server(services)
    Error(message) ->
      io.println_error("The notes app did not start: " <> message)
  }
}

/// Starts the store, and creates the index when it does not exist. The app
/// does not start without its index.
fn start_services() -> Result(Services, String) {
  let opensearch = services.opensearch_client()
  use started <- result.try(services.start_services(opensearch, "notes"))
  search_index.ensure_index(started.opensearch, started.index)
  |> result.replace(started)
  |> result.map_error(client.describe_error)
}

fn start_server(services: Services) -> Nil {
  let assert Ok(Nil) =
    server.new()
    |> server.services(services)
    |> server.router(create_router())
    |> server.bind("localhost")
    |> server.listen(3000)
  Nil
}
