//// Regression tests: ETS table ownership must not cause silent stream crashes
////
//// Before the fix, `dream_httpc_shim` created its named ETS table
//// (`dream_http_client_ref_mapping`) from whichever short-lived process first
//// called `ensure_ref_mapping_table()`. When that process exited, the table was
//// destroyed. Concurrent stream processes that depended on it would crash with
//// `badarg` inside `decode_stream_message_for_selector/1`, killing the stream
//// silently — no `on_stream_error` callback fired.
////
//// These tests verify:
//// 1. The table is owned by a persistent holder process, not the caller
//// 2. The table and its data survive after the creating process exits
//// 3. Concurrent table creation (race condition) does not crash
//// 4. Concurrent streams from short-lived callers all complete
////
//// Tests that manipulate the ETS table directly (delete/recreate) use FFI
//// helpers in `ets_table_ownership_ffi.erl` for table introspection that
//// is not exposed through the Gleam API.

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

/// After ensure_ref_mapping_table(), the table owner must be a separate
/// holder process — not the calling process. This is the core fix mechanism:
/// a dedicated holder process owns the table so it outlives any individual
/// stream process.
pub fn table_owner_is_dedicated_holder_not_caller_test() {
  // Arrange
  delete_table()

  // Act
  ensure_table()

  // Assert — owner is alive but is NOT us
  table_owner_is_not_self() |> should.be_true()
  table_owner_is_alive() |> should.be_true()
}

/// The ETS table must persist after the process that created it exits.
/// Before the fix, the table was destroyed on creator exit because ETS
/// tables are owned by their creating process.
pub fn table_survives_creator_process_exit_test() {
  // Arrange — clean state so the spawned process is the creator
  delete_table()

  let done = process.new_subject()

  // Act — create the table from a short-lived process that exits immediately
  let _pid =
    process.spawn_unlinked(fn() {
      ensure_table()
      process.send(done, True)
    })

  let assert Ok(True) = process.receive(done, 2000)
  // Give the spawned process time to exit
  process.sleep(200)

  // Assert — table and its owner (holder process) are still alive
  table_exists() |> should.be_true()
  table_owner_is_alive() |> should.be_true()
}

/// Data stored in the ETS table must survive after the creating process exits.
/// This verifies that the holder process ownership transfer preserves all
/// existing table entries.
pub fn stored_mappings_survive_creator_exit_test() {
  // Arrange
  delete_table()

  let done = process.new_subject()

  // Act — create table and store a mapping from a short-lived process
  let _pid =
    process.spawn_unlinked(fn() {
      ensure_table()
      store_test_mapping()
      process.send(done, True)
    })

  let assert Ok(True) = process.receive(done, 2000)
  process.sleep(200)

  // Assert — mapping is still retrievable after creator exited
  lookup_test_mapping_exists() |> should.be_true()
}

// ============================================================================
// Race Condition Tests
// ============================================================================

/// Many concurrent calls to ensure_ref_mapping_table() must not crash.
/// Before the fix, a race existed where two processes both saw `undefined`
/// from `ets:info/1` and the second `ets:new/2` call would throw `badarg`
/// because the named table already existed.
pub fn concurrent_table_creation_does_not_crash_test() {
  // Arrange
  delete_table()

  let done = process.new_subject()
  let count = 20

  // Act — spawn 20 processes that all race to create the table
  list.each(list.range(1, count), fn(i) {
    let _pid =
      process.spawn_unlinked(fn() {
        ensure_table()
        process.send(done, i)
      })
    Nil
  })

  // Assert — all 20 processes succeed without crashing
  let results = collect_n(done, count, 5000)
  list.length(results) |> should.equal(count)
  table_exists() |> should.be_true()
}

// ============================================================================
// Stream Integration Regression Tests
// ============================================================================

