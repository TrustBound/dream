# Build a chat with WebSockets

You want a live feature where both sides talk at any time: a chat, a multiplayer cursor, a dashboard that also takes commands. HTTP requests can't do that, and server-sent events only go one way. A WebSocket keeps one connection open in both directions. This guide builds the WebSocket handlers of a chat room with Dream's typed WebSocket actors and its broadcaster, using `examples/websocket_chat`. The frames and answers shown are what that server really sends.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [WebSockets, SSE or streaming](#websockets-sse-or-streaming)
- [Overview: How Dream WebSockets Work](#overview-how-dream-websockets-work)
- [A Small Example](#a-small-example)
- [Step 1: Define a Dependencies type](#step-1-define-a-dependencies-type)
- [Step 2: Define a WebSocket route and controller](#step-2-define-a-websocket-route-and-controller)
- [Step 3: on_init, run when the connection opens](#step-3-on_init-run-when-the-connection-opens)
- [Step 4: on_message, handle incoming and custom messages](#step-4-on_message-handle-incoming-and-custom-messages)
- [Step 5: on_close, clean up](#step-5-on_close-clean-up)
- [Step 6: Broadcast to every user](#step-6-broadcast-to-every-user)
- [Step 7: See the frames of a chat](#step-7-see-the-frames-of-a-chat)
- [Authentication at Upgrade Time](#authentication-at-upgrade-time)
- [When the upgrade fails](#when-the-upgrade-fails)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A `/chat` route that upgrades the request to a WebSocket run by its own actor.
- Handlers for the open, each message, and the close of a connection.
- A chat room where every user gets every message, through the broadcaster service.
- The JSON frames a user sees while another joins, talks and leaves.
- A check of the user's token before the upgrade, and the answer to a request that isn't an upgrade.

## Before you start

You need Dream and `gleam_erlang`:

```sh
gleam add dream gleam_erlang
```

Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) first. The examples on this page are small and include their imports. The full app runs from the Dream repository with `make run` in `examples/websocket_chat`, on port 8080, and its [README](https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/README.md) walks through the browser side and the templates.

## WebSockets, SSE or streaming

Dream already supports:

- **Streaming responses**: send large responses in chunks.
- **Streaming requests**: read large uploads without buffering.
- **Server-Sent Events (SSE)**: one-way event stream from server to browser.

WebSockets are different:

- **Bi-directional**: both client and server can send messages at any time.
- **Long-lived**: a single connection can stay open for hours.
- **Stateful**: each connection has its own state on the server.

Use WebSockets when:

- You are building **chat** or collaborative editing.
- You need **live dashboards** or real-time notifications.
- The server must push updates without the client polling.

If you only need one request → one response, or one-way event streams,
prefer regular HTTP or SSE. See the [Streaming Guide](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) for that.

## Overview: How Dream WebSockets Work

Dream’s WebSocket support lives in the Mist server adapter module:

### The WebSocket module import <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/servers/mist/websocket
```

From your application’s point of view, you work with:

- `websocket.Connection`: an opaque handle to a WebSocket connection.
- `websocket.Message(custom)`: messages received for this connection.
- `websocket.Action(state, custom)`: what to do after handling a message.
- `websocket.upgrade_websocket`: called from a controller to upgrade HTTP to a WebSocket.

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

## A Small Example

This controller upgrades a request to a WebSocket. It sends each text message back with the name of the user. The steps below explain each part.

### Echo each message with the user name <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/readme_websocket_chat.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{type Request, get_query_param}
import dream/servers/mist/websocket
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, None}

pub type Dependencies {
  Dependencies(user_name: String)
}

pub fn chat(request, _context, _services) {
  websocket.upgrade_websocket(
    request,
    dependencies: make_dependencies(request),
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}

fn make_dependencies(request: Request) -> Dependencies {
  let user_name =
    get_query_param(request.query, "user")
    |> option.unwrap("guest")
  Dependencies(user_name:)
}

fn handle_init(
  _connection: websocket.Connection,
  _deps: Dependencies,
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_message(
  state: Nil,
  message: websocket.Message(Nil),
  connection: websocket.Connection,
  deps: Dependencies,
) -> websocket.Action(Nil, Nil) {
  case message {
    websocket.TextMessage(text) -> {
      let _ = websocket.send_text(connection, deps.user_name <> ": " <> text)
      websocket.continue_connection(state)
    }
    _ -> websocket.continue_connection(state)
  }
}

fn handle_close(_state: Nil, _deps: Dependencies) -> Nil {
  Nil
}
```

## Step 1: Define a Dependencies type

Dream has a strong rule: **no closures in controllers or handlers**.
Instead of capturing variables from outer scopes, you pass everything
explicitly through function parameters.

For WebSockets we usually create a small `Dependencies` type that bundles
what the handlers need (current user, services, config, etc.). The
example below shows the top of the chat module: the imports that all of
the steps use, the `ChatMessage` type that users send to each other, and
the `Dependencies` type.

### Imports and the Dependencies type <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L7-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### A router with a WebSocket route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_router.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### A WebSocket controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L38-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Step 3: on_init, run when the connection opens

`on_init` runs **once**, right after the WebSocket is established. It
lets you:

- Compute an initial state value for this connection.
- Optionally subscribe to a broadcaster and provide a `Selector(custom)`
  so your `on_message` handler can receive custom messages.

### The on_init handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L59-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Step 4: on_message, handle incoming and custom messages

Every time a message arrives, Dream calls your `on_message` function.
It must return an `Action(state, custom)` value created by one of:

- `websocket.continue_connection(state)`: keep the connection open.
- `websocket.continue_connection_with_selector(state, selector)`: keep
  connection open and update which selector to use.
- `websocket.stop_connection()`: close the connection.

The message type is `websocket.Message(custom)`:

- `TextMessage(String)`: text frame from the client.
- `BinaryMessage(BitArray)`: binary frame from the client.
- `CustomMessage(custom)`: value delivered via your `Selector(custom)`.

A close is not a message. When the client or the server closes the
connection, Dream calls your `on_close` function, as Step 5 shows.

The handler below puts the decision in `reply_to`, a plain function that
gets no connection and returns a `Reply`. `handle_websocket_message` only
carries out the reply. A test can call `reply_to`, as
[Test your code](#test-your-code) shows.

### The on_message handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L80-L131"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// What one message makes the connection do. A plain function with no
/// connection, so a test can call it.
pub type Reply {
  SendText(String)
  KeepOpen
}

pub fn reply_to(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  dependencies: Dependencies,
) -> Reply {
  case message {
    // Text sent by this client: broadcast to everyone (including sender)
    websocket.TextMessage(text) -> {
      let chat_message = ChatMessage(sender: state.user_name, content: text)
      broadcaster.publish(dependencies.chat_bus, chat_message)
      KeepOpen
    }

    // Message broadcast from the server (via broadcaster)
    websocket.CustomMessage(chat_message) ->
      SendText(format_chat_message(chat_message))

    // Ignore binary for now
    websocket.BinaryMessage(_) -> KeepOpen
  }
}

pub fn handle_websocket_message(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: Dependencies,
) -> websocket.Action(ChatState, ChatMessage) {
  case reply_to(state, message, dependencies) {
    SendText(text) -> send_or_stop(state, connection, text)
    KeepOpen -> websocket.continue_connection(state)
  }
}

fn send_or_stop(
  state: ChatState,
  connection: websocket.Connection,
  text: String,
) -> websocket.Action(ChatState, ChatMessage) {
  case websocket.send_text(connection, text) {
    Ok(Nil) -> websocket.continue_connection(state)
    // The client has gone away
    Error(_send_error) -> websocket.stop_connection()
  }
}
```

If `send_text` fails, it returns `Error(SendError)`: the client has gone
away, so `send_or_stop` stops the connection.

## Step 5: on_close, clean up

`on_close` runs once when the connection is closed. It receives the
*last* state value and your dependencies. Typical uses:

- Unsubscribe from a broadcaster.
- Announce that a user left.
- Release any other resources you are tracking.

### The on_close handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L133-L143"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Step 6: Broadcast to every user

Most non-trivial WebSocket apps need to **send messages to more than one
connection** at a time. Dream provides a tiny `broadcaster` module under
`src/dream/services/broadcaster.gleam` to help with this.

At a high level:

- A `Broadcaster(message)` manages many subscribers.
- Each subscriber has a `Channel(message)`.
- A channel can be turned into a `Selector(message)`.
- When you call `publish(broadcaster, message)`, all subscribers receive
  the message.
- `unsubscribe(broadcaster, channel)` stops the messages to one channel.
- `count_subscribers(broadcaster)` returns the number of subscribers in a `Result`.

### Initialize broadcaster in Services <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L27-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Subscribe in `on_init` <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L64-L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Publish from anywhere <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_chat.gleam#L149-L155"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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


## Step 7: See the frames of a chat

The chat app turns each `ChatMessage` into a JSON frame. These are the frames that Bob's browser gets when he joins, Alice joins, Alice says "Hello everyone!", and Alice leaves. An integration scenario of the example connects two real WebSocket clients and compares what Bob receives with this file:

### The frames Bob receives <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/chat_frames.txt#L1-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{"type":"joined","user":"Bob"}
{"type":"joined","user":"Alice"}
{"type":"message","user":"Alice","text":"Hello everyone!"}
{"type":"left","user":"Alice"}
```

### The scenario that checks them <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/features/websocket_chat.feature#L54-L61"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
    Scenario: The JSON frames of the README
        Given user "Bob" connects to the chat
        And user "Alice" connects to the chat
        When user "Alice" sends message "Hello everyone!"
        Then user "Bob" should receive message from "Alice" saying "Hello everyone!"
        When user "Alice" disconnects
        Then user "Bob" should receive "left" notification for "Alice"
        And the frames that user "Bob" received should be the lines of "test/integration/chat_frames.txt"
```

## Authentication at Upgrade Time

WebSocket frames do not carry HTTP headers, so **authenticate at the
upgrade request**, not later.

Inside your controller, check the token before you call
`upgrade_websocket`. In this example the token comes from the
`Authorization: Bearer <token>` header, and `validate_auth_token` finds the
user that has that token. If there is no such user, the controller returns
401 and does not upgrade:

### Check the auth token before the upgrade <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websockets_guide_auth.gleam#L26-L42"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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


## When the upgrade fails

A WebSocket starts as an HTTP `GET` with `Upgrade: websocket` and a few more headers. A plain request to the same route isn't an upgrade, and the server refuses it before your handlers run:

### Send a plain GET to /chat <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/readme.sh#L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i "http://localhost:8080/chat?user=Ann"
```

### A 400 with no body <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/readme_output.txt#L1-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 400 Bad Request
content-length: 0
date: (the time of the request)
connection: keep-alive
```

The other failures happen after the upgrade. When the client goes away, `on_close` runs, even when the connection dies without a close frame. A `send_text` to a connection that has closed returns an error. Check it, and return `websocket.stop_connection()` when sending fails.

## Test your code

`reply_to` and `on_close` get no connection, so a test calls them like any function. The test process subscribes to the chat bus, so it receives what the handlers publish:

### Test the chat's message handling <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_websockets_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// WebSockets guide: a test of the chat's message handling
////
//// reply_to and handle_websocket_close are from
//// test/snippets/websockets_guide_chat.gleam. Neither takes a connection,
//// so the test needs no server. The test process subscribes to the chat
//// bus, so it receives what the handlers publish.

import dream/servers/mist/websocket
import dream/services/broadcaster
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process
import snippets/websockets_guide_chat.{
  type ChatMessage, ChatMessage, ChatState, Dependencies, KeepOpen, SendText,
}

fn chat_bus() -> broadcaster.Broadcaster(ChatMessage) {
  let assert Ok(chat_bus) = broadcaster.start_broadcaster()
  chat_bus
}

/// Subscribes the test process, then returns what it receives in 100 ms.
fn published_by(
  chat_bus: broadcaster.Broadcaster(ChatMessage),
  action: fn() -> anything,
) -> Result(ChatMessage, Nil) {
  let selector =
    broadcaster.subscribe(chat_bus)
    |> broadcaster.channel_to_selector
  let _result = action()
  process.selector_receive(selector, 100)
}

pub fn tests() -> TestSuite {
  let state = ChatState(user_name: "ada")

  describe("chat handlers", [
    group("reply_to", [
      it("keeps the connection open after a text message", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.TextMessage("hello"),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(KeepOpen)
        |> or_fail_with("a text message should keep the connection open")
      }),
      it("publishes a text message with the user's name", fn() {
        // Arrange
        let bus = chat_bus()
        let dependencies = Dependencies(user_name: "ada", chat_bus: bus)

        // Act
        let published =
          published_by(bus, fn() {
            websockets_guide_chat.reply_to(
              state,
              websocket.TextMessage("hello"),
              dependencies,
            )
          })

        // Assert
        published
        |> should
        |> be_equal(Ok(ChatMessage(sender: "ada", content: "hello")))
        |> or_fail_with("every subscriber should get ada's message")
      }),
      it("ignores a binary message", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.BinaryMessage(<<1, 2, 3>>),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(KeepOpen)
        |> or_fail_with("a binary message should change nothing")
      }),
      it("sends a broadcast message to the client as text", fn() {
        // Arrange
        let dependencies = Dependencies(user_name: "ada", chat_bus: chat_bus())
        let message = ChatMessage(sender: "bob", content: "hi")

        // Act
        let reply =
          websockets_guide_chat.reply_to(
            state,
            websocket.CustomMessage(message),
            dependencies,
          )

        // Assert
        reply
        |> should
        |> be_equal(SendText("bob: hi"))
        |> or_fail_with("bob's message should go to the client as 'bob: hi'")
      }),
    ]),
    group("handle_websocket_close", [
      it("tells the others that the user left", fn() {
        // Arrange
        let bus = chat_bus()
        let dependencies = Dependencies(user_name: "ada", chat_bus: bus)

        // Act
        let published =
          published_by(bus, fn() {
            websockets_guide_chat.handle_websocket_close(state, dependencies)
          })

        // Assert
        published
        |> should
        |> be_equal(
          Ok(ChatMessage(sender: "ada", content: "ada left the chat")),
        )
        |> or_fail_with("the others should get the leave message")
      }),
    ]),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_websockets_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
chat handlers
  handle_websocket_close
    ✓ tells the others that the user left
  reply_to
    ✓ ignores a binary message
    ✓ keeps the connection open after a text message
    ✓ publishes a text message with the user's name
    ✓ sends a broadcast message to the client as text

Summary: 5 run, 0 failed, 5 passed in 0ms
```

A test can't call `on_init` or `on_message` itself. Both get a `websocket.Connection`, an opaque type that only the server makes when a client upgrades, and Dream has no test connection. For the same reason, a test can't see what `send_text` writes. Keep the decisions in functions like `reply_to`, and leave only the calls on the connection in the handlers.

The `examples/websocket_chat` project tests the handlers with a real server. Its integration tests are written in Gherkin (Cucumber), and they:

- Start a real Dream server.
- Connect with real WebSocket clients.
- Send messages as different users.
- Assert that messages and notifications are received correctly.

To run them:

### Run the integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/websocket_chat && make test-integration)
```

## Common pitfalls

- **Authenticating after the upgrade.** Frames carry no headers. Check the token in the controller, before `upgrade_websocket`, and answer `401` there.
- **Blocking work in `on_message`.** Each connection is one actor. A slow call in `on_message` delays every later frame of that connection. Hand slow work to another process and send the result back as a custom message.
- **Unsubscribing by hand on close.** The broadcaster removes a connection's channel when its process ends, so `on_close` only needs to tell the others.
- **A proxy that drops idle connections.** Load balancers often close a connection with no traffic after a minute or so. Send a ping, or a small message, more often than that.

## Where to go next

- Read the source for `src/dream/servers/mist/websocket.gleam` to see the
  full API (`Message`, `Action`, `send_text`, `send_binary`, etc.).
- Explore `src/dream/services/broadcaster.gleam` for the pub/sub
  implementation.
- Run and modify the [`examples/websocket_chat/`](https://github.com/TrustBound/dream/tree/3.0.0/examples/websocket_chat)
  example to fit your own use case.
- Revisit the [Streaming Guide](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) to compare WebSockets with
  HTTP streaming and SSE.
