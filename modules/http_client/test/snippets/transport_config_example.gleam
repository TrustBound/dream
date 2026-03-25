import dream_http_client/client

pub fn configure_high_concurrency() -> Nil {
  client.transport_config()
  |> client.max_sessions(200)
  |> client.keep_alive_timeout(120_000)
  |> client.configure_transport()
}
