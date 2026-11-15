# WebSockets in Dream

Build real-time features like chat, notifications, and live dashboards using typed WebSockets in Gleam.

This guide assumes you:

- Know a little HTTP (requests, responses, status codes).
- May be **new to Gleam** – examples are small and include imports and types.

We will cover:

- When to use WebSockets vs HTTP streaming or SSE.
- How Dream upgrades an HTTP request to a WebSocket.
- Writing `on_init`, `on_message`, and `on_close` handlers.
- Broadcasting messages with the `broadcaster` service.
- Authentication at upgrade time.
- Where to look for a full example and tests.

## WebSockets vs Streaming and SSE

Dream already supports:

- **Streaming responses** – send large responses in chunks.
- **Streaming requests** – read large uploads without buffering.
- **Server-Sent Events (SSE)** – one-way event stream from server to browser.

WebSockets are different:

- **Bi-directional** – both client and server can send messages at any time.
- **Long-lived** – a single connection can stay open for hours.
- **Stateful** – each connection has its own state on the server.

Use WebSockets when:

- You are building **chat** or collaborative editing.
- You need **live dashboards** or real-time notifications.
- The server must push updates without the client polling.

If you only need one request → one response, or one-way event streams,
prefer regular HTTP or SSE. See the [Streaming Guide](streaming.md) for that.

## Overview: How Dream WebSockets Work

Dream’s WebSocket support lives in the Mist server adapter module:

### The WebSocket module import <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/servers/mist/websocket
```

From your application’s point of view, you work with:

- `websocket.Connection` – an opaque handle to a WebSocket connection.
- `websocket.Message(custom)` – messages received for this connection.
- `websocket.Action(state, custom)` – what to do after handling a message.
- `websocket.upgrade_websocket` – called from a controller to upgrade HTTP → WebSocket.

The high-level flow is:

1. A browser makes a WebSocket upgrade request to a path in your app
   (for example, `GET /chat` with `Upgrade: websocket` headers).
2. Your Dream **router** sends that request to a controller.
3. The controller calls `upgrade_websocket` instead of returning a normal
   HTTP response.
4. Dream and Mist perform the WebSocket handshake.
5. Dream calls your handler functions:
   - `on_init` (once, when the connection is established).
   - `on_message` (every time a text/binary/custom message arrives).
   - `on_close` (once, after the connection is closed).

## Step 1: Define a Dependencies type

Dream has a strong rule: **no closures in controllers or handlers**.
Instead of capturing variables from outer scopes, you pass everything
explicitly through function parameters.

For WebSockets we usually create a small `Dependencies` type that bundles
what the handlers need (current user, services, config, etc.). The
example below shows the top of the chat module: the imports that all of
the steps use, the `ChatMessage` type that users send to each other, and
the `Dependencies` type.

### Imports and the Dependencies type <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L7-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/erlang/process
import gleam/option.{Some}
import gleam/otp/actor

pub type ChatMessage {
  ChatMessage(sender: String, content: String)
}

pub type Dependencies {
  Dependencies(
    user_name: String,
    chat_bus: broadcaster.Broadcaster(ChatMessage),
  )
}
```

You can later add more fields (logger, config, metrics) without changing
handler signatures everywhere.

## Step 2: Define a WebSocket route and controller

First, add a route in your router that points to a controller function:

### A router with a WebSocket route <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_router.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{Get}
import dream/router.{route, router}
import snippets/websockets_guide_chat as chat

pub fn create_router() {
  router()
  |> route(
    method: Get,
    path: "/chat",
    controller: chat.handle_chat_upgrade,
    middleware: [],
  )
}
```

A WebSocket controller has the same shape as a regular controller:

### A WebSocket controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L38-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user_name =
    get_query_param(request.query, "user")
    |> option.unwrap("Anonymous")

  let dependencies =
    Dependencies(user_name: user_name, chat_bus: services.chat_bus)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
}
```

The controller reads the user name from the `user` query parameter (for
example, `/chat?user=ada`) and uses `Anonymous` when it is missing.

Instead of returning a `Response` directly, the controller calls
`upgrade_websocket`. Dream returns a dummy HTTP response to satisfy the
controller type, but the real work happens in the WebSocket handlers.

## Step 3: `on_init` – run when the connection opens

`on_init` runs **once**, right after the WebSocket is established. It
lets you:

- Compute an initial state value for this connection.
- Optionally subscribe to a broadcaster and provide a `Selector(custom)`
  so your `on_message` handler can receive custom messages.

### The on_init handler <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L59-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Per-connection state kept by Dream
pub type ChatState {
  ChatState(user_name: String)
}

pub fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: Dependencies,
) -> #(ChatState, option.Option(process.Selector(ChatMessage))) {
  // 1. Subscribe this connection to the broadcaster
  let channel = broadcaster.subscribe(dependencies.chat_bus)

  // 2. Turn channel into a Selector so we can receive messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Initial state for this WebSocket connection
  let state = ChatState(user_name: dependencies.user_name)

  #(state, Some(selector))
}
```

Dream stores `state` internally and passes it back to `on_message` for
this connection. The selector tells Dream to also listen for custom
messages (for example, from other users via the broadcaster).

## Step 4: `on_message` – handle incoming and custom messages

Every time a message arrives, Dream calls your `on_message` function.
It must return an `Action(state, custom)` value created by one of:

- `websocket.continue_connection(state)` – keep the connection open.
- `websocket.continue_connection_with_selector(state, selector)` – keep
  connection open and update which selector to use.
- `websocket.stop_connection()` – close the connection.

The message type is `websocket.Message(custom)`:

- `TextMessage(String)` – text frame from the client.
- `BinaryMessage(BitArray)` – binary frame from the client.
- `CustomMessage(custom)` – value delivered via your `Selector(custom)`.
- `ConnectionClosed` – Mist or the client closed the connection.

### The on_message handler <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L80-L108"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_websocket_message(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: Dependencies,
) -> websocket.Action(ChatState, ChatMessage) {
  case message {
    // Text sent by this client
    websocket.TextMessage(text) -> {
      let chat_message = ChatMessage(sender: state.user_name, content: text)
      // Broadcast to everyone (including sender)
      broadcaster.publish(dependencies.chat_bus, chat_message)
      websocket.continue_connection(state)
    }

    // Message broadcast from the server (via broadcaster)
    websocket.CustomMessage(chat_message) -> {
      let payload = format_chat_message(chat_message)
      let _ = websocket.send_text(connection, payload)
      websocket.continue_connection(state)
    }

    // Close frame or server shutdown
    websocket.ConnectionClosed -> websocket.stop_connection()

    // Ignore binary for now
    websocket.BinaryMessage(_) -> websocket.continue_connection(state)
  }
}
```

