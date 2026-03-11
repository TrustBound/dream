# Server-Sent Events in Dream

Push real-time updates from server to client using typed SSE connections backed by dedicated OTP actors.

This guide assumes you:

- Know a little HTTP (requests, responses, status codes).
- May be **new to Gleam** – examples are small and include imports and types.

We will cover:

- When to use SSE vs WebSockets vs HTTP streaming.
- How Dream upgrades an HTTP request to an SSE connection.
- Writing `on_init` and `on_message` handlers.
- Building and sending events.
- Broadcasting events from external code.
- Connecting from JavaScript with `EventSource`.
- Where to look for a full example and tests.

## SSE vs WebSockets vs Streaming

Dream supports three real-time patterns:

- **Server-Sent Events (SSE)** – one-way event stream from server to browser.
  Simple, automatic reconnection, works over plain HTTP.
- **WebSockets** – bi-directional, long-lived connections. Both client and
  server can send messages at any time.
- **Streaming responses** – send large responses in chunks (files, CSV exports).

Use SSE when:

- The server pushes updates and the client only listens.
- You want **automatic reconnection** (built into the browser's `EventSource`).
- You need **event IDs** so the client can resume after disconnection.
- You are building **live dashboards**, notification feeds, or progress indicators.

If the client also needs to send messages, use
[WebSockets](websockets.md) instead. For large file downloads or one-off
streams, see the [Streaming Guide](streaming.md).

## Overview: How Dream SSE Works

Dream's SSE support lives in the Mist server adapter module:

```gleam
import dream/servers/mist/sse
```

From your application's point of view, you work with:

- `sse.SSEConnection` – an opaque handle to the SSE connection.
- `sse.Event` – a structured SSE event built with `event`, `event_name`,
  `event_id`, and `event_retry`.
- `sse.Action(state, message)` – what to do after handling a message.
- `sse.upgrade_to_sse` – called from a controller to upgrade HTTP to SSE.

The high-level flow is:

1. A browser makes an HTTP request to a path in your app
   (for example, `GET /events` with `Accept: text/event-stream`).
2. Your Dream **router** sends that request to a controller.
3. The controller calls `upgrade_to_sse` instead of returning a normal
   HTTP response.
4. Dream and Mist spawn a **dedicated OTP actor** for this connection.
5. Dream calls your handler functions:
   - `on_init` (once, when the actor starts — receives a `Subject(message)`).
   - `on_message` (every time a message is received by the actor).

Unlike the old `sse_response` function which used chunked encoding and
would stall after a few events, `upgrade_to_sse` gives the SSE connection
its own mailbox, completely avoiding TCP message contention.

## Step 1: Define a Dependencies type

Dream has a strong rule: **no closures in controllers or handlers**.
Instead of capturing variables from outer scopes, you pass everything
explicitly through function parameters.

For SSE we usually create a small `Dependencies` type:

```gleam
pub type Dependencies {
  Dependencies(counter_start: Int)
}
```

## Step 2: Define an SSE route and controller

Add a route in your router that points to a controller function:

```gleam
import dream/http/request.{Get}
import dream/router.{route, router}
import controllers/sse_controller

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

```gleam
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/sse

pub fn handle_events(request: Request, _context, _services) -> Response {
  let deps = Dependencies(counter_start: 0)

  sse.upgrade_to_sse(
    request,
    dependencies: deps,
    on_init: handle_init,
    on_message: handle_message,
  )
}
```

Instead of returning a `Response` directly, the controller calls
`upgrade_to_sse`. Dream returns a dummy HTTP response to satisfy the
controller type, but the real work happens in the SSE actor.

## Step 3: `on_init` – run when the actor starts

`on_init` runs **once**, right after the SSE actor is created. It receives:

- A `Subject(message)` – the actor's mailbox address. External code can
  `process.send(subject, message)` to push messages into the actor.
- Your `Dependencies`.

It returns a tuple of initial state and an optional `Selector(message)`:

```gleam
import gleam/erlang/process
import gleam/option.{None}

pub type Tick {
  Tick
}

pub type State {
  State(count: Int, self: process.Subject(Tick))
}

fn handle_init(
  subject: process.Subject(Tick),
  deps: Dependencies,
) -> #(State, option.Option(process.Selector(Tick))) {
  // Send the first tick to start the loop
  process.send(subject, Tick)
  #(State(count: deps.counter_start, self: subject), None)
}
```

The actor stores the subject in state so `on_message` can schedule
future messages to itself.

## Step 4: `on_message` – handle messages and send events

Every time a message arrives, Dream calls your `on_message` function.
It must return an `Action(state, message)` created by one of:

- `sse.continue_connection(state)` – keep the actor running.
- `sse.continue_connection_with_selector(state, selector)` – keep running
  and change the message selector.
- `sse.stop_connection()` – shut down the actor.

```gleam
import dream/servers/mist/sse
import gleam/erlang/process
import gleam/int

