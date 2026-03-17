//// Regression tests: ETS table ownership must not cause silent stream crashes
////
//// The `dream_http_client_ref_mapping` ETS table is created by the
//// `dream_http_client` OTP application in its `start/2` callback. The table
//// is owned by the application master process, which lives for the entire
//// application lifetime. This means:
////
//// - No short-lived process can destroy the table by exiting.
//// - No race condition on table creation (application start is serialized).
//// - No try/catch needed on ETS access (the table is always there).
////
//// These tests verify:
//// 1. The table exists and is owned by a long-lived process, not the caller
//// 2. Concurrent streams from short-lived callers all complete
//// 3. Sequential streams across process boundaries work
////
//// The integration tests are the real regression tests — they reproduce the
//// exact scenario from the original bug report (concurrent streams from
//// expired callers) and verify it can never happen again.

import dream_http_client/client
import dream_http_client_test
import gleam/erlang/process
import gleam/http
import gleam/list
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

// ============================================================================
// ETS Table Ownership Tests
// ============================================================================

/// The ETS table must exist and be owned by a process that is NOT the
/// calling test process. With the OTP application architecture, the table
/// is owned by the application master — a long-lived process managed by
/// the BEAM's application controller.
pub fn table_is_owned_by_application_not_caller_test() {
  table_exists() |> should.be_true()
  table_owner_is_not_self() |> should.be_true()
  table_owner_is_alive() |> should.be_true()
}

/// Data stored in the ETS table from a short-lived process must persist
/// after that process exits. The table is owned by the application master,
/// so no individual process exit can destroy it or its data.
pub fn stored_mappings_survive_writer_process_exit_test() {
  let done = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      store_test_mapping()
      process.send(done, True)
    })

  let assert Ok(True) = process.receive(done, 2000)
  process.sleep(200)

  lookup_test_mapping_exists() |> should.be_true()
  clear_test_mappings()
}

// ============================================================================
// Stream Integration Regression Tests
// ============================================================================