If `send_text` fails, it returns `Error(SendError)` – in many simple
apps you can log this and continue, but you could also decide to stop
the connection.

## Step 5: `on_close` – clean up

`on_close` runs once when the connection is closed. It receives the
*last* state value and your dependencies. Typical uses:

- Unsubscribe from a broadcaster.
- Announce that a user left.
- Release any other resources you are tracking.

### The on_close handler <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L110-L120"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_websocket_close(
  state: ChatState,
  dependencies: Dependencies,
) -> Nil {
  let leave_message =
    ChatMessage(
      sender: state.user_name,
      content: state.user_name <> " left the chat",
    )
  broadcaster.publish(dependencies.chat_bus, leave_message)
}
```

> Note: in the simple `broadcaster` module included with Dream,
> subscriptions are cleaned up automatically when processes die, but it
> is still a good habit to handle any explicit cleanup you need here.

## Broadcasting with the `broadcaster` service

Most non-trivial WebSocket apps need to **send messages to more than one
connection** at a time. Dream provides a tiny `broadcaster` module under
`src/dream/services/broadcaster.gleam` to help with this.

At a high level:

- A `Broadcaster(message)` manages many subscribers.
- Each subscriber has a `Channel(message)`.
- A channel can be turned into a `Selector(message)`.
- When you call `publish(broadcaster, message)`, all subscribers receive
  the message.

### Initialize broadcaster in Services <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L27-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(chat_bus: broadcaster.Broadcaster(ChatMessage))
}

pub fn initialize() -> Result(Services, actor.StartError) {
  case broadcaster.start_broadcaster() {
    Ok(chat_bus) -> Ok(Services(chat_bus: chat_bus))
    Error(start_error) -> Error(start_error)
  }
}
```

`initialize` returns an error if the broadcaster does not start, so your
`main` function can decide what to do.

### Subscribe in `on_init` <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L64-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: Dependencies,
) -> #(ChatState, option.Option(process.Selector(ChatMessage))) {
  // 1. Subscribe this connection to the broadcaster
  let channel = broadcaster.subscribe(dependencies.chat_bus)

  // 2. Turn channel into a Selector so we can receive messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Initial state for this WebSocket connection
  let state = ChatState(user_name: dependencies.user_name)

  #(state, Some(selector))
}
```

### Publish from anywhere <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_chat.gleam#L126-L132"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn publish_chat_message(
  services: Services,
  sender: String,
  text: String,
) -> Nil {
  broadcaster.publish(services.chat_bus, ChatMessage(sender, text))
}
```

The `websocket_chat` example in this repository shows a larger version
of this pattern with more message types and integration tests.

## Authentication at Upgrade Time

WebSocket frames do not carry HTTP headers, so **authenticate at the
upgrade request**, not later.

Inside your controller, check the token before you call
`upgrade_websocket`. In this example the token comes from the
`Authorization: Bearer <token>` header, and `validate_auth_token` finds the
user that has that token. If there is no such user, the controller returns
401 and does not upgrade:

### Check the auth token before the upgrade <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/websockets_guide_auth.gleam#L26-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_upgrade(request, _context, services: Services) -> Response {
  case validate_auth_token(request, services) {
    Ok(user) -> {
      let dependencies =
        Dependencies(user_name: user.name, chat_bus: services.chat_bus)
      websocket.upgrade_websocket(
        request,
        dependencies: dependencies,
        on_init: handle_websocket_init,
        on_message: handle_websocket_message,
        on_close: handle_websocket_close,
      )
    }
    Error(Nil) ->
      response.text_response(status.unauthorized, "Invalid auth token")
  }
}
```

This way only authenticated clients are allowed to upgrade to WebSockets.

## Testing WebSocket Apps

The `examples/websocket_chat` project includes **full integration tests**
written in Gherkin (Cucumber). These tests:

- Start a real Dream server.
- Connect with real WebSocket clients.
- Send messages as different users.
- Assert that messages and notifications are received correctly.

To run them:

```bash
cd examples/websocket_chat
make test-integration
```

For unit tests inside Gleam, prefer to keep your WebSocket handlers
small and pure by extracting logic into separate functions that do not
know about WebSockets. You can then test those functions directly
without opening real connections.

## Where to Go Next

- Read the source for `src/dream/servers/mist/websocket.gleam` to see the
  full API (`Message`, `Action`, `send_text`, `send_binary`, etc.).
- Explore `src/dream/services/broadcaster.gleam` for the pub/sub
  implementation.
- Run and modify the [`examples/websocket_chat/`](../../examples/websocket_chat/)
  example to fit your own use case.
- Revisit the [Streaming Guide](streaming.md) to compare WebSockets with
  HTTP streaming and SSE.
