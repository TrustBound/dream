//// Tests for the snippets of docs/guides/beam.md.
////
//// Each test runs a snippet of test/snippets/beam_guide_*.gleam, measures
//// what the runtime does, writes the measurements as text, and compares
//// that text with the output file that the guide shows
//// (test/outputs/beam_guide_*.txt). No test waits for a time to pass: a
//// slow dependency is a process that waits for a message from the test.

import dream/http/request.{Get, Post}
import dream/http/response.{type Response, Text}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/erlang/atom
import gleam/erlang/process.{type Pid, type Subject}
import gleam/int
import gleam/list
import gleam/string
import simplifile
import snippets/beam_guide_atoms
import snippets/beam_guide_binaries
import snippets/beam_guide_blocking
import snippets/beam_guide_bottleneck.{type PriceMessage, GetPrice}
import snippets/beam_guide_cache
import snippets/beam_guide_ets
import snippets/beam_guide_let_assert
import snippets/beam_guide_links
import snippets/beam_guide_lists
import snippets/beam_guide_mailbox
import snippets/beam_guide_messages
import snippets/beam_guide_process_dictionary
import snippets/beam_guide_processes
import snippets/beam_guide_recursion
import snippets/beam_guide_strings
import snippets/beam_guide_supervisor
import snippets/beam_guide_time
import snippets/beam_guide_timeouts
import snippets/beam_guide_waiting

pub fn tests() -> TestSuite {
  describe("BEAM guide snippets", [
    output_test("beam_guide_processes", processes_output),
    output_test("beam_guide_supervisor", supervisor_output),
    output_test("beam_guide_blocking", blocking_output),
    output_test("beam_guide_bottleneck", bottleneck_output),
    output_test("beam_guide_links", links_output),
    output_test("beam_guide_timeouts", timeouts_output),
    output_test("beam_guide_let_assert", let_assert_output),
    output_test("beam_guide_atoms", atoms_output),
    output_test("beam_guide_messages", messages_output),
    output_test("beam_guide_binaries", binaries_output),
    output_test("beam_guide_mailbox", mailbox_output),
    output_test("beam_guide_strings", strings_output),
    output_test("beam_guide_process_dictionary", process_dictionary_output),
    output_test("beam_guide_ets", ets_output),
    output_test("beam_guide_lists", lists_output),
    output_test("beam_guide_recursion", recursion_output),
    output_test("beam_guide_time", time_output),
    output_test("beam_guide_waiting", waiting_output),
  ])
}

/// Runs `measure` and compares its text with test/outputs/<name>.txt
fn output_test(name: String, measure: fn() -> String) -> UnitNode {
  it(name <> " shows what the runtime does", fn() {
    // Act
    let output = measure()

    // Assert
    output
    |> should
    |> be_equal(expected(name))
    |> or_fail_with("expected test/outputs/" <> name <> ".txt")
  })
}

fn expected(name: String) -> String {
  case simplifile.read("test/outputs/" <> name <> ".txt") {
    Ok(text) -> text
    Error(_) -> "test/outputs/" <> name <> ".txt is missing"
  }
}

// ============================================================================
// How the BEAM runs a Dream app
// ============================================================================

