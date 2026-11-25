//// The services of the notes app: the note store, and the OpenSearch
//// client with the name of the index.

import dream_http_client/client as http_client
import dream_opensearch/client.{type Client}
import gleam/http
import gleam/result
import gleam/string
import notes/store.{type Store}

pub type Services {
  Services(notes: Store, opensearch: Client, index: String)
}

/// The OpenSearch client of the running app. A search waits 2 seconds at
/// most: after that, the app answers 503 and does not keep the client
/// waiting for the 30 seconds of the default timeout.
pub fn opensearch_client() -> Client {
  http_client.new()
  |> http_client.scheme(http.Http)
  |> http_client.host("localhost")
  |> http_client.port(9200)
  |> http_client.timeout(2000)
  |> client.from_request
}

/// Starts the note store, and gives the services with `opensearch` and the
/// name of the index
pub fn start_services(
  opensearch: Client,
  index: String,
) -> Result(Services, String) {
  store.start()
  |> result.map(fn(notes) { Services(notes:, opensearch:, index:) })
  |> result.map_error(string.inspect)
}

/// Stops the note store
pub fn stop_services(services: Services) -> Nil {
  store.stop(services.notes)
}
