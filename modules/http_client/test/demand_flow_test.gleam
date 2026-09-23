import dream_http_client_test
import gleeunit/should

@external(erlang, "demand_flow_ffi", "one_httpc_advance_per_fetch")
fn one_httpc_advance_per_fetch(port: Int) -> Bool

pub fn pull_stream_advances_httpc_once_per_fetch_test() {
  dream_http_client_test.get_test_port()
  |> one_httpc_advance_per_fetch
  |> should.be_true()
}