fn processes_output() -> String {
  let arrivals = process.new_subject()
  let port = free_port()
  let assert Ok(handle) =
    server.new()
    |> server.services(beam_guide_processes.Services(arrivals: arrivals))
    |> server.router(beam_guide_processes.app_router())
    |> server.listen_with_handle(port)

  // Two requests that wait in the controller until the test says go
  let answers = process.new_subject()
  spawn_request(port, "/wait", answers)
  spawn_request(port, "/wait", answers)
  let assert Ok(#(first, first_go)) = process.receive(arrivals, 5000)
  let assert Ok(#(second, second_go)) = process.receive(arrivals, 5000)
  let together = list.length(list.unique([first, second]))
  process.send(first_go, Nil)
  process.send(second_go, Nil)
  let assert Ok(_) = process.receive(answers, 5000)
  let assert Ok(_) = process.receive(answers, 5000)

  let #(one, two) = get_twice_on_one_connection(port, <<"/">>)
  let keep_alive = list.length(list.unique([one, two]))
  let #(crash_status, _) = get_on_new_connection(port, <<"/crash">>)
  let #(after_status, _) = get_on_new_connection(port, <<"/">>)
  server.stop(handle)

  lines([
    "Two requests at the same time: " <> processes(together),
    "Two requests on one keep-alive connection: " <> processes(keep_alive),
    "GET /crash: " <> int.to_string(crash_status),
    "GET / after the crash: " <> int.to_string(after_status),
  ])
}

fn spawn_request(port: Int, path: String, answers: Subject(Int)) -> Nil {
  process.spawn_unlinked(fn() {
    let #(status, _) = get_on_new_connection(port, bit_array.from_string(path))
    process.send(answers, status)
  })
  Nil
}

fn processes(count: Int) -> String {
  case count {
    1 -> "1 process"
    _ -> int.to_string(count) <> " processes"
  }
}

fn supervisor_output() -> String {
  let name = process.new_name("beam_guide_counter")
  let assert Ok(started) = beam_guide_supervisor.start_app(name)
  let _ = beam_guide_supervisor.increment(name)
  let before = beam_guide_supervisor.increment(name)
  let assert Ok(old_counter) = process.named(name)
  let monitor = process.monitor(old_counter)
  process.kill(old_counter)
  let assert Ok(_down) =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })
    |> process.selector_receive(5000)
  let new_counter = wait_for_new_process(name, old_counter, 500)
  let after = beam_guide_supervisor.increment(name)
  stop(started.pid)

  lines([
    "Count before the crash: " <> int.to_string(before),
    "A new counter process after the crash: "
      <> string.inspect(is_new(new_counter, old_counter)),
    "Count after the restart: " <> int.to_string(after),
  ])
}

fn is_new(found: Result(Pid, Nil), old: Pid) -> Bool {
  case found {
    Ok(pid) -> pid != old
    Error(Nil) -> False
  }
}

/// The supervisor starts the new counter after the old one ends. This
/// asks for the process of the name until it is a new one, at most
/// `tries` times, 10 milliseconds apart.
fn wait_for_new_process(
  name: process.Name(message),
  old: Pid,
  tries: Int,
) -> Result(Pid, Nil) {
  case process.named(name), tries {
    Ok(pid), _ if pid != old -> Ok(pid)
    _, 0 -> Error(Nil)
    _, _ -> {
      let never: Subject(Nil) = process.new_subject()
      let _ = process.receive(never, 10)
      wait_for_new_process(name, old, tries - 1)
    }
  }
}

// ============================================================================
// Processes and failure
// ============================================================================

fn blocking_output() -> String {
  let request =
    test_request.create_request_with_query(
      Post,
      "/signup",
      "email=ada@example.com",
    )

  // The blocking controller
  let events = process.new_subject()
  let send_now = fn(address) {
    process.send(events, "email sent to " <> address)
  }
  let unused_mailer = process.new_subject()
  let response =
    beam_guide_blocking.signup_and_wait(
      request,
      Nil,
      beam_guide_blocking.Services(send_email: send_now, mailer: unused_mailer),
    )
  let blocking_order =
    list.append(drain(events), ["response " <> int.to_string(response.status)])

  // The controller that gives the email to the mailer
  let gates = process.new_subject()
  let send_later = fn(address) {
    wait_at_gate(gates)
    process.send(events, "email sent to " <> address)
  }
  let assert Ok(mailer) = beam_guide_blocking.start_mailer(send_later)
  let response =
    beam_guide_blocking.signup(
      request,
      Nil,
      beam_guide_blocking.Services(send_email: send_later, mailer: mailer.data),
    )
  let answered = "response " <> int.to_string(response.status)
  open_gate(gates)
  let assert Ok(sent) = process.receive(events, 5000)
  stop(mailer.pid)

  lines([
    "signup_and_wait: " <> string.join(blocking_order, ", then "),
    "signup: " <> answered <> ", then " <> sent,
  ])
}