/// A stream started from a short-lived caller must complete successfully
/// even after the caller process exits. The caller calls `start_stream()`
/// which calls `ensure_ets_tables()` — in the old code, the caller owned
/// the ETS table and its exit destroyed it. The stream process would then
/// crash with `badarg` when it tried to look up ref mappings.
///
/// Note: a single stream may self-heal by re-creating the table from within
/// `request_stream_messages()`. This test provides baseline assurance; the
/// concurrent test below is the definitive bug reproduction.
pub fn stream_from_expired_caller_completes_test() {
  // Arrange — clean state so the caller process creates the table
  delete_table()

  let end_subject = process.new_subject()

  // Act — start stream from a process that immediately exits
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
      // Caller exits here — would destroy table in old code
    })

  // Assert — stream completes (not silently dead, not error)
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
/// fast stream's process exits (and in the old code, destroys the ETS
/// table), the slow stream must still fire `on_stream_end`.
pub fn concurrent_streams_from_expired_callers_both_complete_test() {
  // Arrange — force table recreation through short-lived callers
  delete_table()

  let end_subject = process.new_subject()

  // Act — start fast stream from short-lived caller
  let _pid1 =
    process.spawn_unlinked(fn() {
      let request =
        mock_request("/stream/fast")
        |> client.on_stream_end(fn(_headers) { process.send(end_subject, 1) })
        |> client.on_stream_error(fn(_reason) { process.send(end_subject, -1) })
      let assert Ok(_handle) = client.start_stream(request)
    })

  // Small delay so the fast stream's caller creates the table first,
  // ensuring the slow stream's process is NOT the table creator.
  process.sleep(50)

  // Act — start slow stream from short-lived caller
  let _pid2 =
    process.spawn_unlinked(fn() {
      let request =
        mock_request("/stream/slow")
        |> client.on_stream_end(fn(_headers) { process.send(end_subject, 2) })
        |> client.on_stream_error(fn(_reason) { process.send(end_subject, -2) })
      let assert Ok(_handle) = client.start_stream(request)
    })

  // Assert — both streams complete (positive IDs mean on_stream_end fired)
  let results = collect_n(end_subject, 2, 15_000)
  list.length(results) |> should.equal(2)
  list.each(results, fn(id) { { id > 0 } |> should.be_true() })
}

/// Three concurrent streams from the same (long-lived) caller all complete.
/// Verifies that concurrent streams don't interfere with each other even
/// when they share the same ETS table and complete at similar times.
pub fn three_concurrent_streams_all_complete_test() {
  // Arrange
  let end_subject = process.new_subject()

  // Act — start 3 concurrent streams
  list.each([1, 2, 3], fn(i) {
    let request =
      mock_request("/stream/fast")
      |> client.on_stream_end(fn(_headers) { process.send(end_subject, i) })
      |> client.on_stream_error(fn(_reason) { process.send(end_subject, -i) })
    let assert Ok(_handle) = client.start_stream(request)
    Nil
  })

  // Assert — all 3 complete with on_stream_end (positive), not on_stream_error
  let results = collect_n(end_subject, 3, 5000)
  list.length(results) |> should.equal(3)
  list.each(results, fn(id) { { id > 0 } |> should.be_true() })
}

/// After a stream completes and its process exits, starting a new stream
/// must still work. Verifies the table is not destroyed between sequential
/// stream invocations.
pub fn sequential_streams_after_process_exit_test() {
  // Arrange — stream 1: start, complete, and let the process exit
  let assert Ok(handle1) = client.start_stream(mock_request("/stream/fast"))
  client.await_stream(handle1)
  client.is_stream_active(handle1) |> should.be_false()

  // Act — stream 2 must work
  let end_subject = process.new_subject()
  let request2 =
    mock_request("/stream/fast")
    |> client.on_stream_end(fn(_headers) { process.send(end_subject, True) })
    |> client.on_stream_error(fn(_reason) { process.send(end_subject, False) })
  let assert Ok(_handle2) = client.start_stream(request2)

  // Assert — stream 2 completes
  case process.receive(end_subject, 5000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> should.fail()
  }
}

/// Five concurrent streams from separate short-lived caller processes must
/// all complete. Stress test for the holder-process ownership model under
/// higher concurrency with multiple table-creation races.
pub fn five_concurrent_streams_from_expired_callers_test() {
  // Arrange
  delete_table()

  let end_subject = process.new_subject()
  let count = 5

  // Act — spawn 5 callers that each start a stream and immediately exit
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

  // Assert — all 5 complete
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

@external(erlang, "ets_table_ownership_ffi", "ensure_table")
fn ensure_table() -> Nil

@external(erlang, "ets_table_ownership_ffi", "table_exists")
fn table_exists() -> Bool

@external(erlang, "ets_table_ownership_ffi", "delete_table")
fn delete_table() -> Nil

@external(erlang, "ets_table_ownership_ffi", "table_owner_is_not_self")
fn table_owner_is_not_self() -> Bool

@external(erlang, "ets_table_ownership_ffi", "table_owner_is_alive")
fn table_owner_is_alive() -> Bool

@external(erlang, "ets_table_ownership_ffi", "store_test_mapping")
fn store_test_mapping() -> Nil

@external(erlang, "ets_table_ownership_ffi", "lookup_test_mapping_exists")
fn lookup_test_mapping_exists() -> Bool
