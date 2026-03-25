import dream_http_client/client

pub fn configure_high_concurrency() -> Nil {
  client.transport_config()
  |> client.max_connections(200)
  |> client.idle_timeout(120_000)
  |> client.max_concurrent_streams(500)
  |> client.configure_transport()
}