fn bottleneck_output() -> String {
  let gates = process.new_subject()
  let lookup = fn(_sku) {
    wait_at_gate(gates)
    Ok(100)
  }
  let assert Ok(prices) = beam_guide_bottleneck.start_price_server(lookup)

  // One request holds the price process. Three more wait in its mailbox.
  let answers = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(answers, beam_guide_bottleneck.price(prices.data, "sku-1"))
  })
  let assert Ok(first_gate) = process.receive(gates, 5000)
  let replies = process.new_subject()
  list.each([1, 2, 3], fn(_) {
    process.send(prices.data, GetPrice("sku-1", replies))
  })
  let waiting = message_queue_len(prices.pid)
  process.send(first_gate, Nil)
  list.each([1, 2, 3], fn(_) { open_gate(gates) })
  let assert Ok(_) = process.receive(answers, 5000)

  // A call after the price process stopped
  stop(prices.pid)
  let after_stop =
    catch_crash(fn() { beam_guide_bottleneck.price(prices.data, "sku-1") })
  let after_stop_text = case after_stop {
    Error(message) ->
      "it panics, "
      <> string.inspect(string.starts_with(message, "callee exited"))
    Ok(_) -> "it returns"
  }

  // Three requests read the ETS table themselves
  let table = beam_guide_cache.new_table()
  beam_guide_cache.insert(table, "sku-1", 100)
  let reads = process.new_subject()
  list.each([1, 2, 3], fn(_) {
    process.spawn_unlinked(fn() {
      process.send(
        reads,
        beam_guide_bottleneck.price_from_table(table, "sku-1"),
      )
    })
  })
  let read_answers =
    list.map([1, 2, 3], fn(_) {
      let assert Ok(answer) = process.receive(reads, 5000)
      answer
    })

  lines([
    "Requests that wait for the one price process: " <> int.to_string(waiting),
    "A call after the price process stopped: "
      <> after_stop_text
      <> " that the callee exited",
    "Three requests that read the ETS table: " <> string.inspect(read_answers),
  ])
}

fn links_output() -> String {
  let crash = fn() { panic as "render failed" }

  let outcomes = process.new_subject()
  let request_process =
    process.spawn_unlinked(fn() {
      let response = beam_guide_links.render_with_linked_helper(crash)
      process.send(outcomes, "it answers " <> describe_response(response))
    })
  let monitor = process.monitor(request_process)
  let assert Ok(linked) =
    process.new_selector()
    |> process.select(outcomes)
    |> process.select_specific_monitor(monitor, fn(_down) {
      "the request process ends"
    })
    |> process.selector_receive(5000)

  let monitored = beam_guide_links.render_with_monitored_helper(crash)

  lines([
    "render_with_linked_helper, the helper crashes: " <> linked,
    "render_with_monitored_helper, the helper crashes: "
      <> describe_response(monitored),
  ])
}

fn timeouts_output() -> String {
  let gates = process.new_subject()
  let lookup = fn(_sku) {
    wait_at_gate(gates)
    Ok(100)
  }
  let assert Ok(prices) = beam_guide_bottleneck.start_price_server(lookup)

  // A request that calls with no timeout
  let answers = process.new_subject()
  let request_process =
    process.spawn_unlinked(fn() {
      process.send(
        answers,
        beam_guide_timeouts.price_or_wait_forever(prices.data, "sku-1"),
      )
    })
  let assert Ok(held) = process.receive(gates, 5000)
  let forever = case
    process.is_alive(request_process),
    process.receive(answers, 0)
  {
    True, Error(Nil) -> "still waiting, with no answer"
    _, _ -> "it answered"
  }
  process.kill(request_process)
  process.send(held, Nil)

  // A request that calls with a timeout of 10 milliseconds
  let response =
    beam_guide_timeouts.price_with_timeout(prices.data, "sku-1", 10)
  open_gate(gates)
  stop(prices.pid)

  lines([
    "price_or_wait_forever, the price service does not answer: " <> forever,
    "price_with_timeout, the price service does not answer in 10 ms: "
      <> describe_response(response),
  ])
}