/// A stream started from a short-lived caller must complete successfully
/// even after the caller process exits. In the old code, the caller owned
/// the ETS table and its exit destroyed it. The stream process would then
/// crash with `badarg` when looking up ref mappings.
pub fn stream_from_expired_caller_completes_test() {
  let end_subject = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      let request =
        mock_request("/stream/fast")
        |> client.on_stream_end(fn(_headers) {
          process.send(end_subject, "completed")
        })
        |> client.on_stream_error(fn(reason) {
          process.send(end_subject, "error:" <> reason)
        })
      let assert Ok(_handle) = client.start_stream(request)
    })

  case process.receive(end_subject, 5000) {
    Ok("completed") -> Nil
    Ok(_msg) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

/// Two concurrent streams from short-lived callers must BOTH complete.
///
/// This is the exact scenario from the bug report: when two streams are
/// active, the first stream process to exit destroys the shared ETS table,
/// crashing the second stream silently — no `on_stream_error` fires.
///
/// The fast stream completes in ~1s; the slow stream takes ~10s. After the
/// fast stream's caller exits (and in the old code, destroys the ETS
/// table), the slow stream must still fire `on_stream_end`.
pub fn concurrent_streams_from_expired_callers_both_complete_test() {
  let end_subject = process.new_subject()

  let _pid1 =
    process.spawn_unlinked(fn() {
      let request =
        mock_request("/stream/fast")
        |> client.on_stream_end(fn(_headers) { process.send(end_subject, 1) })
        |> client.on_stream_error(fn(_reason) { process.send(end_subject, -1) })
      let assert Ok(_handle) = client.start_stream(request)
    })

  process.sleep(50)

  let _pid2 =
    process.spawn_unlinked(fn() {
      let request =
        mock_request("/stream/slow")
        |> client.on_stream_end(fn(_headers) { process.send(end_subject, 2) })
        |> client.on_stream_error(fn(_reason) { process.send(end_subject, -2) })
      let assert Ok(_handle) = client.start_stream(request)
    })

  let results = collect_n(end_subject, 2, 15_000)
  list.length(results) |> should.equal(2)
  list.each(results, fn(id) { { id > 0 } |> should.be_true() })
}

/// Three concurrent streams from the same (long-lived) caller all complete.
/// Verifies that concurrent streams don't interfere with each other even
/// when they share the same ETS table and complete at similar times.
pub fn three_concurrent_streams_all_complete_test() {
  let end_subject = process.new_subject()

  list.each([1, 2, 3], fn(i) {
    let request =
      mock_request("/stream/fast")
      |> client.on_stream_end(fn(_headers) { process.send(end_subject, i) })
      |> client.on_stream_error(fn(_reason) { process.send(end_subject, -i) })
    let assert Ok(_handle) = client.start_stream(request)
    Nil
  })

  let results = collect_n(end_subject, 3, 5000)
  list.length(results) |> should.equal(3)
  list.each(results, fn(id) { { id > 0 } |> should.be_true() })
}

/// After a stream completes and its process exits, starting a new stream
/// must still work. Verifies the table is not destroyed between sequential
/// stream invocations.
pub fn sequential_streams_after_process_exit_test() {
  let assert Ok(handle1) = client.start_stream(mock_request("/stream/fast"))
  client.await_stream(handle1)
  client.is_stream_active(handle1) |> should.be_false()

  let end_subject = process.new_subject()
  let request2 =
    mock_request("/stream/fast")
    |> client.on_stream_end(fn(_headers) { process.send(end_subject, True) })
    |> client.on_stream_error(fn(_reason) { process.send(end_subject, False) })
  let assert Ok(_handle2) = client.start_stream(request2)

  case process.receive(end_subject, 5000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

/// Five concurrent streams from separate short-lived caller processes must
/// all complete. Stress test for the OTP application ownership model under
/// higher concurrency.
pub fn five_concurrent_streams_from_expired_callers_test() {
  let end_subject = process.new_subject()
  let count = 5

  list.each(list.range(1, count), fn(i) {
    let _pid =
      process.spawn_unlinked(fn() {
        let request =
          mock_request("/stream/fast")
          |> client.on_stream_end(fn(_headers) { process.send(end_subject, i) })
          |> client.on_stream_error(fn(_reason) {
            process.send(end_subject, -i)
          })
        let assert Ok(_handle) = client.start_stream(request)
      })
    Nil
  })

  let results = collect_n(end_subject, count, 8000)
  list.length(results) |> should.equal(count)
  list.each(results, fn(id) { { id > 0 } |> should.be_true() })
}

// ============================================================================
// Helpers
// ============================================================================

fn collect_n(subject: process.Subject(a), n: Int, timeout_ms: Int) -> List(a) {
  do_collect_n(subject, n, timeout_ms, [])
}

fn do_collect_n(
  subject: process.Subject(a),
  remaining: Int,
  timeout_ms: Int,
  acc: List(a),
) -> List(a) {
  case remaining <= 0 {
    True -> list.reverse(acc)
    False ->
      case process.receive(subject, timeout_ms) {
        Ok(item) ->
          do_collect_n(subject, remaining - 1, timeout_ms, [item, ..acc])
        Error(Nil) -> list.reverse(acc)
      }
  }
}

// ============================================================================
// FFI Bindings — ETS table introspection
// ============================================================================

@external(erlang, "ets_table_ownership_ffi", "table_exists")
fn table_exists() -> Bool

@external(erlang, "ets_table_ownership_ffi", "table_owner_is_not_self")
fn table_owner_is_not_self() -> Bool

@external(erlang, "ets_table_ownership_ffi", "table_owner_is_alive")
fn table_owner_is_alive() -> Bool

@external(erlang, "ets_table_ownership_ffi", "store_test_mapping")
fn store_test_mapping() -> Nil

@external(erlang, "ets_table_ownership_ffi", "lookup_test_mapping_exists")
fn lookup_test_mapping_exists() -> Bool

@external(erlang, "ets_table_ownership_ffi", "clear_test_mappings")
fn clear_test_mappings() -> Nil