fn handle_message(
  state: State,
  _message: Tick,
  connection: sse.SSEConnection,
  _deps: Dependencies,
) -> sse.Action(State, Tick) {
  let ev =
    sse.event("{\"count\": " <> int.to_string(state.count) <> "}")
    |> sse.event_name("tick")
    |> sse.event_id(int.to_string(state.count))

  let _ = sse.send_event(connection, ev)

  // Schedule the next tick
  process.send_after(state.self, 1000, Tick)
  sse.continue_connection(State(..state, count: state.count + 1))
}
```

## Step 5: Event builders

SSE events are built with a pipeline of builder functions:

```gleam
// Minimal event (data only)
sse.event("hello world")

// Event with all optional fields
sse.event("{\"count\": 42}")
|> sse.event_name("tick")       // event: tick
|> sse.event_id("42")           // id: 42
|> sse.event_retry(5000)        // retry: 5000
```

- `event(data)` – creates an event. The only required field.
- `event_name(event, name)` – sets the event type. Clients filter on this
  with `EventSource.addEventListener("name", ...)`.
- `event_id(event, id)` – sets the event ID. The browser sends
  `Last-Event-ID` on reconnection so you can resume.
- `event_retry(event, ms)` – tells the client how long to wait before
  reconnecting after a connection loss.

Send the event with:

```gleam
case sse.send_event(connection, ev) {
  Ok(Nil) -> sse.continue_connection(state)
  Error(Nil) -> sse.stop_connection()
}
```

## Broadcasting with SSE

For non-trivial apps, you often need external code (other controllers,
background jobs, etc.) to push events into SSE connections. Use the
`Subject(message)` received in `on_init`:

1. Store the subject in a shared location (broadcaster, ETS, etc.).
2. From anywhere in your app, `process.send(subject, your_message)`.
3. The SSE actor's `on_message` receives it and sends an event to the client.

Dream's `broadcaster` module works naturally with SSE:

```gleam
import dream/services/broadcaster
import gleam/option.{Some}

fn handle_init(
  subject: process.Subject(AppEvent),
  deps: Dependencies,
) -> #(State, option.Option(process.Selector(AppEvent))) {
  let channel = broadcaster.subscribe(deps.event_bus)
  let selector = broadcaster.channel_to_selector(channel)
  #(State(count: 0), Some(selector))
}
```

Now any code that calls `broadcaster.publish(event_bus, event)` will
deliver the event to all connected SSE clients.

## Client-side: EventSource

Browsers have built-in SSE support via `EventSource`:

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

```gleam
import dream/router.{route, router}

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
  Response(
    ..response,
    headers: [
      Header("Access-Control-Allow-Origin", "*"),
      ..response.headers
    ],
  )
}
```

The `Access-Control-Allow-Origin` header will be sent to the client as
part of the SSE response, enabling cross-origin `EventSource` connections.

If middleware returns a non-200 response (for example, a 401 from an
authentication check), the SSE upgrade is not performed and the error
response is returned to the client instead.

## Testing SSE Apps

The `examples/sse` project includes **full integration tests** written
in Gherkin (Cucumber). These tests:

- Start a real Dream server.
- Connect with HTTPoison's async streaming mode.
- Parse SSE events from the chunked HTTP response.
- Assert that events stream continuously without stalling.

To run them:

```bash
cd examples/sse
make test-integration
```

For unit tests, keep your SSE handlers small and pure by extracting
logic into separate functions. You can test event construction and
state transitions without opening real connections.

## Where to Go Next

- Read the source for `src/dream/servers/mist/sse.gleam` to see the full
  API (`SSEConnection`, `Event`, `Action`, `send_event`, etc.).
- Explore `src/dream/services/broadcaster.gleam` for the pub/sub
  implementation.
- Run and modify the [`examples/sse/`](../../examples/sse/) example to
  fit your own use case.
- Revisit the [WebSocket Guide](websockets.md) to compare SSE with
  bi-directional connections.
- See the [Streaming Guide](streaming.md) for chunked transfer encoding
  and file downloads.
