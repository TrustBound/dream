import dream_http_client/client
import dream_http_client_test
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/list
import gleam/yielder
import gleeunit/should

@external(erlang, "profile_ffi", "max_sessions")
fn max_sessions(profile: atom.Atom) -> Int

@external(erlang, "profile_ffi", "begin_cancel_trace")
fn begin_cancel_trace() -> Nil

@external(erlang, "profile_ffi", "cancelled_in")
fn cancelled_in(profile: atom.Atom) -> Bool

@external(erlang, "cancellation_ffi", "await_registered")
fn await_registered(handle: client.StreamHandle) -> Bool

fn request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

pub fn default_requests_leave_host_profile_unchanged_test() {
  let host_default = atom.create("default")
  let before = max_sessions(host_default)

  let assert Ok(response) = client.send(request("/text"))
  response.status |> should.equal(200)

  max_sessions(host_default) |> should.equal(before)
  max_sessions(atom.create("dream_http_client")) |> should.equal(100)
}

pub fn explicit_profile_covers_all_request_modes_test() {
  let name = atom.create("dream_http_client_test_isolated")
  let assert Ok(profile) = client.start_profile(name, 3)
  max_sessions(name) |> should.equal(3)

  let assert Ok(response) =
    request("/text") |> client.use_profile(profile) |> client.send()
  response.status |> should.equal(200)

  let chunks =
    request("/stream/fast")
    |> client.use_profile(profile)
    |> client.stream_yielder()
    |> yielder.to_list()
  { chunks != [] } |> should.be_true()
  list.all(chunks, fn(chunk) {
    case chunk {
      Ok(_) -> True
      Error(_) -> False
    }
  })
  |> should.be_true()

  let completed = process.new_subject()
  let assert Ok(handle) =
    request("/stream/fast")
    |> client.use_profile(profile)
    |> client.on_stream_end(fn(_) { process.send(completed, True) })
    |> client.start_stream()
  process.receive(completed, 3000) |> should.equal(Ok(True))
  client.await_stream(handle)

  let assert Ok(Nil) = client.stop_profile(profile)
}

pub fn cancellation_uses_request_profile_test() {
  let name = atom.create("dream_http_client_test_cancel")
  let assert Ok(profile) = client.start_profile(name, 2)
  let assert Ok(handle) =
    request("/stream/slow")
    |> client.use_profile(profile)
    |> client.start_stream()
  await_registered(handle) |> should.be_true()

  begin_cancel_trace()
  client.cancel_stream_handle(handle)
  cancelled_in(name) |> should.be_true()

  let assert Ok(Nil) = client.stop_profile(profile)
}

pub fn profile_limits_and_reserved_name_are_checked_test() {
  client.start_profile(atom.create("dream_http_client"), 3)
  |> should.be_error()
  client.start_profile(atom.create("default"), 3)
  |> should.be_error()
  client.start_profile(atom.create("dream_http_client_test_invalid"), 0)
  |> should.be_error()
}
