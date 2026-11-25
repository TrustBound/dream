# The BEAM for Dream developers

Your first Dream server runs. Before you add more to it, learn how the BEAM, the virtual machine under Gleam, runs that server. The BEAM gives each connection its own process, copies each message, and starts processes again when they fail. These rules are different from most other runtimes, and code that is correct in Node.js or Go can be slow, leak memory or fail on the BEAM. This guide shows how the BEAM runs a Dream app, then the common traps, one at a time. Each trap shows the wrong code, what the runtime does with it, and the fix.

## Table of Contents

- [What you will learn](#what-you-will-learn)
- [Before you start](#before-you-start)
- [How the BEAM runs a Dream app](#how-the-beam-runs-a-dream-app)
- [Processes and failure](#processes-and-failure)
- [Memory](#memory)
- [State](#state)
- [Time and the runtime](#time-and-the-runtime)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you will learn

- Which process runs a request, and what happens to the other requests when one crashes.
- How a supervisor starts a failed process again, and what state the new process has.
- How to keep slow work, slow dependencies and crashes of helper processes out of a request.
- Where memory goes on the BEAM: atoms, messages, binaries, mailboxes and strings.
- Where to keep state that more than one request uses.
- How to measure a duration, and how to wait in a test.

## Before you start

You need a Dream server that runs, as at the end of [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html). For why Dream runs on the BEAM at all, read [Why the BEAM?](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/why-beam.md). This guide does not repeat it.

Every code block in this guide is a file in `test/snippets/` of the Dream repository. Every output block is a file in `test/outputs/`. The tests in [`test/beam_snippets_test.gleam`](https://github.com/TrustBound/dream/blob/3.0.0/test/beam_snippets_test.gleam) run the code, measure what the runtime does, and compare the measurements with the output files. The Dream repository tests with Gleam 1.19 and Erlang/OTP 28. The measurements are the same on OTP 29.

The tests do not wait for a time to pass. Each slow dependency in the tests is a process that waits for a message from the test. The test then knows the exact state of each process when it measures.

## How the BEAM runs a Dream app

A BEAM process is not an operating system process or a thread. It is a small unit of the virtual machine, with its own memory and its own mailbox. The schedulers of the BEAM share the CPU cores between the processes.

### Each connection runs in its own process

This app has three controllers. `whoami` answers with the process that runs the request. `wait_for_go` tells a test process that a request arrived, and waits for a message before it answers. `crash` fails on each request:

#### Answer with the process of the request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_processes.gleam#L3-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, Get}
import dream/http/response.{type Response, text_response}
import dream/http/status
import dream/router.{type Router, route, router}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/string

pub type Services {
  Services(arrivals: Subject(#(Pid, Subject(Nil))))
}

/// Answers with the process that runs the request
pub fn whoami(_request: Request, _context, _services: Services) -> Response {
  text_response(status.ok, string.inspect(process.self()))
}

/// Tells `arrivals` which process runs the request, then waits for a go
/// before it answers. Two requests that wait here run at the same time.
pub fn wait_for_go(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  let go = process.new_subject()
  process.send(services.arrivals, #(process.self(), go))
  case process.receive(go, within: 5000) {
    Ok(Nil) -> text_response(status.ok, string.inspect(process.self()))
    Error(Nil) -> text_response(status.service_unavailable, "No go")
  }
}

/// Fails on every request
pub fn crash(_request: Request, _context, _services: Services) -> Response {
  panic as "this controller always fails"
}

pub fn app_router() -> Router(context, Services) {
  router()
  |> route(method: Get, path: "/", controller: whoami, middleware: [])
  |> route(method: Get, path: "/wait", controller: wait_for_go, middleware: [])
  |> route(method: Get, path: "/crash", controller: crash, middleware: [])
}
```

The test starts this app on a free port. It sends two requests to `/wait` on two connections, and it waits until both controllers report. Both requests then wait in their controllers at the same time. Next, the test sends two requests to `/` on one keep-alive connection. Last, it sends `GET /crash` and then `GET /` on new connections:

#### What the app does with each request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_processes.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Two requests at the same time: 2 processes
Two requests on one keep-alive connection: 1 process
GET /crash: 500
GET / after the crash: 200
```

Each line tells you a rule:

- **Requests on two connections run in two processes, at the same time.** One slow request does not stop the other one.
- **Requests on one keep-alive connection run in one process, one after the other.** Dream's server makes a process for each HTTP/1.1 connection, and that process runs each request of the connection. Do not expect a new process for each request. The [process dictionary trap](#state-in-the-process-dictionary) shows why this matters.
- **A crash ends only its own process.** The client of `/crash` gets a `500`. The server logs the crash, and the next request gets a `200`. No other connection sees the crash.

The processes do not share memory. A controller cannot change a value that another request uses, because Gleam values never change, and each process has its own heap. Processes talk only by messages.

### A supervisor starts a failed process again

A supervisor is a process that starts other processes and watches them. When one of them fails, the supervisor starts a new one. Dream's server uses supervisors for its connections. You use them for your own long-lived processes, such as a cache, a mailer or a counter. This app runs a counter under a supervisor from [`gleam_otp`](https://hexdocs.pm/gleam_otp/1.2.0/gleam/otp/static_supervisor.html):

#### Run a counter under a supervisor <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_supervisor.gleam#L3-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/erlang/process.{type Name, type Subject}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub type CounterMessage {
  Increment(reply: Subject(Int))
}

/// A counter process, registered under `name`
pub fn start_counter(
  name: Name(CounterMessage),
) -> actor.StartResult(Subject(CounterMessage)) {
  actor.new(0)
  |> actor.named(name)
  |> actor.on_message(fn(count, message) {
    case message {
      Increment(reply) -> {
        process.send(reply, count + 1)
        actor.continue(count + 1)
      }
    }
  })
  |> actor.start
}

/// Starts the counter under a supervisor. When the counter fails, the
/// supervisor starts a new one under the same name.
pub fn start_app(
  name: Name(CounterMessage),
) -> actor.StartResult(supervisor.Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(supervision.worker(fn() { start_counter(name) }))
  |> supervisor.start
}

/// Asks the counter that has the name `name` to count one more
pub fn increment(name: Name(CounterMessage)) -> Int {
  process.call(process.named_subject(name), waiting: 1000, sending: Increment)
}
```

The test counts two times, kills the counter process, waits until the supervisor registers a new process under the name, and counts again:

#### The counter before and after the crash <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_supervisor.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Count before the crash: 2
A new counter process after the crash: True
Count after the restart: 1
```

The supervisor starts a new process, so the name works again. But the count starts again at 0. The state of a process ends with the process. A supervisor gives you a working process again, not the data of the old one. Keep data that must live through a crash in a database, or in a place the next process can read it again when it starts.

### What this means for a controller

- Write a controller as if it is the only code that runs. Other requests cannot change its values.
- Let a request fail when it meets a bug. The client gets a `500`, the log shows the crash, and the server goes on.
- Do not keep state in the request's process. The process can run the next request of the same connection, or it can end after this one.
- Put state that requests share in a process, an ETS table or a database, and start it under a supervisor.

## Processes and failure

### Slow work in a request

A controller that does slow work, such as sending an email, makes the client wait for all of it:

#### Wrong: send the email in the request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_blocking.gleam#L10-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(send_email: fn(String) -> Nil, mailer: Subject(String))
}

/// Wrong: the client waits until the email is sent
pub fn signup_and_wait(
  request: Request,
  _context,
  services: Services,
) -> Response {
  let address = get_query_param(request.query, "email") |> option.unwrap("")
  services.send_email(address)
  text_response(status.ok, "Welcome!")
}
```

Give the work to a process that runs next to the requests, and answer at once. `process.send` puts the address in the mailer's mailbox and returns:

#### Fix: give the email to a mailer process <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_blocking.gleam#L25-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: give the email to the mailer process and answer at once
pub fn signup(request: Request, _context, services: Services) -> Response {
  let address = get_query_param(request.query, "email") |> option.unwrap("")
  process.send(services.mailer, address)
  text_response(status.accepted, "Welcome! Look for our email.")
}

/// The mailer process: it sends one email for each address it gets
pub fn start_mailer(
  send_email: fn(String) -> Nil,
) -> actor.StartResult(Subject(String)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, address) {
    send_email(address)
    actor.continue(state)
  })
  |> actor.start
}
```

The test gives each controller a `send_email` function that records when it runs:

#### When the client gets its answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_blocking.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
signup_and_wait: email sent to ada@example.com, then response 200
signup: response 202, then email sent to ada@example.com
```

With `signup_and_wait`, the client waits for the email. With `signup`, the client gets `202 Accepted` first, and the mailer sends the email after it. Start the mailer under your supervisor when the app starts, and give its subject to the controllers in your services.

### One process that every request calls

A process is a good place for state, but it handles one message at a time. When each request calls the same process, the requests wait in a line:

#### Wrong: one process answers each price <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_bottleneck.gleam#L7-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type PriceMessage {
  GetPrice(sku: String, reply: Subject(Result(Int, Nil)))
}

/// Wrong: one process looks up the price for every request
pub fn start_price_server(
  lookup_price: fn(String) -> Result(Int, Nil),
) -> actor.StartResult(Subject(PriceMessage)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, message) {
    case message {
      GetPrice(sku, reply) -> {
        process.send(reply, lookup_price(sku))
        actor.continue(state)
      }
    }
  })
  |> actor.start
}

/// Each request calls the price server, and waits its turn
pub fn price(prices: Subject(PriceMessage), sku: String) -> Result(Int, Nil) {
  process.call(prices, waiting: 1000, sending: GetPrice(sku, _))
}
```

The test holds the price process in the `lookup_price` of one request, and sends three more requests:

#### Requests that call one process <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_bottleneck.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Requests that wait for the one price process: 3
A call after the price process stopped: it panics, True that the callee exited
Three requests that read the ETS table: [Ok(100), Ok(100), Ok(100)]
```

The first two lines show both problems of this design:

- **A bottleneck.** Three requests wait in the mailbox of the price process, while it works on the first one. With 1,000 requests at the same time, 999 wait.
- **A single point of failure.** When the price process stops, `process.call` panics in every request that calls it, until a supervisor starts it again.

For data that many requests read, use an ETS table. ETS is a store of the BEAM that holds a table outside of any process heap. Each process can read it directly, at the same time as the others. Gleam's standard library has no ETS module, so this app uses a small Erlang file. The [`dream_ets`](https://github.com/TrustBound/dream_ets) module of the Dream ecosystem is another option.

#### The ETS functions in Erlang <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_cache_ffi.erl"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```erlang
-module(beam_guide_cache_ffi).
-export([new_table/0, insert/3, lookup/2, increment/2, exists/1]).

%% An ETS table that every process can read and write. The process that
%% calls new_table/0 owns the table: the table goes away when that process
%% ends.
new_table() ->
    ets:new(cache, [set, public, {read_concurrency, true}]).

insert(Table, Key, Value) ->
    true = ets:insert(Table, {Key, Value}),
    nil.

lookup(Table, Key) ->
    case ets:lookup(Table, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil}
    end.

%% Adds 1 to the number under Key in one step, and returns the new number.
%% A key that is not there starts at 0.
increment(Table, Key) ->
    ets:update_counter(Table, Key, 1, {Key, 0}).

exists(Table) ->
    ets:info(Table, id) =/= undefined.
```

#### The ETS functions in Gleam <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_cache.gleam#L3-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Table

/// Makes a table. The process that calls this owns the table.
@external(erlang, "beam_guide_cache_ffi", "new_table")
pub fn new_table() -> Table

@external(erlang, "beam_guide_cache_ffi", "insert")
pub fn insert(table: Table, key: String, value: Int) -> Nil

@external(erlang, "beam_guide_cache_ffi", "lookup")
pub fn lookup(table: Table, key: String) -> Result(Int, Nil)

/// Adds 1 to the number under `key` and returns the new number
@external(erlang, "beam_guide_cache_ffi", "increment")
pub fn increment(table: Table, key: String) -> Int

/// True while the table is there
@external(erlang, "beam_guide_cache_ffi", "exists")
pub fn exists(table: Table) -> Bool
```

#### Fix: each request reads the table <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_bottleneck.gleam#L32-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: each request reads the table itself, so no request waits for
/// another one
pub fn price_from_table(table: Table, sku: String) -> Result(Int, Nil) {
  beam_guide_cache.lookup(table, sku)
}
```

The third line of the output shows three processes that read the table, with no process between them. A table has an owner process too. The [ETS owner trap](#an-ets-table-dies-with-its-owner) shows which process to give it.

### Links and monitors

`process.spawn` starts a process that is linked to the process that starts it. A link joins the fates of two processes: when one of them crashes, the other one also stops. This controller starts a linked helper, and the helper crashes:

#### Wrong: a linked helper <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_links.gleam#L7-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: `process.spawn` links the helper to the request process, so a
/// crash of the helper also ends the request
pub fn render_with_linked_helper(render: fn() -> String) -> Response {
  let reply = process.new_subject()
  process.spawn(fn() { process.send(reply, render()) })
  case process.receive(reply, within: 1000) {
    Ok(text) -> text_response(status.ok, text)
    Error(Nil) -> text_response(status.service_unavailable, "Too slow")
  }
}
```

A monitor watches a process without a link. When the watched process ends, the watcher gets a message. `run_in_helper` starts the helper with `process.spawn_unlinked`, monitors it, and waits for the answer or for the end of the helper:

#### Fix: an unlinked helper with a monitor <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_links.gleam#L18-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: start the helper unlinked and monitor it. A crash of the helper
/// is then a message.
pub fn render_with_monitored_helper(render: fn() -> String) -> Response {
  case run_in_helper(render) {
    Ok(text) -> text_response(status.ok, text)
    Error(Nil) ->
      text_response(status.internal_server_error, "The page did not render")
  }
}

/// Runs `work` in a new process. Returns `Error(Nil)` when that process
/// ends without an answer, for example when it crashes.
pub fn run_in_helper(work: fn() -> a) -> Result(a, Nil) {
  let reply = process.new_subject()
  let helper = process.spawn_unlinked(fn() { process.send(reply, work()) })
  let monitor = process.monitor(helper)
  let result =
    process.new_selector()
    |> process.select_map(reply, Ok)
    |> process.select_specific_monitor(monitor, fn(_down) { Error(Nil) })
    |> process.selector_receive_forever
  process.demonitor_process(monitor)
  result
}
```

The test runs each controller in a request process, with a helper that panics:

#### What a crash of the helper does to the request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_links.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
render_with_linked_helper, the helper crashes: the request process ends
render_with_monitored_helper, the helper crashes: 500 The page did not render
```

With the link, the crash of the helper ends the request process too, and the controller never answers. With the monitor, the crash is a message, and the controller sends a clear `500`.

Use a link when two processes cannot work without each other, as a supervisor does with its children. Use a monitor when one process only needs to know that the other one ended.

### A call with no timeout

`process.call_forever` waits until the other process answers, with no limit:

#### Wrong: wait forever for the price service <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_timeouts.gleam#L10-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: if the price service never answers, the request never ends
pub fn price_or_wait_forever(
  prices: Subject(PriceMessage),
  sku: String,
) -> Response {
  case process.call_forever(prices, GetPrice(sku, _)) {
    Ok(price) -> text_response(status.ok, int.to_string(price))
    Error(Nil) -> text_response(status.not_found, "No such product")
  }
}
```

`process.call` takes a timeout, and it panics when the time ends. `price_with_timeout` runs the call in the helper of the last section, so a timeout becomes a `503` with a clear message:

#### Fix: wait at most a set time <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_timeouts.gleam#L21-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: wait at most `timeout` milliseconds, and answer 503 after that
pub fn price_with_timeout(
  prices: Subject(PriceMessage),
  sku: String,
  timeout: Int,
) -> Response {
  let answer =
    run_in_helper(fn() {
      process.call(prices, waiting: timeout, sending: GetPrice(sku, _))
    })
  case answer {
    Ok(Ok(price)) -> text_response(status.ok, int.to_string(price))
    Ok(Error(Nil)) -> text_response(status.not_found, "No such product")
    Error(Nil) ->
      text_response(
        status.service_unavailable,
        "The price service did not answer in time",
      )
  }
}
```

The test runs both controllers against a price service that never answers:

#### A price service that never answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_timeouts.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
price_or_wait_forever, the price service does not answer: still waiting, with no answer
price_with_timeout, the price service does not answer in 10 ms: 503 The price service did not answer in time
```

With `call_forever`, the request waits until the client gives up. The server logs nothing, so the slow dependency stays hidden. With a timeout, the client gets an answer, and the panic of the helper puts the timeout in the log.

Choose a timeout that is shorter than the time the client waits. Erlang's own [`gen_server:call`](https://www.erlang.org/docs/28/apps/stdlib/gen_server.html) waits 5 seconds by default. A client or a load balancer that gives up after 3 seconds never sees the error of a 5-second timeout. Each call in a request then needs a time that fits in what is left of the request's time.

### `let assert` in request code

`let assert` crashes the process when the pattern does not match. Input from a client often does not match:

#### Wrong: crash on a bad page number <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_let_assert.gleam#L9-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: a page number that is not a number crashes the request
pub fn page_or_crash(request: Request, _context, _services) -> Response {
  let assert Ok(page) = case get_query_param(request.query, "page") {
    Some(text) -> int.parse(text)
    None -> Ok(1)
  }
  text_response(status.ok, "Page " <> int.to_string(page))
}
```

Bad input is an expected case, not a bug. Answer it with a `400`:

#### Fix: answer 400 for a bad page number <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_let_assert.gleam#L18-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: bad input from a client is an expected case, so answer 400
pub fn page(request: Request, _context, _services) -> Response {
  let parsed = case get_query_param(request.query, "page") {
    Some(text) -> int.parse(text)
    None -> Ok(1)
  }
  case parsed {
    Ok(page) -> text_response(status.ok, "Page " <> int.to_string(page))
    Error(Nil) ->
      text_response(status.bad_request, "page must be a whole number")
  }
}
```

`let assert` is right where a failure is a bug, and where stopping is the safe action. At startup, a setting that is wrong must stop the program with a message that says why:

#### Right: stop at startup on a bad setting <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_let_assert.gleam#L31-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Right: at startup, a bad setting is a bug in the deployment. The
/// program stops at once, with a message that says why.
pub fn port_setting(text: String) -> Int {
  let assert Ok(port) = int.parse(text) as "PORT must be a whole number"
  port
}
```

#### What each function does with bad input <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_let_assert.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
page_or_crash with ?page=two: the request crashes: Pattern match failed, no pattern matched the value.
page with ?page=two: 400 page must be a whole number
port_setting("eighty"): Error("PORT must be a whole number")
```

The client of `page_or_crash` gets a `500`, and the log gets a crash report for an input error. `page` tells the client what is wrong. `port_setting` stops with the message that you gave to `as`, so the log says what to fix. The `main` of a Dream app does the same with the result of `server.listen`: `let assert Ok(Nil) =` stops the program when the server cannot start.

## Memory

### Atoms are never freed

An atom is a constant whose value is its name, such as `ok` or `error`. The BEAM keeps each atom in one table for the life of the runtime, and it never frees one. When the table is full, the whole runtime stops. This code makes an atom from a value that a client sends:

#### Wrong: make an atom from user input <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_atoms.gleam#L5-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: makes a new atom for each new value that a client sends. The
/// runtime never frees an atom.
pub fn sort_key_from_input(text: String) -> Atom {
  atom.create(text)
}
```

Accept only the values that you know, and use a custom type for them:

#### Fix: a custom type for the known values <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_atoms.gleam#L11-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type SortKey {
  ByName
  ByDate
}

/// Fix: accept only the values that you know, as a custom type
pub fn sort_key(text: String) -> Result(SortKey, Nil) {
  case text {
    "name" -> Ok(ByName)
    "date" -> Ok(ByDate)
    _ -> Error(Nil)
  }
}
```

The test runs `sort_key_from_input` in a process that ends, then looks for the atom:

#### Atoms after the request ends <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_atoms.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Before the request, beam_guide_shoe_size is an atom: False
After the request process ended, beam_guide_shoe_size is an atom: True
sort_key("beam_guide_hat_size"): Error(Nil), and beam_guide_hat_size is an atom: False
The atom limit of this runtime: 1048576
```

The atom stays after its process ends. A client that sends a new value on each request adds an atom on each request, until the runtime reaches its limit and stops. `sort_key` makes no atom. On the Erlang side, the same rule applies to `binary_to_atom` and `list_to_atom`. See [Common Caveats](https://www.erlang.org/docs/28/system/commoncaveats.html) and [System Limits](https://www.erlang.org/docs/28/system/system_limits.html).

### Every message is a copy

Processes share no memory, so `process.send` copies the message into the heap of the receiver. A large value costs a copy each time that you send it:

#### Send rows, an ID or a binary <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_messages.gleam#L5-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: sends all the rows. The worker gets its own copy of each one.
pub fn export_rows(worker: Subject(List(Int)), rows: List(Int)) -> Nil {
  process.send(worker, rows)
}

/// Fix: send the ID of the export, and let the worker read the rows
pub fn export_by_id(worker: Subject(Int), export_id: Int) -> Nil {
  process.send(worker, export_id)
}

/// A binary of more than 64 bytes is not copied: the receiver gets a
/// reference to the same bytes
pub fn export_csv(worker: Subject(BitArray), csv: BitArray) -> Nil {
  process.send(worker, csv)
}
```

The test sends each message to a worker process, and measures the size of the message in the heap of the worker:

#### The size of each message in the worker <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_messages.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
export_rows, 100000 numbers: 200000 words in the worker's heap
export_by_id: 0 words in the worker's heap
export_csv, 1000000 bytes: 8 words in the worker's heap
```

A word is 8 bytes on a 64-bit machine, so the 100,000 numbers are 1.6 MB in the worker, next to the 1.6 MB of the sender. A small `Int` takes no extra space. A binary of more than 64 bytes is different: the BEAM keeps its bytes outside of the process heaps, and a message holds only a reference to them, here 8 words. To send large data, send its ID, or send it as one binary.

### A slice of a large binary keeps the whole binary

A slice of a binary of more than 64 bytes does not copy its bytes. It points into the large binary, and the runtime cannot free the large binary while the slice exists:

#### Wrong: keep a slice of the upload <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_binaries.gleam#L5-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: a slice of more than 64 bytes points into the upload, so the
/// whole upload stays in memory while you keep the slice
pub fn preview_slice(upload: BitArray, size: Int) -> Result(BitArray, Nil) {
  bit_array.slice(upload, at: 0, take: size)
}
```

Copy the slice when you keep it longer than the large binary:

#### Fix: copy the slice <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_binaries.gleam#L11-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: copy the slice, so the runtime can free the upload
pub fn preview_copy(upload: BitArray, size: Int) -> Result(BitArray, Nil) {
  case bit_array.slice(upload, at: 0, take: size) {
    Ok(preview) -> Ok(copy(preview))
    Error(Nil) -> Error(Nil)
  }
}

@external(erlang, "binary", "copy")
fn copy(bits: BitArray) -> BitArray
```

#### The memory that a slice keeps <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_binaries.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
preview_slice, 16 bytes of a 1000000-byte upload, keeps 16 bytes
preview_slice, 100 bytes of a 1000000-byte upload, keeps 1000000 bytes
preview_copy, 100 bytes of a 1000000-byte upload, keeps 100 bytes
```

The 16-byte slice keeps 16 bytes: the runtime copies a slice of 64 bytes or less. The 100-byte slice keeps the whole 1 MB upload. Store such a slice in a cache or in the state of a long-lived process, and the cache holds 1 MB for each entry. The copy keeps only its 100 bytes. See [Constructing and Matching Binaries](https://www.erlang.org/docs/28/system/binaryhandling.html).

### A mailbox that grows without limit

`process.send` never waits. When requests send to a process faster than it can handle the messages, the messages wait in its mailbox, and the mailbox has no limit:

#### Wrong: log with a message that does not wait <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_mailbox.gleam#L7-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type LogMessage {
  Log(line: String)
  LogAndReply(line: String, reply: Subject(Nil))
}

/// A logger process that writes each line with `write`
pub fn start_logger(
  write: fn(String) -> Nil,
) -> actor.StartResult(Subject(LogMessage)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, message) {
    case message {
      Log(line) -> write(line)
      LogAndReply(line, reply) -> {
        write(line)
        process.send(reply, Nil)
      }
    }
    actor.continue(state)
  })
  |> actor.start
}

/// Wrong: returns at once. When requests log faster than the logger
/// writes, the lines wait in the logger's mailbox, with no limit.
pub fn log(logger: Subject(LogMessage), line: String) -> Nil {
  process.send(logger, Log(line))
}
```

Make the sender wait for the receiver. `process.call` waits for a reply, so no request can get ahead of the logger:

#### Fix: log and wait for the logger <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_mailbox.gleam#L36-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: waits until the logger wrote the line. A request can never get
/// ahead of the logger, so the mailbox holds at most one line for each
/// request that logs at the same time.
pub fn log_and_wait(logger: Subject(LogMessage), line: String) -> Nil {
  process.call(logger, waiting: 1000, sending: LogAndReply(line, _))
}
```

A mailbox also grows when a process gets messages that it never receives. `process.receive` takes only the messages of one subject, and it leaves the others in the mailbox. After a timeout, a late reply comes to the process, and nothing receives it:

#### Wrong: a reply that comes after the timeout <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_mailbox.gleam#L43-L56"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: after the timeout, a late reply comes to this process and
/// stays in its mailbox, because nothing receives it
pub fn price_with_own_timeout(
  prices: Subject(PriceMessage),
  sku: String,
  timeout: Int,
) -> Result(Int, Nil) {
  let reply = process.new_subject()
  process.send(prices, GetPrice(sku, reply))
  case process.receive(reply, within: timeout) {
    Ok(price) -> price
    Error(Nil) -> Error(Nil)
  }
}
```

The fix is `price_with_timeout` from [A call with no timeout](#a-call-with-no-timeout). The helper process waits for the reply, so a late reply goes to the helper. The helper ended at the timeout, and the runtime drops messages to a process that ended.

The test holds the logger in its first line and sends 1,000 lines more. Then it lets a price service reply after the timeout of each price function, and counts the messages in the mailbox of the request process:

#### Messages that wait in a mailbox <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_mailbox.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
log, 1000 lines to a busy logger: 1000 messages wait
log_and_wait: the line is written before the call returns
price_with_own_timeout, a reply after the timeout: 1 message left in the mailbox
price_with_timeout, a reply after the timeout: 0 messages left in the mailbox
```

Each message uses memory until a process receives it. In a Dream app, the process of a keep-alive connection can live for minutes, so its late replies stay for minutes too. When many processes do this, the BEAM can stop because it has no memory left.

### Strings built in a loop

A Gleam `String` is a binary. `<>` makes a new binary, and it copies the bytes of both sides into it:

#### Wrong: put each line in front of the text <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_strings.gleam#L6-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: puts each line in front of the text so far. Each step copies
/// all of the text so far.
pub fn report_by_prepending(lines: List(String)) -> String {
  list.fold(lines, "", fn(text, line) { line <> "\n" <> text })
}
```

The runtime can make one case fast. When you add to the end of a binary, and nothing else holds the old binary, the runtime grows the binary in place:

#### Add each line to the end of the text <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_strings.gleam#L12-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Adds each line to the end of the text so far. The runtime can grow
/// the text in place when nothing else holds the old text.
pub fn report_by_appending(lines: List(String)) -> String {
  list.fold(lines, "", fn(text, line) { text <> line <> "\n" })
}
```

A string tree adds a piece at the front or at the end with no copy, and joins the pieces one time at the end:

#### Fix: join the lines one time at the end <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_strings.gleam#L18-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: collect the pieces in a string tree, and join them one time at
/// the end
pub fn report(lines: List(String)) -> String {
  list.fold(lines, string_tree.new(), fn(tree, line) {
    tree
    |> string_tree.append(line)
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}
```

The test counts the reductions, the units of work of the scheduler, for 2,000 lines and for 8,000 lines:

#### The work for 4 times the lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_strings.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
4 times the lines, 2000 to 8000:
report_by_prepending does more than 8 times the work: True
report_by_appending does less than 5 times the work: True
report does less than 5 times the work: True
```

The work of `report_by_prepending` grows with the square of the lines: 4 times the lines is more than 8 times the work. The other two grow in line with the lines. Use [`string_tree`](https://hexdocs.pm/gleam_stdlib/1.0.5/gleam/string_tree.html) for text, and [`bytes_tree`](https://hexdocs.pm/gleam_stdlib/1.0.5/gleam/bytes_tree.html) for bytes, when you build in a loop. They keep the work in line with the size, whatever the order of the pieces.

## State

### State in the process dictionary

Each process has a process dictionary, a store of keys and values that only that process can see. Gleam has no API for it, but Erlang's `get` and `put` are one `@external` away:

#### Wrong: count visits in the process dictionary <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_process_dictionary.gleam#L13-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(visits: Table)
}

type Key {
  VisitCount
}

@external(erlang, "erlang", "get")
fn get(key: Key) -> Dynamic

@external(erlang, "erlang", "put")
fn put(key: Key, value: Int) -> Dynamic

/// Wrong: counts visits in the process dictionary of the process that
/// runs the request
pub fn count_in_process_dictionary(
  _request: Request,
  _context,
  _services: Services,
) -> Response {
  let count = decode.run(get(VisitCount), decode.int) |> result.unwrap(0)
  let _old = put(VisitCount, count + 1)
  text_response(status.ok, int.to_string(count + 1))
}
```

The process dictionary belongs to the process, and the process belongs to the connection. Keep a count that every request shares in an ETS table, with the module of [One process that every request calls](#one-process-that-every-request-calls):

#### Fix: count visits in an ETS table <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_process_dictionary.gleam#L39-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: counts visits in an ETS table that every request shares
pub fn count_in_table(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  let count = beam_guide_cache.increment(services.visits, "visits")
  text_response(status.ok, int.to_string(count))
}

pub fn app_router() -> Router(context, Services) {
  router()
  |> route(
    method: Get,
    path: "/dictionary",
    controller: count_in_process_dictionary,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/table",
    controller: count_in_table,
    middleware: [],
  )
}
```

The test sends two requests on one keep-alive connection, then one request on a new connection, to each counter:

#### Visit counts on different connections <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_process_dictionary.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Process dictionary, two requests on one connection: 1, 2
Process dictionary, a request on a new connection: 1
ETS table, three requests on three connections: 1, 2, 3
```

The count in the process dictionary is neither one count for each request nor one count for the app. The second request on the connection sees the value of the first one. On a connection that a proxy shares between many users, the data of one user can go to the next user. A new connection starts at 1 again. The ETS count is one count for the app. `ets:update_counter` adds 1 in one step, so two requests cannot both read 1 and write 2.

Gleam has no global variables. A module constant is fixed when you compile, so it cannot hold state.

### An ETS table dies with its owner

The process that makes an ETS table owns it, and the table goes away when that process ends. A table that a request makes goes away with the request:

#### Wrong: make the table in a request <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_ets.gleam#L6-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: called from a request, the request process owns the table, and
/// the table goes away when the request ends
pub fn cache_for_request() -> Table {
  let table = beam_guide_cache.new_table()
  beam_guide_cache.insert(table, "sku-1", 100)
  table
}
```

Make the table in a process that starts with the app and keeps running. Put the table in your services, so each request can read it:

#### Fix: a process that owns the table <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_ets.gleam#L14-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: start a process at startup that owns the table, and keep it
/// running. Give the table to the requests in your services.
pub fn start_table_owner() -> actor.StartResult(Table) {
  actor.new_with_initialiser(1000, fn(_subject) {
    let table = beam_guide_cache.new_table()
    beam_guide_cache.insert(table, "sku-1", 100)
    actor.initialised(Nil)
    |> actor.returning(table)
    |> Ok
  })
  |> actor.start
}
```

The test makes each table, runs a request process that ends, and then looks for the table:

#### Tables after the request ends <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_ets.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
cache_for_request, after the request process ended, the table exists: False
start_table_owner, after the request process ended, the table exists: True, sku-1: Ok(100)
```

A read of a table that went away crashes the request with `badarg`. Start the owner process under your supervisor. When the owner crashes, its table goes too, so the new owner must fill the table again. Erlang's [`ets`](https://www.erlang.org/docs/28/apps/stdlib/ets.html) module also has an `heir` option, which gives the table to another process when the owner ends.

### Adding to the end of a list in a loop

A Gleam list is a linked list. Adding to the front is one step. `list.append` copies the whole first list, so a loop that appends copies the list again on each step:

#### Wrong: append to the list in a loop <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_lists.gleam#L5-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: `list.append` copies the whole list on each step
pub fn squares_by_appending(numbers: List(Int)) -> List(Int) {
  list.fold(numbers, [], fn(squares, number) {
    list.append(squares, [number * number])
  })
}
```

Add each item to the front, then reverse the list one time:

#### Fix: add to the front, then reverse <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_lists.gleam#L12-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: add each item to the front, then reverse the list one time
pub fn squares(numbers: List(Int)) -> List(Int) {
  list.fold(numbers, [], fn(squares, number) { [number * number, ..squares] })
  |> list.reverse
}
```

#### The work for 4 times the numbers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_lists.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
4 times the numbers, 2000 to 8000:
squares_by_appending does more than 8 times the work: True
squares does less than 5 times the work: True
```

Like the string that you build at the front, the work of `squares_by_appending` grows with the square of the list. Most functions of [`gleam/list`](https://hexdocs.pm/gleam_stdlib/1.0.5/gleam/list.html), such as `list.map`, already work this way.

### Recursion that is not a tail call

A function call is a tail call when it is the last thing that the function does. The BEAM runs a tail call with no new stack frame. A call that is not a tail call keeps a frame until it returns:

#### Wrong: add after the recursive call <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_recursion.gleam#L3-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: the addition happens after the recursive call returns, so each
/// call keeps a stack frame until the end
pub fn sum_to(n: Int) -> Int {
  case n {
    0 -> 0
    _ -> n + sum_to(n - 1)
  }
}
```

Carry the result in an argument, so the recursive call is the last thing that the function does:

#### Fix: carry the total in an argument <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_recursion.gleam#L12-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: the recursive call is the last thing the function does, so the
/// stack does not grow
pub fn sum_to_with_total(n: Int, total: Int) -> Int {
  case n {
    0 -> total
    _ -> sum_to_with_total(n - 1, total + n)
  }
}
```

The test runs each function in a process that can use at most 1,000,000 words (8 MB) of heap and stack:

#### Recursion in a process with a heap limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_recursion.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
sum_to(1000000), at most 1000000 words of heap: the runtime stopped the process at the limit
sum_to_with_total(1000000, 0), at most 1000000 words of heap: 500000500000
```

The BEAM has no fixed stack size, so `sum_to` does not overflow a stack as it does in other languages. Its stack grows into the memory of the process, up to the memory of the machine. Here the limit stops it. `sum_to_with_total` uses the same small stack for each number.

A recursion that is not a tail call is fine when the depth is small, such as the parts of a path. The Erlang efficiency guide says the same in [Functions](https://www.erlang.org/docs/28/system/eff_guide_functions.html). Use a tail call when the depth comes from input, such as the items of a request body.

## Time and the runtime

### System time for a duration

System time is the time of day. The BEAM moves it when the clock of the machine changes, for example when NTP corrects the clock:

#### Wrong: measure a duration with the time of day <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_time.gleam#L6-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Wrong: system time is the time of day, and the runtime moves it when
/// the clock of the machine changes, also backwards. A duration from it
/// can be too long, too short or below zero.
pub fn milliseconds_by_clock(work: fn() -> a) -> Int {
  let start = timestamp.system_time()
  let _ = work()
  timestamp.difference(start, timestamp.system_time())
  |> duration.to_milliseconds
}
```

Monotonic time only goes forward. Use it for durations and timeouts:

#### Fix: measure a duration with monotonic time <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_time.gleam#L16-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
type TimeUnit {
  Millisecond
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: TimeUnit) -> Int

/// Fix: monotonic time never goes back, so use it for durations
pub fn milliseconds(work: fn() -> a) -> Int {
  let start = monotonic_time(Millisecond)
  let _ = work()
  monotonic_time(Millisecond) - start
}
```

`TimeUnit` is a custom type with one variant. Gleam sends `Millisecond` to Erlang as the atom `millisecond`, so `monotonic_time(Millisecond)` is `erlang:monotonic_time(millisecond)`.

#### Monotonic time in this runtime <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_time.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The time warp mode of this runtime: multi_time_warp
10000 readings of monotonic time, the times it went back: 0
milliseconds of a function that does nothing is 0 or more: True
```

The test cannot change the clock of the machine, so it shows the mode of the runtime. In `multi_time_warp` mode, the default since OTP 26, system time can move forwards and backwards at any time. See [Time and Time Correction in Erlang](https://www.erlang.org/docs/28/apps/erts/time_correction.html). `timestamp.system_time()` reads that system time, so a duration from it can be wrong. Use `timestamp` for the time of an event, such as a `created_at` column.

### Sleep in a test

A test that sleeps guesses how long the work takes:

#### Wrong: sleep, then look for the result <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_waiting.gleam#L5-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts a job that makes a thumbnail, and sends its name to `done`
pub fn start_thumbnail(
  image: String,
  make_thumbnail: fn(String) -> String,
  done: Subject(String),
) -> Nil {
  process.spawn(fn() { process.send(done, make_thumbnail(image)) })
  Nil
}

/// Wrong: guesses that 100 milliseconds is enough. On a busy machine it
/// is not, and the test fails at random. On a fast one, it wastes time.
pub fn thumbnail_after_sleep(done: Subject(String)) -> Result(String, Nil) {
  process.sleep(100)
  process.receive(done, within: 0)
}
```

Let the work send a message when it is done, and wait for that message:

#### Fix: wait for the done message <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/beam_guide_waiting.gleam#L22-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Fix: wait for the message. The test goes on when the job is done, and
/// fails only when the job takes longer than 5 seconds.
pub fn thumbnail_when_done(done: Subject(String)) -> Result(String, Nil) {
  process.receive(done, within: 5000)
}
```

The test holds the thumbnail job until both functions have looked for the result:

#### Two ways to wait for a job <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/beam_guide_waiting.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
thumbnail_after_sleep, the job is not done after 100 ms: Error(Nil)
thumbnail_when_done: Ok("photo-small.jpg")
```

On a busy CI machine the job takes longer than 100 ms, and the test with the sleep fails at random. On a fast machine, the sleep wastes 100 ms in each test. The receive returns as soon as the message is there. Its timeout is only the time after which the test fails.

### Native code that blocks a scheduler

The BEAM stops each process after a set amount of work, and lets the next one run. That is why one busy request cannot stop the others. Native code, such as a NIF (a function in C or Rust that the BEAM calls), runs outside of this control. A NIF that runs for a long time keeps its scheduler for all of that time, and the processes in the queue of that scheduler wait. The runtime can also show odd delays in timers and in its own work.

You meet this when a package uses a NIF for slow work, such as hashing a password or resizing an image. A good package marks such a NIF as dirty, so it runs on a separate set of schedulers. Before you use a package with native code in a request, look in its docs for dirty schedulers. If it does not use them, run its slow calls in a few worker processes, so it can block those processes only. See [erl_nif](https://www.erlang.org/docs/28/apps/erts/erl_nif.html) for the rules that NIF authors follow.

## Common pitfalls

| Symptom | Cause | Fix |
|:---|:---|:---|
| A client waits for work that it does not need, such as an email | The controller does the slow work itself | Send the work to a worker process and answer `202` ([Slow work in a request](#slow-work-in-a-request)) |
| Requests get slow under load, and the mailbox of one process grows | Each request calls the same process | Read shared data from an ETS table ([One process that every request calls](#one-process-that-every-request-calls)) |
| A request process ends with no answer when a helper crashes | The helper is linked to the request process | Start the helper unlinked and monitor it ([Links and monitors](#links-and-monitors)) |
| Requests hang, and nothing is in the log | A call with no timeout, or with a timeout longer than the client waits | Give each call a timeout that fits the request ([A call with no timeout](#a-call-with-no-timeout)) |
| Bad input gives `500` and a crash report | `let assert` on client input | Use `case` and answer `400` ([`let assert` in request code](#let-assert-in-request-code)) |
| The runtime stops with a full atom table | Atoms made from client input | Map known values to a custom type ([Atoms are never freed](#atoms-are-never-freed)) |
| Memory grows when you pass data between processes | Each message is a copy | Send an ID or one binary ([Every message is a copy](#every-message-is-a-copy)) |
| Memory stays high after uploads end | A kept slice holds the whole upload | Copy the slice ([A slice of a large binary keeps the whole binary](#a-slice-of-a-large-binary-keeps-the-whole-binary)) |
| One process uses more and more memory | Its mailbox grows: a slow receiver, or messages that nothing receives | Make senders wait, and receive late replies in a helper ([A mailbox that grows without limit](#a-mailbox-that-grows-without-limit)) |
| Building a large text or list is slow | `<>` at the front, or `list.append`, in a loop | Use `string_tree`, or add to the front and reverse ([Strings built in a loop](#strings-built-in-a-loop), [Adding to the end of a list in a loop](#adding-to-the-end-of-a-list-in-a-loop)) |
| A request sees a value from an earlier request | State in the process dictionary | Keep shared state in ETS ([State in the process dictionary](#state-in-the-process-dictionary)) |
| `badarg` from an ETS read | The process that owned the table ended | Make the table in a long-lived process ([An ETS table dies with its owner](#an-ets-table-dies-with-its-owner)) |
| A process uses a lot of memory on a deep input | Recursion that is not a tail call | Carry the result in an argument ([Recursion that is not a tail call](#recursion-that-is-not-a-tail-call)) |
| A duration is below zero or too long | System time moved | Use monotonic time ([System time for a duration](#system-time-for-a-duration)) |
| A test fails at random on CI | The test sleeps for a guessed time | Wait for a message ([Sleep in a test](#sleep-in-a-test)) |
| All requests get slow while one call runs | A NIF blocks a scheduler | Use dirty NIFs, or a few worker processes ([Native code that blocks a scheduler](#native-code-that-blocks-a-scheduler)) |

## Where to go next

- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): start errors, body limits and a graceful stop.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html): send and receive large bodies without holding them in memory.
- [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html): a process for each client, with messages from the rest of the app.
- [Why the BEAM?](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/why-beam.md): why Dream runs on the BEAM.
- [`gleam/erlang/process`](https://hexdocs.pm/gleam_erlang/1.3.0/gleam/erlang/process.html): processes, subjects, links, monitors and selectors.
- [`gleam/otp/actor`](https://hexdocs.pm/gleam_otp/1.2.0/gleam/otp/actor.html) and [`gleam/otp/static_supervisor`](https://hexdocs.pm/gleam_otp/1.2.0/gleam/otp/static_supervisor.html): long-lived processes and supervisors.
- [The Erlang efficiency guide](https://www.erlang.org/docs/28/system/efficiency_guide.html): how the BEAM uses memory and time.