fn let_assert_output() -> String {
  let request = test_request.create_request_with_query(Get, "/", "page=two")
  let crashed =
    catch_crash(fn() { beam_guide_let_assert.page_or_crash(request, Nil, Nil) })
  let crashed_text = case crashed {
    Error(message) -> "the request crashes: " <> message
    Ok(response) -> describe_response(response)
  }
  let answered = beam_guide_let_assert.page(request, Nil, Nil)
  let setting =
    catch_crash(fn() { beam_guide_let_assert.port_setting("eighty") })

  lines([
    "page_or_crash with ?page=two: " <> crashed_text,
    "page with ?page=two: " <> describe_response(answered),
    "port_setting(\"eighty\"): " <> string.inspect(setting),
  ])
}

// ============================================================================
// Memory
// ============================================================================

fn atoms_output() -> String {
  let before = atom.get("beam_guide_shoe_size")
  run_in_process_that_ends(fn() {
    beam_guide_atoms.sort_key_from_input("beam_guide_shoe_size")
  })
  let after = atom.get("beam_guide_shoe_size")
  let checked = beam_guide_atoms.sort_key("beam_guide_hat_size")
  let hat = atom.get("beam_guide_hat_size")

  lines([
    "Before the request, beam_guide_shoe_size is an atom: "
      <> string.inspect(before != Error(Nil)),
    "After the request process ended, beam_guide_shoe_size is an atom: "
      <> string.inspect(after != Error(Nil)),
    "sort_key(\"beam_guide_hat_size\"): "
      <> string.inspect(checked)
      <> ", and beam_guide_hat_size is an atom: "
      <> string.inspect(hat != Error(Nil)),
    "The atom limit of this runtime: " <> int.to_string(atom_limit()),
  ])
}

fn messages_output() -> String {
  let rows = one_to(100_000)
  let csv = repeat_bytes(<<"x">>, 1_000_000)
  let rows_words =
    words_received(fn(worker) { beam_guide_messages.export_rows(worker, rows) })
  let id_words =
    words_received(fn(worker) { beam_guide_messages.export_by_id(worker, 42) })
  let csv_words =
    words_received(fn(worker) { beam_guide_messages.export_csv(worker, csv) })

  lines([
    "export_rows, 100000 numbers: "
      <> int.to_string(rows_words)
      <> " words in the worker's heap",
    "export_by_id: " <> int.to_string(id_words) <> " words in the worker's heap",
    "export_csv, 1000000 bytes: "
      <> int.to_string(csv_words)
      <> " words in the worker's heap",
  ])
}

/// Starts a worker process, calls `send` with its subject, and returns the
/// size in words of the message in the heap of the worker
fn words_received(send: fn(Subject(message)) -> Nil) -> Int {
  let workers = process.new_subject()
  let sizes = process.new_subject()
  process.spawn_unlinked(fn() {
    let inbox = process.new_subject()
    process.send(workers, inbox)
    let message = process.receive_forever(inbox)
    process.send(sizes, heap_words(message))
  })
  let assert Ok(worker) = process.receive(workers, 5000)
  send(worker)
  let assert Ok(size) = process.receive(sizes, 5000)
  size
}

fn binaries_output() -> String {
  let upload = repeat_bytes(<<"x">>, 1_000_000)
  let assert Ok(small) = beam_guide_binaries.preview_slice(upload, 16)
  let assert Ok(slice) = beam_guide_binaries.preview_slice(upload, 100)
  let assert Ok(copy) = beam_guide_binaries.preview_copy(upload, 100)

  lines([
    "preview_slice, 16 bytes of a 1000000-byte upload, keeps "
      <> int.to_string(referenced_byte_size(small))
      <> " bytes",
    "preview_slice, 100 bytes of a 1000000-byte upload, keeps "
      <> int.to_string(referenced_byte_size(slice))
      <> " bytes",
    "preview_copy, 100 bytes of a 1000000-byte upload, keeps "
      <> int.to_string(referenced_byte_size(copy))
      <> " bytes",
  ])
}

