# Push live updates with server-sent events

You want the browser to see new data the moment the server has it: a counter, a progress bar, a feed of notifications. The browser doesn't need to send anything back on the same connection. That's what server-sent events (SSE) are for: one long HTTP response that carries events, which the browser's `EventSource` reads and reconnects on its own. This guide builds an SSE endpoint with Dream's typed SSE actors, using `examples/sse`, and every output is what that server answers.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [SSE, WebSockets or streaming](#sse-websockets-or-streaming)
- [Overview: How Dream SSE Works](#overview-how-dream-sse-works)
- [Step 1: Define a Dependencies type](#step-1-define-a-dependencies-type)
- [Step 2: Define an SSE route and controller](#step-2-define-an-sse-route-and-controller)
- [Step 3: on_init, run when the actor starts](#step-3-on_init-run-when-the-actor-starts)
- [Step 4: on_message, handle messages and send events](#step-4-on_message-handle-messages-and-send-events)
- [Step 5: Event builders](#step-5-event-builders)
- [Step 6: See the stream](#step-6-see-the-stream)
- [Broadcasting with SSE](#broadcasting-with-sse)
- [Client-side: EventSource](#client-side-eventsource)
- [Using Middleware with SSE](#using-middleware-with-sse)
- [When a connection is refused or ends](#when-a-connection-is-refused-or-ends)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- An `/events` route that upgrades the request to an SSE connection run by its own actor.
- A counter that sends `data: {"count": N}` every second.
- Named events, event ids and a retry time.
- Events pushed from other code through a broadcaster.
- A browser client with `EventSource`, and a route that middleware refuses.

## Before you start

You need Dream and `gleam_erlang`, for the actor's process types:

```sh
gleam add dream gleam_erlang
```

Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) first. The examples on this page are small and include their imports. The example runs from the Dream repository with `make run` in `examples/sse`, on port 8081.

## SSE, WebSockets or streaming

Dream supports three real-time patterns:

- **Server-Sent Events (SSE)**: one-way event stream from server to browser.
  Simple, automatic reconnection, works over plain HTTP.
- **WebSockets**: bi-directional, long-lived connections. Both client and
  server can send messages at any time.
- **Streaming responses**: send large responses in chunks (files, CSV exports).

Use SSE when:

- The server pushes updates and the client only listens.
- You want **automatic reconnection** (built into the browser's `EventSource`).
- You need **event IDs** so the client can resume after disconnection.
- You are building **live dashboards**, notification feeds, or progress indicators.

If the client also needs to send messages, use
[WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) instead. For large file downloads or one-off
streams, see the [Streaming Guide](https://hexdocs.pm/dream/3.0.0/guides/streaming.html).

## Overview: How Dream SSE Works

Dream's SSE support lives in the Mist server adapter module:

### The SSE module import <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/servers/mist/sse
```

From your application's point of view, you work with:

- `sse.SSEConnection`: an opaque handle to the SSE connection.
- `sse.Event`: a structured SSE event built with `event`, `event_name`,
  `event_id`, and `event_retry`.
- `sse.Action(state, message)`: what to do after handling a message.
- `sse.upgrade_to_sse`: called from a controller to upgrade HTTP to SSE.

The high-level flow is:

1. A browser makes an HTTP request to a path in your app
   (for example, `GET /events` with `Accept: text/event-stream`).
2. Your Dream **router** sends that request to a controller.
3. The controller calls `upgrade_to_sse` instead of returning a normal
   HTTP response.
4. Dream and Mist spawn a **dedicated OTP actor** for this connection.
5. Dream calls your handler functions:
   - `on_init` (once, when the actor starts, and receives a `Subject(message)`).
   - `on_message` (every time a message is received by the actor).

Unlike the old `sse_response` function which used chunked encoding and
would stall after a few events, `upgrade_to_sse` gives the SSE connection
its own mailbox, completely avoiding TCP message contention.

## Step 1: Define a Dependencies type

Dream has a strong rule: **no closures in controllers or handlers**.
Instead of capturing variables from outer scopes, you pass everything
explicitly through function parameters.

For SSE we usually create a small `Dependencies` type. The example below
shows the top of the controller module: the imports that all of the steps
use, then the type.

### Imports and the Dependencies type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L6-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/header.{get_header}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/http/status
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int
import gleam/option.{None, Some}

pub type Dependencies {
  Dependencies(counter_start: Int)
}
```

## Step 2: Define an SSE route and controller

Add a route in your router that points to a controller function:

### A router with an SSE route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_router.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{Get}
import dream/router.{route, router}
import snippets/sse_guide_controller as sse_controller

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/events",
    controller: sse_controller.handle_events,
    middleware: [],
  )
}
```

An SSE controller has the same shape as a regular controller:

### An SSE controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L19-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_events(request: Request, _context, _services) -> Response {
  let dependencies = Dependencies(counter_start: 0)

  sse.upgrade_to_sse(
    request,
    dependencies: dependencies,
    on_init: handle_init,
    on_message: handle_message,
  )
}
```

Instead of returning a `Response` directly, the controller calls
`upgrade_to_sse`. Dream returns a dummy HTTP response to satisfy the
controller type, but the real work happens in the SSE actor.

## Step 3: on_init, run when the actor starts

`on_init` runs **once**, right after the SSE actor is created. It receives:

- A `Subject(message)`: the actor's mailbox address. External code can
  `process.send(subject, message)` to push messages into the actor.
- Your `Dependencies`.

It returns a tuple of initial state and an optional `Selector(message)`.
The actor always receives messages sent to its subject. With
`Some(selector)`, it also receives the messages that the selector selects,
for example events from a broadcaster (see
[Broadcasting with SSE](#broadcasting-with-sse)). This handler needs no
other messages, so it returns `None`:

### The on_init handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L30-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Tick {
  Tick
}

pub type State {
  State(count: Int, self: process.Subject(Tick))
}

pub fn handle_init(
  subject: process.Subject(Tick),
  dependencies: Dependencies,
) -> #(State, option.Option(process.Selector(Tick))) {
  // Send the first tick to start the loop
  process.send(subject, Tick)
  #(State(count: dependencies.counter_start, self: subject), None)
}
```

The actor stores the subject in state so `on_message` can schedule
future messages to itself.

Do not stop the actor from `on_init` (for example, by sending a message
that makes `on_message` return `stop_connection()` at once). If the actor
stops before the connection is handed over to it, the server writes an
extra 500 response.

## Step 4: on_message, handle messages and send events

Every time a message arrives, Dream calls your `on_message` function.
The handler below sends one event for each tick. `tick_event` builds the
event in a function of its own, so a test can call it (see
[Test your code](#test-your-code)). When `send_event`
returns an error, the client has gone away, so the handler stops the
actor instead of ticking forever.

`on_message` must return an `Action(state, message)` created by one of:

- `sse.continue_connection(state)`: keep the actor running.
- `sse.continue_connection_with_selector(state, selector)`: keep running
  and change the message selector.
- `sse.stop_connection()`: shut down the actor.

### The on_message handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L47-L68"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn handle_message(
  state: State,
  _message: Tick,
  connection: sse.SSEConnection,
  _dependencies: Dependencies,
) -> sse.Action(State, Tick) {
  case sse.send_event(connection, tick_event(state.count)) {
    Ok(Nil) -> {
      // Schedule the next tick
      process.send_after(state.self, 1000, Tick)
      sse.continue_connection(State(..state, count: state.count + 1))
    }
    // The client has gone away, so stop the actor
    Error(Nil) -> sse.stop_connection()
  }
}

pub fn tick_event(count: Int) -> sse.Event {
  sse.event("{\"count\": " <> int.to_string(count) <> "}")
  |> sse.event_name("tick")
  |> sse.event_id(int.to_string(count))
}
```

## Step 5: Event builders

SSE events are built with a pipeline of builder functions:

### Building events <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_events.gleam#L7-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn build_minimal_event() -> sse.Event {
  // Minimal event (data only)
  sse.event("hello world")
}

pub fn build_full_event() -> sse.Event {
  // Event with all optional fields
  sse.event("{\"count\": 42}")
  // event: tick
  |> sse.event_name("tick")
  // id: 42
  |> sse.event_id("42")
  // retry: 5000
  |> sse.event_retry(5000)
}
```

- `event(data)`: creates an event. The only required field.
- `event_name(event, name)`: sets the event type. Clients filter on this
  with `EventSource.addEventListener("name", ...)`.
- `event_id(event, id)`: sets the event ID. The browser sends
  `Last-Event-ID` on reconnection so you can resume.
- `event_retry(event, ms)`: tells the client how long to wait before
  reconnecting after a connection loss.

To stop the actor when the client has gone away, check the result of
`send_event`:

### Sending an event <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_events.gleam#L23-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn send_event_or_stop(
  state: state,
  connection: sse.SSEConnection,
  event: sse.Event,
) -> sse.Action(state, message) {
  case sse.send_event(connection, event) {
    Ok(Nil) -> sse.continue_connection(state)
    Error(Nil) -> sse.stop_connection()
  }
}
```


## Step 6: See the stream

The example's `/events` route runs the counter of the steps above. Ask for it with `-N`, so curl prints each event as it arrives, and stop after the first event:

### Read the headers and the first event <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme.sh#L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -s -i -N http://localhost:8081/events | head -n 8
```

### The headers and the first event <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme_output.txt#L7-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
transfer-encoding: chunked
content-type: text/event-stream
cache-control: no-cache
connection: keep-alive

data: {"count": 0}

```

`content-type: text/event-stream` and `cache-control: no-cache` come from Dream. Each event is its `data:` line and a blank line. The README of the example reads three events:

### Read three events <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme.sh#L3"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -N http://localhost:8081/events | head -n 6
```

### Three events <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme_output.txt#L1-L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
data: {"count": 0}

data: {"count": 1}

data: {"count": 2}

```

## Broadcasting with SSE

For non-trivial apps, you often need external code (other controllers,
background jobs, etc.) to push events into SSE connections. Use the
`Subject(message)` received in `on_init`:

1. Store the subject in a shared location (broadcaster, ETS, etc.).
2. From anywhere in your app, `process.send(subject, your_message)`.
3. The SSE actor's `on_message` receives it and sends an event to the client.

Dream's `broadcaster` module works with SSE. The controller below
subscribes in `on_init` and returns the channel's selector:

1. `on_init` subscribes to the broadcaster and returns
   `Some(selector)`. The actor then receives each published event.
2. `on_message` sends each event to the client.

The actor also keeps its own subject. `upgrade_to_sse` merges the selector
from `on_init` with that subject, so messages sent to the subject still
arrive.

### An SSE controller that uses a broadcaster <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_broadcast.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse
import dream/services/broadcaster
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}

pub type AppEvent {
  AppEvent(text: String)
}

pub type Dependencies {
  Dependencies(event_bus: broadcaster.Broadcaster(AppEvent))
}

pub fn handle_events(
  request: Request,
  _context,
  event_bus: broadcaster.Broadcaster(AppEvent),
) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Dependencies(event_bus: event_bus),
    on_init: handle_init,
    on_message: handle_message,
  )
}

pub fn handle_init(
  _subject: process.Subject(AppEvent),
  dependencies: Dependencies,
) -> #(Int, option.Option(process.Selector(AppEvent))) {
  let selector =
    broadcaster.subscribe(dependencies.event_bus)
    |> broadcaster.channel_to_selector
  #(0, Some(selector))
}

fn handle_message(
  count: Int,
  message: AppEvent,
  connection: sse.SSEConnection,
  _dependencies: Dependencies,
) -> sse.Action(Int, AppEvent) {
  let AppEvent(text) = message
  let event =
    sse.event(text)
    |> sse.event_id(int.to_string(count))
  case sse.send_event(connection, event) {
    Ok(Nil) -> sse.continue_connection(count + 1)
    Error(Nil) -> sse.stop_connection()
  }
}
```

Now any code that calls `broadcaster.publish(event_bus, AppEvent(text))`
will deliver the event to all connected SSE clients. The controller takes
the broadcaster as its services value.

## Client-side: EventSource

Browsers have built-in SSE support via `EventSource`. The `sse` example serves this script at `/client.js`:

### The browser client <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/assets/client.js#L1-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
const source = new EventSource("/events");

// Listen for all events (default event type is "message")
source.onmessage = (event) => {
  console.log("data:", event.data);
};

// Listen for named events
source.addEventListener("tick", (event) => {
  console.log("tick:", event.data, "id:", event.lastEventId);
});

// Handle errors (browser reconnects automatically)
source.onerror = (event) => {
  console.log("SSE connection lost, reconnecting...");
};
```

The browser automatically reconnects if the connection drops, sending
`Last-Event-ID` so your server can resume from the right point.

## Using Middleware with SSE

SSE connections work seamlessly with Dream middleware. Any headers added
by middleware (CORS, security headers, authentication, etc.) are included
in the SSE response sent to the client.

### A CORS middleware on an SSE route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_middleware.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/header.{Header}
import dream/http/request.{Get}
import dream/http/response.{Response}
import dream/router.{route, router}
import snippets/sse_guide_controller as sse_controller

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/events",
    controller: sse_controller.handle_events,
    middleware: [cors_middleware],
  )
}

fn cors_middleware(request, context, services, next) {
  let response = next(request, context, services)
  Response(..response, headers: [
    Header("Access-Control-Allow-Origin", "*"),
    ..response.headers
  ])
}
```

The `Access-Control-Allow-Origin` header will be sent to the client as
part of the SSE response, enabling cross-origin `EventSource` connections.

If middleware returns a non-200 response (for example, a 401 from an
authentication check), the SSE upgrade is not performed and the error
response is returned to the client instead.


## When a connection is refused or ends

Middleware runs before the upgrade, so it can refuse the connection with a normal answer. The example's `/events/rejected` route has a middleware that always does:

### Ask the refused route <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme.sh#L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:8081/events/rejected
```

### A 401 before any event <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme_output.txt#L15-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 401 Unauthorized
content-type: text/plain; charset=utf-8
content-length: 12
date: (the time of the request)
connection: keep-alive

Unauthorized
```

`EventSource` treats a non-200 answer as fatal and stops reconnecting, so refuse with a status only when the client must not retry.

When the client goes away (above, `head` closes the connection after a few lines), the next `send_event` returns `Error(Nil)`. Return `sse.stop_connection()` then, as `send_event_or_stop` in Step 5 does, and the actor ends. If you ignore the error, the actor keeps running and sends into a closed connection.

## Test your code

The SSE connection needs a client, but the code around it doesn't. `tick_event` builds the event, `on_init` gets a subject that a test can make, and a controller can decide before the upgrade. This controller refuses a client without the token:

### Decide before the upgrade <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_guide_controller.gleam#L70-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_private_events(request: Request, context, services) -> Response {
  // Decide before the upgrade: a refused client gets a normal answer
  case get_header(request.headers, "Authorization") {
    Some("Bearer secret-token") -> handle_events(request, context, services)
    _ -> response.text_response(status.unauthorized, "Unauthorized")
  }
}
```

The test below calls these functions and `on_init` with no server. The `on_init` of the broadcast controller subscribes the test process, so the test publishes an event and receives it:

### Test the code around the connection <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_sse_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// SSE guide: a test of the code around the SSE connection
////
//// The functions are from test/snippets/sse_guide_controller.gleam and
//// test/snippets/sse_guide_broadcast.gleam. The test needs no server: it
//// calls the event builder, the decision before the upgrade, and on_init
//// with a subject of the test process.

import dream/context.{EmptyContext}
import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request, Text}
import dream/router.{EmptyServices}
import dream/servers/mist/sse
import dream/services/broadcaster
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process
import gleam/option.{None, Some}
import snippets/sse_guide_broadcast.{AppEvent}
import snippets/sse_guide_controller.{Dependencies, Tick}

fn events_request(headers: List(Header)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/events/private",
    query: "",
    params: [],
    host: None,
    port: None,
    remote_address: None,
    body: Text(""),
    headers: headers,
    cookies: [],
    content_type: None,
    content_length: None,
  )
}

pub fn tests() -> TestSuite {
  describe("SSE ticker", [
    group("tick_event", [
      it("names the event tick and numbers it with the count", fn() {
        // Act
        let event = sse_guide_controller.tick_event(3)

        // Assert
        event
        |> should
        |> be_equal(
          sse.event("{\"count\": 3}")
          |> sse.event_name("tick")
          |> sse.event_id("3"),
        )
        |> or_fail_with("tick 3 should carry count 3, name tick and id 3")
      }),
    ]),
    group("handle_private_events", [
      it("answers 401 when the token is missing", fn() {
        // Arrange
        let request = events_request([])

        // Act
        let response =
          sse_guide_controller.handle_private_events(
            request,
            EmptyContext,
            EmptyServices,
          )

        // Assert
        response.status
        |> should
        |> be_equal(401)
        |> or_fail_with("a request without a token should get 401")
      }),
      it("upgrades when the token is right", fn() {
        // Arrange
        let request =
          events_request([Header("Authorization", "Bearer secret-token")])

        // Act
        let response =
          sse_guide_controller.handle_private_events(
            request,
            EmptyContext,
            EmptyServices,
          )

        // Assert
        response.status
        |> should
        |> be_equal(200)
        |> or_fail_with("200 tells the server to upgrade to SSE")
      }),
    ]),
    group("handle_init", [
      it("starts the count at counter_start", fn() {
        // Arrange
        let subject = process.new_subject()

        // Act
        let #(state, _selector) =
          sse_guide_controller.handle_init(
            subject,
            Dependencies(counter_start: 5),
          )

        // Assert
        state.count
        |> should
        |> be_equal(5)
        |> or_fail_with("the first tick should carry counter_start")
      }),
      it("sends the first tick to the actor", fn() {
        // Arrange
        let subject = process.new_subject()

        // Act
        let _started =
          sse_guide_controller.handle_init(
            subject,
            Dependencies(counter_start: 0),
          )

        // Assert
        process.receive(subject, 0)
        |> should
        |> be_equal(Ok(Tick))
        |> or_fail_with("on_init should send Tick to its own subject")
      }),
      it("subscribes the actor to the event bus", fn() {
        // Arrange
        let assert Ok(event_bus) = broadcaster.start_broadcaster()
        let dependencies = sse_guide_broadcast.Dependencies(event_bus:)
        let #(_count, selector) =
          sse_guide_broadcast.handle_init(process.new_subject(), dependencies)

        // Act
        broadcaster.publish(event_bus, AppEvent("hello"))

        // Assert
        receive_from(selector)
        |> should
        |> be_equal(Ok(AppEvent("hello")))
        |> or_fail_with("a published event should reach the actor")
      }),
    ]),
  ])
}

fn receive_from(
  selector: option.Option(process.Selector(message)),
) -> Result(message, Nil) {
  case selector {
    Some(selector) -> process.selector_receive(selector, 100)
    None -> Error(Nil)
  }
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_sse_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
SSE ticker
  handle_init
    ✓ sends the first tick to the actor
    ✓ starts the count at counter_start
    ✓ subscribes the actor to the event bus
  handle_private_events
    ✓ answers 401 when the token is missing
    ✓ upgrades when the token is right
  tick_event
    ✓ names the event tick and numbers it with the count

Summary: 6 run, 0 failed, 6 passed in 0ms
```

A `200` from the controller tells the server to upgrade. A test can't go further without a client:

- `on_message` gets an `SSEConnection`. It's an opaque type, and only the server makes one, so a test can't call `handle_message`.
- `Event` and `Action` are opaque too. A test can compare an event with one built the same way, as the `tick_event` test does. It can't read the fields of the event or the text that the client gets.

The `examples/sse` project tests those parts with a real server and a real client. Its integration tests are written in Gherkin (Cucumber), and they:

- Start a real Dream server.
- Connect with HTTPoison's async streaming mode.
- Parse SSE events from the chunked HTTP response.
- Assert that events stream continuously without stalling.

To run them:

### Run the integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/sse && make test-integration)
```

## Common pitfalls

- **The actor keeps running after the client left.** Check the result of `send_event` and return `sse.stop_connection()` on `Error(Nil)`.
- **A proxy buffers the stream.** Some proxies hold a response until it ends. Turn buffering off for the SSE path (for nginx, `proxy_buffering off`), or the browser sees nothing.
- **Work in the controller.** The controller only upgrades. Start timers and subscriptions in `on_init`, which runs in the actor.
- **Browser connection limits.** Over HTTP/1.1 a browser opens few connections to one host, and each SSE stream holds one. Serve over HTTP/2, see [Serve HTTPS and HTTP/2](https://hexdocs.pm/dream/3.0.0/guides/http2.html), or share one stream between tabs.

## Where to go next

- Read the source for `src/dream/servers/mist/sse.gleam` to see the full
  API (`SSEConnection`, `Event`, `Action`, `send_event`, etc.).
- Explore `src/dream/services/broadcaster.gleam` for the pub/sub
  implementation.
- Run and modify the [`examples/sse/`](https://github.com/TrustBound/dream/tree/3.0.0/examples/sse) example to
  fit your own use case.
- Revisit the [WebSocket Guide](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) to compare SSE with
  bi-directional connections.
- See the [Streaming Guide](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) for chunked transfer encoding
  and file downloads.