fn mailbox_output() -> String {
  lines([
    "log, 1000 lines to a busy logger: "
      <> int.to_string(lines_waiting_at_busy_logger())
      <> " messages wait",
    "log_and_wait: " <> log_and_wait_order(),
    "price_with_own_timeout, a reply after the timeout: "
      <> int.to_string(
      messages_left_by(fn(prices) {
        let _ = beam_guide_mailbox.price_with_own_timeout(prices, "sku-1", 10)
        Nil
      }),
    )
      <> " message left in the mailbox",
    "price_with_timeout, a reply after the timeout: "
      <> int.to_string(
      messages_left_by(fn(prices) {
        let _ = beam_guide_timeouts.price_with_timeout(prices, "sku-1", 10)
        Nil
      }),
    )
      <> " messages left in the mailbox",
  ])
}

fn lines_waiting_at_busy_logger() -> Int {
  let gates = process.new_subject()
  let write = fn(_line) { wait_at_gate(gates) }
  let assert Ok(logger) = beam_guide_mailbox.start_logger(write)
  beam_guide_mailbox.log(logger.data, "line 0")
  let assert Ok(_held) = process.receive(gates, 5000)
  list.each(one_to(1000), fn(number) {
    beam_guide_mailbox.log(logger.data, "line " <> int.to_string(number))
  })
  let waiting = message_queue_len(logger.pid)
  stop(logger.pid)
  waiting
}

fn log_and_wait_order() -> String {
  let written = process.new_subject()
  let write = fn(line) { process.send(written, line) }
  let assert Ok(logger) = beam_guide_mailbox.start_logger(write)
  beam_guide_mailbox.log_and_wait(logger.data, "hello")
  let order = case process.receive(written, 0) {
    Ok("hello") -> "the line is written before the call returns"
    _ -> "the call returns before the line is written"
  }
  stop(logger.pid)
  order
}

type FakePriceControl {
  ReplyNow(request_process: Pid)
}

/// Runs `ask` in a request process with a price service that answers only
/// after `ask` returns. Then it counts the messages in the mailbox of the
/// request process. The price service counts them, after its reply, so the
/// count includes the reply.
fn messages_left_by(ask: fn(Subject(PriceMessage)) -> Nil) -> Int {
  let setup = process.new_subject()
  let counts = process.new_subject()
  process.spawn_unlinked(fn() {
    let prices = process.new_subject()
    let control = process.new_subject()
    process.send(setup, #(prices, control))
    let assert Ok(GetPrice(_sku, reply)) = process.receive(prices, 5000)
    let assert Ok(ReplyNow(request_process)) = process.receive(control, 5000)
    process.send(reply, Ok(100))
    process.send(counts, message_queue_len(request_process))
  })
  let assert Ok(#(prices, control)) = process.receive(setup, 5000)

  let asked = process.new_subject()
  let request_process =
    process.spawn_unlinked(fn() {
      ask(prices)
      process.send(asked, Nil)
      let stay: Subject(Nil) = process.new_subject()
      process.receive_forever(stay)
    })
  let assert Ok(Nil) = process.receive(asked, 5000)
  process.send(control, ReplyNow(request_process))
  let assert Ok(count) = process.receive(counts, 5000)
  process.kill(request_process)
  count
}

fn strings_output() -> String {
  let growth = fn(build: fn(List(String)) -> String) {
    let few = reductions_of(fn() { build(numbered_lines(2000)) })
    let many = reductions_of(fn() { build(numbered_lines(8000)) })
    many / few
  }

  lines([
    "4 times the lines, 2000 to 8000:",
    "report_by_prepending does more than 8 times the work: "
      <> string.inspect(growth(beam_guide_strings.report_by_prepending) > 8),
    "report_by_appending does less than 5 times the work: "
      <> string.inspect(growth(beam_guide_strings.report_by_appending) < 5),
    "report does less than 5 times the work: "
      <> string.inspect(growth(beam_guide_strings.report) < 5),
  ])
}

fn numbered_lines(count: Int) -> List(String) {
  list.map(one_to(count), fn(number) { "line " <> int.to_string(number) })
}

// ============================================================================
// State
// ============================================================================

fn process_dictionary_output() -> String {
  let port = free_port()
  let services =
    beam_guide_process_dictionary.Services(visits: beam_guide_cache.new_table())
  let assert Ok(handle) =
    server.new()
    |> server.services(services)
    |> server.router(beam_guide_process_dictionary.app_router())
    |> server.listen_with_handle(port)

  let #(first, second) = get_twice_on_one_connection(port, <<"/dictionary">>)
  let #(_, fresh) = get_on_new_connection(port, <<"/dictionary">>)
  let table_counts =
    list.map([1, 2, 3], fn(_) {
      let #(_, body) = get_on_new_connection(port, <<"/table">>)
      body
    })
  server.stop(handle)

  lines([
    "Process dictionary, two requests on one connection: "
      <> first
      <> ", "
      <> second,
    "Process dictionary, a request on a new connection: " <> fresh,
    "ETS table, three requests on three connections: "
      <> string.join(table_counts, ", "),
  ])
}

fn ets_output() -> String {
  let tables = process.new_subject()
  run_in_process_that_ends(fn() {
    process.send(tables, beam_guide_ets.cache_for_request())
  })
  let assert Ok(request_table) = process.receive(tables, 5000)

  let assert Ok(owner) = beam_guide_ets.start_table_owner()
  let prices = process.new_subject()
  run_in_process_that_ends(fn() {
    process.send(prices, beam_guide_cache.lookup(owner.data, "sku-1"))
  })
  let assert Ok(price) = process.receive(prices, 5000)
  let owned_exists = beam_guide_cache.exists(owner.data)
  stop(owner.pid)

  lines([
    "cache_for_request, after the request process ended, the table exists: "
      <> string.inspect(beam_guide_cache.exists(request_table)),
    "start_table_owner, after the request process ended, the table exists: "
      <> string.inspect(owned_exists)
      <> ", sku-1: "
      <> string.inspect(price),
  ])
}

fn lists_output() -> String {
  let growth = fn(build: fn(List(Int)) -> List(Int)) {
    let few = reductions_of(fn() { build(one_to(2000)) })
    let many = reductions_of(fn() { build(one_to(8000)) })
    many / few
  }

  lines([
    "4 times the numbers, 2000 to 8000:",
    "squares_by_appending does more than 8 times the work: "
      <> string.inspect(growth(beam_guide_lists.squares_by_appending) > 8),
    "squares does less than 5 times the work: "
      <> string.inspect(growth(beam_guide_lists.squares) < 5),
  ])
}

fn recursion_output() -> String {
  let body =
    run_with_heap_limit(
      fn() { beam_guide_recursion.sum_to(1_000_000) },
      1_000_000,
    )
  let tail =
    run_with_heap_limit(
      fn() { beam_guide_recursion.sum_to_with_total(1_000_000, 0) },
      1_000_000,
    )

  lines([
    "sum_to(1000000), at most 1000000 words of heap: "
      <> heap_limit_result(body),
    "sum_to_with_total(1000000, 0), at most 1000000 words of heap: "
      <> heap_limit_result(tail),
  ])
}

fn heap_limit_result(result: Result(Int, Nil)) -> String {
  case result {
    Ok(sum) -> int.to_string(sum)
    Error(Nil) -> "the runtime stopped the process at the limit"
  }
}

// ============================================================================
// Time and the runtime
// ============================================================================

fn time_output() -> String {
  let readings = list.map(one_to(10_000), fn(_) { beam_guide_time.now() })
  let went_back =
    list.window_by_2(readings)
    |> list.count(fn(pair) { pair.1 < pair.0 })
  let duration = beam_guide_time.milliseconds(fn() { Nil })

  lines([
    "The time warp mode of this runtime: " <> time_warp_mode(),
    "10000 readings of monotonic time, the times it went back: "
      <> int.to_string(went_back),
    "milliseconds of a function that does nothing is 0 or more: "
      <> string.inspect(duration >= 0),
  ])
}

fn waiting_output() -> String {
  let gates = process.new_subject()
  let done = process.new_subject()
  let make_thumbnail = fn(image) {
    wait_at_gate(gates)
    string.replace(image, ".jpg", "-small.jpg")
  }
  beam_guide_waiting.start_thumbnail("photo.jpg", make_thumbnail, done)
  let assert Ok(job_gate) = process.receive(gates, 5000)
  let after_sleep = beam_guide_waiting.thumbnail_after_sleep(done)
  process.send(job_gate, Nil)
  let when_done = beam_guide_waiting.thumbnail_when_done(done)

  lines([
    "thumbnail_after_sleep, the job is not done after 100 ms: "
      <> string.inspect(after_sleep),
    "thumbnail_when_done: " <> string.inspect(when_done),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

/// Called by a stand-in for slow work. It sends a gate to the test, and
/// waits until the test opens it.
fn wait_at_gate(gates: Subject(Subject(Nil))) -> Nil {
  let gate = process.new_subject()
  process.send(gates, gate)
  let assert Ok(Nil) = process.receive(gate, 5000)
  Nil
}

/// Waits for the next gate and opens it
fn open_gate(gates: Subject(Subject(Nil))) -> Nil {
  let assert Ok(gate) = process.receive(gates, 5000)
  process.send(gate, Nil)
}

/// Runs `work` in a new process, and returns after that process ended
fn run_in_process_that_ends(work: fn() -> a) -> Nil {
  let pid = process.spawn_unlinked(fn() { work() })
  let monitor = process.monitor(pid)
  let assert Ok(Nil) =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(_down) { Nil })
    |> process.selector_receive(5000)
  Nil
}

/// Stops a process that is linked to the test process, without stopping
/// the test process
fn stop(pid: Pid) -> Nil {
  process.unlink(pid)
  process.kill(pid)
}

fn drain(subject: Subject(String)) -> List(String) {
  case process.receive(subject, 0) {
    Ok(message) -> [message, ..drain(subject)]
    Error(Nil) -> []
  }
}

fn describe_response(response: Response) -> String {
  case response.body {
    Text(text) -> int.to_string(response.status) <> " " <> text
    _ -> int.to_string(response.status)
  }
}

/// The numbers from 1 to `last`
fn one_to(last: Int) -> List(Int) {
  count_down(last, [])
}

fn count_down(number: Int, numbers: List(Int)) -> List(Int) {
  case number {
    0 -> numbers
    _ -> count_down(number - 1, [number, ..numbers])
  }
}

fn lines(items: List(String)) -> String {
  string.join(items, "\n") <> "\n"
}

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "beam_guide_test_ffi", "message_queue_len")
fn message_queue_len(pid: Pid) -> Int

@external(erlang, "beam_guide_test_ffi", "heap_words")
fn heap_words(term: a) -> Int

@external(erlang, "beam_guide_test_ffi", "referenced_byte_size")
fn referenced_byte_size(bits: BitArray) -> Int

/// Calls `run`. Returns `Error` with the message when it panics or when a
/// `let assert` fails.
@external(erlang, "beam_guide_test_ffi", "catch_crash")
fn catch_crash(run: fn() -> a) -> Result(a, String)

/// A binary of `times` copies of `bits`, with no room to grow
@external(erlang, "binary", "copy")
fn repeat_bytes(bits: BitArray, times: Int) -> BitArray

@external(erlang, "beam_guide_test_ffi", "time_warp_mode")
fn time_warp_mode() -> String

@external(erlang, "beam_guide_test_ffi", "atom_limit")
fn atom_limit() -> Int

@external(erlang, "beam_guide_test_ffi", "reductions_of")
fn reductions_of(work: fn() -> a) -> Int

@external(erlang, "beam_guide_test_ffi", "run_with_heap_limit")
fn run_with_heap_limit(work: fn() -> Int, words: Int) -> Result(Int, Nil)

@external(erlang, "beam_guide_test_ffi", "get_on_new_connection")
fn get_on_new_connection(port: Int, path: BitArray) -> #(Int, String)

@external(erlang, "beam_guide_test_ffi", "get_twice_on_one_connection")
fn get_twice_on_one_connection(port: Int, path: BitArray) -> #(String, String)
