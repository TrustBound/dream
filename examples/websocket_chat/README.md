# WebSocket Chat Example

A complete real-time chat application that shows you how to build WebSocket applications in Dream from scratch.

## What You'll Learn

This example teaches you:

1. **What WebSockets are** and when to use them vs HTTP
2. **How to upgrade** from HTTP to WebSocket in Dream
3. **How to handle** WebSocket messages (text, binary, custom)
4. **How to broadcast** messages to multiple connected users
5. **How to structure** real-time applications with Dream patterns
6. **How to pass dependencies** without closures (Dream's way)
7. **How to test** WebSocket applications with integration tests

If you're new to WebSockets or Dream, this guide walks you through everything step by step.

## Quick Start

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/websocket_chat
make run
```

1. Server starts on `http://localhost:8080`
2. Open in your browser: `http://localhost:8080`
3. Enter your name (e.g., "Alice")
4. Open another tab, enter a different name (e.g., "Bob")
5. Start chatting! Messages appear in real-time for both users

## What is a WebSocket?

Before diving in, let's understand what we're building:

### HTTP (Normal Web Requests)

```text illustration
Browser                    Server
   |                          |
   |----"GET /api/users"----->|
   |<---[user list]-----------| 
   |                          |
   (connection closes)
```

Every request opens a new connection, gets a response, and closes. This is fine for most web pages.

### WebSocket (This Example)

```text illustration
Browser                    Server
   |                          |
   |---"Upgrade to WebSocket"->|
   |<---"OK, upgraded"---------|
   |                          |
   |====== PERSISTENT ========|  (stays open)
   |                          |
   |<--"Alice joined"---------|
   |--"Hello!"--------------->|
   |<--"Bob: Hi Alice!"-------|
   |                          |
```

The connection stays open. Both sides can send messages anytime. Perfect for chat, notifications, live updates.

## Application Features

- **Name Entry Screen** - Clean UX: users enter name before accessing chat
- **Real-time Messages** - Messages broadcast instantly to all connected users
- **Join/Leave Notifications** - System messages when users enter/exit chat
- **Multiple Concurrent Users** - All users see each other's messages
- **Modern UI** - Gradient design with smooth CSS animations
- **Automatic Reconnection** - If disconnected, returns to name entry screen

## Architecture Overview

Here's the complete picture of how everything fits together:

```text illustration
┌─────────────────┐                    ┌─────────────────┐
│  Alice's        │                    │  Bob's          │
│  Browser        │                    │  Browser        │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │ 1. HTTP GET /                        │
         ├─────────────────────────────────────►│
         │                                      │
         │ 2. HTML (welcome screen)             │
         │◄─────────────────────────────────────┤
         │                                      │
         │ 3. WebSocket Upgrade                 │ 3. WebSocket Upgrade
         │    ws://localhost:8080/chat?user=Alice   ws://localhost:8080/chat?user=Bob
         │                                      │
         ▼                                      ▼
    ┌────────────────────────────────────────────────┐
    │           Dream Application Server             │
    │                                                │
    │  ┌──────────────────────────────────────────┐ │
    │  │  Router                                  │ │
    │  │  GET /                  → home.show      │ │
    │  │  GET /chat              → chat.handle_...│ │
    │  │  GET /assets/**filepath → serve_assets   │ │
    │  └──────────────┬───────────────────────────┘ │
    │                 │                              │
    │  ┌──────────────▼───────────────────────────┐ │
    │  │  Controllers                             │ │
    │  │  - Extract username                      │ │
    │  │  - Create dependencies (no closures!)    │ │
    │  │  - Upgrade to WebSocket                  │ │
    │  └──────────────┬───────────────────────────┘ │
    │                 │                              │
    │  ┌──────────────▼───────────────────────────┐ │
    │  │  WebSocket Handlers                      │ │
    │  │  on_init    → Subscribe to broadcaster   │ │
    │  │  on_message → Broadcast to all users     │ │
    │  │  on_close   → Notify other users         │ │
    │  └──────────────┬───────────────────────────┘ │
    │                 │                              │
    │  ┌──────────────▼───────────────────────────┐ │
    │  │  Broadcaster Service (Pub/Sub)           │ │
    │  │  - Registry of all connections           │ │
    │  │  - Distributes messages to subscribers   │ │
    │  │  - Handles subscribe/unsubscribe         │ │
    │  └──────────────┬───────────────────────────┘ │
    │                 │                              │
    └─────────────────┼──────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         ▼                         ▼
    Alice's WS               Bob's WS
   Connection              Connection
```

**Key Points:**
- HTTP is used only for the initial page load and asset serving
- WebSocket connections stay open for real-time bi-directional communication
- The Broadcaster Service is the central hub that distributes messages to all connections
- Each connection has its own state (username, client ID) but shares the broadcaster

## Code Structure

The example has these source files and assets:

### List the files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/readme.sh#L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find assets src -type f | sort
```

### The files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/readme_output.txt#L7-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
assets/scripts/chat.js
assets/styles/chat.css
src/controllers/chat.gleam
src/controllers/home.gleam
src/controllers/static_controller.gleam
src/main.gleam
src/router.gleam
src/services.gleam
src/services/chat_service.gleam
src/templates/components/chat_header.gleam
src/templates/components/chat_header.matcha
src/templates/components/input_area.gleam
src/templates/components/input_area.matcha
src/templates/components/messages_container.gleam
src/templates/components/messages_container.matcha
src/templates/components/welcome_screen.gleam
src/templates/components/welcome_screen.matcha
src/templates/elements/button.gleam
src/templates/elements/button.matcha
src/templates/elements/input.gleam
src/templates/elements/input.matcha
src/templates/layouts/page.gleam
src/templates/layouts/page.matcha
src/templates/pages/chat.gleam
src/templates/pages/chat.matcha
src/types/chat_message.gleam
src/views/chat_view.gleam
```

- `src/controllers/chat.gleam`: the WebSocket upgrade and its handlers.
- `src/controllers/home.gleam`: the HTML page. `src/controllers/static_controller.gleam`: the assets.
- `src/services/chat_service.gleam`: starts the broadcaster.
- `src/types/chat_message.gleam`: the message type.
- `src/templates/`: the Matcha templates, and the Gleam modules generated from them.
- `assets/scripts/chat.js`: the WebSocket client.
- The integration tests are in `test/integration/`.

## How It Works: Complete Walkthrough

### Step 1: User Opens the Page

When a user visits `http://localhost:8080`, the `home` controller serves an HTML page:

#### Home controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/home.gleam#L11-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  html_response(status.ok, chat_view.render_page())
}
```

The HTML contains:
- A **welcome screen** where users enter their name
- A **hidden chat screen** that appears after connecting
- JavaScript that handles the WebSocket connection

### Step 2: User Enters Name and Clicks "Join Chat"

The JavaScript of `assets/scripts/chat.js` creates a WebSocket connection. `new WebSocket(wsUrl)` triggers the upgrade:

#### Creating the connection <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L53-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${protocol}//${
    window.location.host
  }/chat?user=${encodeURIComponent(currentUser)}`;

  ws = new WebSocket(wsUrl);
```

This sends an HTTP request with special headers. The key is the example of RFC 6455:

```http illustration
GET /chat?user=Alice HTTP/1.1
Host: localhost:8080
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

### Step 3: Server Upgrades HTTP to WebSocket

The router sends this request to the chat controller:

#### Router <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/router.gleam#L16-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create() {
  router()
  |> route(Get, "/", home.show, [])
  |> route(Get, "/chat", chat.handle_chat_upgrade, [])
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
}
```

The controller extracts the username and prepares for the upgrade:

#### Upgrade controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L23-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user = request.get_query_param(request.query, "user")
  let user = option.unwrap(user, "Anonymous")

  let dependencies = ChatDependencies(user: user, services: services)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
}
```

**Important**: Notice the `dependencies` parameter. This is Dream's way of avoiding closures. Instead of capturing `user` and `services` in a closure, we bundle them into a `ChatDependencies` type and pass them explicitly to every handler.

### Step 4: Connection Established - `on_init` Handler Runs

When the WebSocket connection is established, Dream calls `handle_websocket_init`:

#### `on_init` handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L45-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> #(String, option.Option(process.Selector(ChatMessage))) {
  let ChatDependencies(user: user, services: services) = dependencies

  // 1. Subscribe to broadcaster
  let channel = broadcaster.subscribe(services.pubsub)

  // 2. Create selector for chat messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Notify join
  broadcaster.publish(services.pubsub, UserJoined(user))

  // Initial state is the username
  #(user, Some(selector))
}
```

**What's happening here:**

1. **Subscribe to broadcaster** - The broadcaster service is like a mailing list. Every connection subscribes, and gets a channel that receives each published message.

2. **Make a selector** - `channel_to_selector` turns the channel into a selector. Dream uses it to give broadcaster messages to `on_message` as `CustomMessage`.

3. **Publish join notification** - Send `UserJoined(user)` to all subscribers. This connection subscribed in step 1, so the new user also gets the notification.

4. **Return state and selector** - The state is the username (a `String`). Dream passes it to every later handler call for this connection.

### Step 5: User Sends a Message - `on_message` Handler Runs

When the JavaScript calls `ws.send("Hello!")`, Dream receives it and calls `handle_websocket_message`. The handler has two jobs. A `TextMessage` from the browser is published to the broadcaster as `TextMessage(state, text)`. A `CustomMessage` from the broadcaster is changed to JSON and sent to this connection's browser:

#### `on_message` handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L67-L90"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn handle_websocket_message(
  state: String,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> websocket.Action(String, ChatMessage) {
  let ChatDependencies(services: services, ..) = dependencies

  case message {
    websocket.TextMessage(text) -> {
      // Broadcast user message
      broadcaster.publish(services.pubsub, TextMessage(state, text))
      websocket.continue_connection(state)
    }
    websocket.CustomMessage(chat_message) -> {
      // Received from PubSub, send to client
      let json_message = format_chat_message_to_json(chat_message)
      let _ = websocket.send_text(connection, json.to_string(json_message))
      websocket.continue_connection(state)
    }
    websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
      websocket.continue_connection(state)
  }
}
```

**Message Flow Diagram:**

```text illustration
Alice's Browser            Server            Bob's Browser
      |                      |                      |
      |--"Hello!"----------->|                      |
      |                      |                      |
      | [publish TextMessage("Alice", "Hello!")]    |
      |                      |                      |
      |   [each connection gets a CustomMessage]    |
      |   [and sends it to its browser as JSON]     |
      |<--JSON message-------|---JSON message------>|
```

Each browser gets the same text frame: `{"type":"message","user":"Alice","text":"Hello!"}`. `chat.js` shows the user name and the text.

### Step 6: The Broadcaster Service - How Multi-User Chat Works

You might be wondering: "How does the server send messages to all connected users?"

This is where the **broadcaster service** comes in. It's the infrastructure that makes real-time chat possible.

#### What is the Broadcaster?

The broadcaster is a long-running process that:
1. **Keeps a list** of all subscribed channels
2. **Receives messages** from any part of your application
3. **Sends each message to all subscribers**

Think of it like a radio station - clients "tune in" by subscribing, and the broadcaster sends signals to everyone listening.

#### How to Use the Broadcaster

Start it once when your app starts. `services.initialize` calls `init_chat_pubsub`, which starts the broadcaster:

##### Start the broadcaster in `services.initialize` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/services.gleam#L19-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn initialize() -> Services {
  let pubsub = init_chat_pubsub()
  Services(pubsub: pubsub)
}
```

##### `init_chat_pubsub` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/services/chat_service.gleam#L21-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn init_chat_pubsub() -> ChatPubSub {
  let assert Ok(pubsub) = broadcaster.start_broadcaster()
  pubsub
}
```

Subscribe when a WebSocket connects. `subscribe` returns a channel, and `channel_to_selector` makes a selector from it:

##### Subscribe in `on_init` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L51-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // 1. Subscribe to broadcaster
  let channel = broadcaster.subscribe(services.pubsub)

  // 2. Create selector for chat messages
  let selector = broadcaster.channel_to_selector(channel)
```

Publish a message to all subscribers. There is no "all except" option: each subscriber gets each message:

##### Publish in `on_message` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L78"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      broadcaster.publish(services.pubsub, TextMessage(state, text))
```

##### When a connection ends, the broadcaster removes its channel

The example does not unsubscribe. The broadcaster monitors the process that owns each channel. Each WebSocket connection runs in its own process, and `subscribe` in `on_init` makes that process the owner of the channel. When the connection closes or crashes, its process ends, and the broadcaster removes the channel. A closed connection does not stay in the subscriber list, and no memory leaks.

Call `broadcaster.unsubscribe` only to stop the messages earlier, while the connection is still open. For example, a user leaves a room but keeps the socket open. Keep the `Channel` from `subscribe` in the connection state, then give it to `unsubscribe`:

##### Unsubscribe while the connection is open <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L31-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn leave(
  my_broadcaster: broadcaster.Broadcaster(message),
  channel: broadcaster.Channel(message),
) -> Nil {
  broadcaster.unsubscribe(my_broadcaster, channel)
}
```

#### Why is Broadcaster a Separate Service?

**Separation of Concerns:**
- Broadcasting is **infrastructure**, not business logic
- The controller focuses on WebSocket lifecycle (connect, message, disconnect)
- The service handles message distribution

**Reusability:**
- Other parts of your app can broadcast messages (background jobs, HTTP endpoints, etc.)
- Example: An admin HTTP endpoint could send announcements to all users

**Testability:**
- Easy to mock the broadcaster in unit tests
- Integration tests can verify actual broadcasting behavior

### Step 7: User Closes Tab - `on_close` Handler Runs

When a user closes their browser tab or disconnects, Dream calls `handle_websocket_close`:

#### `on_close` handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L117-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn handle_websocket_close(
  state: String,
  dependencies: ChatDependencies,
) -> Nil {
  let ChatDependencies(services: services, ..) = dependencies
  broadcaster.publish(services.pubsub, UserLeft(state))
}
```

**What happens on close:**
- The handler publishes `UserLeft(state)`, so the other users know who left
- The handler does not unsubscribe. The connection's process ends, and the broadcaster removes its channel (see [When a connection ends, the broadcaster removes its channel](#when-a-connection-ends-the-broadcaster-removes-its-channel))
- The `on_close` handler always runs, even if the connection dies unexpectedly

---

## Complete Message Type Reference

### Gleam ChatMessage Type <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/types/chat_message.gleam#L4-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ChatMessage {
  TextMessage(user: String, text: String)
  UserJoined(user: String)
  UserLeft(user: String)
}
```

### JSON Format Sent to Browsers

`format_chat_message_to_json` in `controllers/chat.gleam` makes this JSON: a `message` with the user and the text, and a `joined` or `left` notification with the user. These are the frames that Bob's browser gets when he joins, Alice joins, Alice says "Hello everyone!", and Alice leaves. An integration scenario compares them with what the server sends:

#### The frames <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/chat_frames.txt#L1-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{"type":"joined","user":"Bob"}
{"type":"joined","user":"Alice"}
{"type":"message","user":"Alice","text":"Hello everyone!"}
{"type":"left","user":"Alice"}
```

The JavaScript client parses these and displays them differently (messages in white, notifications in gray).

---

## Frontend Code Explained (JavaScript + CSS)

The frontend has two main parts: **JavaScript** for WebSocket logic and **CSS** for styling.

### JavaScript: Managing WebSocket Connection

The file `assets/scripts/chat.js` handles all client-side WebSocket logic:

#### 1. Welcome Screen → Chat Screen Flow

#### Showing the screens and joining <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L14-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
function showWelcomeScreen() {
  welcomeScreen.style.display = "flex";
  chatScreen.style.display = "none";
  nameInput.value = "";
  nameInput.focus();
}

function showChatScreen() {
  welcomeScreen.style.display = "none";
  chatScreen.style.display = "flex";
  messageInput.focus();
}

function disconnect() {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.close();
  }
}

function joinChat() {
  const name = nameInput.value.trim();

  if (!name) {
    alert("Please enter your name");
    return;
  }

  currentUser = name;
  connect();
}
```

#### 2. WebSocket Connection Management

#### The connection <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L50-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
function connect() {
  disconnect();

  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${protocol}//${
    window.location.host
  }/chat?user=${encodeURIComponent(currentUser)}`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    statusDiv.textContent = `Connected as ${currentUser}`;
    messageInput.disabled = false;
    sendButton.disabled = false;
    showChatScreen();
  };

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    if (data.type === "joined") {
      addSystemMessage(`${data.user} joined the chat`);
    } else if (data.type === "left") {
      addSystemMessage(`${data.user} left the chat`);
    } else if (data.type === "message") {
      addMessage(data.user, data.text, data.user === currentUser);
    }
  };

  ws.onclose = () => {
    statusDiv.textContent = "Disconnected";
    messageInput.disabled = true;
    sendButton.disabled = true;
    showWelcomeScreen();
  };

  ws.onerror = () => {
    addSystemMessage("Connection error");
  };
}
```

**Important Details:**

- `encodeURIComponent(username)` prevents injection attacks and handles special characters
- The protocol switches between `ws:` and `wss:` based on HTTP/HTTPS
- `ws.onclose` returns to welcome screen - users can rejoin with a different name

#### 3. Sending Messages

#### Sending a message <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L119-L135"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
function sendMessage() {
  const message = messageInput.value.trim();
  if (message && ws && ws.readyState === WebSocket.OPEN) {
    ws.send(message);
    messageInput.value = "";
  }
}

joinButton.addEventListener("click", joinChat);
sendButton.addEventListener("click", sendMessage);
leaveButton.addEventListener("click", leaveChat);

messageInput.addEventListener("keypress", (e) => {
  if (e.key === "Enter") {
    sendMessage();
  }
});
```

**Why check `ws.readyState`?**

If the connection is closed, `ws.send()` will throw an error. Checking prevents crashes.

#### 4. Displaying Messages

Inside `connect()`, the `onmessage` handler reads the `type` field of each JSON message from the server. A `joined` or `left` message becomes a system line. A `message` shows `data.user` and `data.text`:

#### Reading the messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L67-L77"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    if (data.type === "joined") {
      addSystemMessage(`${data.user} joined the chat`);
    } else if (data.type === "left") {
      addSystemMessage(`${data.user} left the chat`);
    } else if (data.type === "message") {
      addMessage(data.user, data.text, data.user === currentUser);
    }
  };
```

`addMessage` and `addSystemMessage` add the message to the page:

#### Adding a message to the page <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/scripts/chat.js#L91-L117"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```javascript
function addMessage(user, text, isCurrentUser) {
  const messageDiv = document.createElement("div");
  messageDiv.className = `message ${
    isCurrentUser ? "user-message" : "other-message"
  }`;

  const userDiv = document.createElement("div");
  userDiv.className = "user";
  userDiv.textContent = user;

  const textDiv = document.createElement("div");
  textDiv.className = "text";
  textDiv.textContent = text;

  messageDiv.appendChild(userDiv);
  messageDiv.appendChild(textDiv);
  messagesDiv.appendChild(messageDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function addSystemMessage(text) {
  const messageDiv = document.createElement("div");
  messageDiv.className = "message system-message";
  messageDiv.textContent = text;
  messagesDiv.appendChild(messageDiv);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}
```

**UX Considerations:**

- Your own messages are purple and at the right, messages from others are white, and join and leave lines are green and centered
- Auto-scroll keeps latest messages visible
- The sender name is bold for readability

### CSS: Modern Gradient Design

The file `assets/styles/chat.css` provides the visual design:

#### Key Design Elements

A gradient background, with the welcome screen as a centered card:

#### The background and the welcome screen <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/styles/chat.css#L7-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```css
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
}

.welcome-screen {
    background: white;
    border-radius: 12px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    padding: 60px 40px;
    text-align: center;
    width: 90%;
    max-width: 400px;
    display: none;
    flex-direction: column;
    gap: 30px;
}
```

Messages scroll on their own, and each one slides in:

#### The messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/styles/chat.css#L84-L97"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```css
.messages {
    flex: 1;
    padding: 20px;
    overflow-y: auto;
    background: #f8f9fa;
}

.message {
    margin-bottom: 15px;
    padding: 10px 15px;
    border-radius: 8px;
    max-width: 80%;
    animation: slideIn 0.3s ease;
}
```

The input area stays at the bottom:

#### The input area <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/assets/styles/chat.css#L139-L149"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```css
.input-area {
    padding: 20px;
    border-top: 1px solid #e1e8ed;
    background: white;
    border-radius: 0 0 12px 12px;
}

.input-group {
    display: flex;
    gap: 10px;
}
```

**Design Principles:**

- **Flexbox layout** - Responsive, easy to maintain
- **Full viewport height** - Chat uses entire screen
- **White panels** - Rounded cards with a soft shadow on the gradient
- **Smooth animations** - Messages slide in, buttons change on hover

## Dream's No-Closure Pattern (Important!)

### Why No Closures?

Dream has a strict rule: **no closures in controller code**. This might seem restrictive, but there's a good reason:

**Problem with closures:**

The controller below works, but it is the pattern to avoid. Each handler is a closure that captures `user` and `services` from the controller. The `dependencies` value is `Nil`, so no type shows what the handlers need. You cannot name a handler, test it alone, or reuse it in a different controller.

#### Closures that capture dependencies (avoid this) <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websocket_chat_readme_closure.gleam#L16-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let user = option.unwrap(get_query_param(request.query, "user"), "Anonymous")

  // ❌ BAD: each handler captures `user` and `services` from this scope
  websocket.upgrade_websocket(
    request,
    dependencies: Nil,
    on_init: fn(_connection, _dependencies) {
      let channel = broadcaster.subscribe(services.pubsub)
      #(user, Some(broadcaster.channel_to_selector(channel)))
    },
    on_message: fn(state, message, connection, _dependencies) {
      case message {
        websocket.TextMessage(text) -> {
          broadcaster.publish(services.pubsub, user <> ": " <> text)
          websocket.continue_connection(state)
        }
        websocket.CustomMessage(chat_line) -> {
          let _ = websocket.send_text(connection, chat_line)
          websocket.continue_connection(state)
        }
        websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
          websocket.continue_connection(state)
      }
    },
    on_close: fn(_state, _dependencies) {
      broadcaster.publish(services.pubsub, user <> " left")
    },
  )
}
```

Dream's solution is explicit dependencies. The upgrade controller bundles the user and the services into one value, and passes named functions as handlers:

#### Explicit dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L31-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let dependencies = ChatDependencies(user: user, services: services)

  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,
    on_message: handle_websocket_message,
    on_close: handle_websocket_close,
  )
```

**Benefits:**
1. **Visible dependencies** - You can see exactly what each function needs
2. **Easier testing** - Mock the `dependencies` parameter
3. **Better documentation** - Type signatures show all inputs
4. **Prevents bugs** - Can't accidentally capture stale values

### The ChatDependencies Pattern

This example bundles dependencies into a single type:

#### `ChatDependencies` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L12-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Dependencies for WebSocket handlers
///
/// Wraps user and services to pass them through to handlers.
type ChatDependencies {
  ChatDependencies(user: String, services: Services)
}
```

**Why bundle?**

Without bundling, every handler would need a parameter for the user, one for the services, and one for each later addition. With bundling, each handler takes one `ChatDependencies` parameter:

#### A handler takes one dependencies parameter <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L45-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> #(String, option.Option(process.Selector(ChatMessage))) {
```

You can add more fields to `ChatDependencies` without changing every handler signature.

## Server-Agnostic Design (No Vendor Lock-In)

Dream abstracts the underlying WebSocket server (Mist) so your application isn't locked to one implementation.

### What You Use (Dream Types)

`on_message` matches Dream's message types and returns Dream's actions. `websocket.stop_connection()` closes a connection; this example does not use it:

#### Dream message types in `on_message` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L75-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  case message {
    websocket.TextMessage(text) -> {
      // Broadcast user message
      broadcaster.publish(services.pubsub, TextMessage(state, text))
      websocket.continue_connection(state)
    }
    websocket.CustomMessage(chat_message) -> {
      // Received from PubSub, send to client
      let json_message = format_chat_message_to_json(chat_message)
      let _ = websocket.send_text(connection, json.to_string(json_message))
      websocket.continue_connection(state)
    }
    websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
      websocket.continue_connection(state)
  }
```

### What You Don't See (Mist Types - Internal Only)

The controller never imports `mist`. Inside `dream/servers/mist/websocket`, Dream changes mist's text, binary and close frames into the types above. These are all the imports of the chat controller:

#### Chat controller imports <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L1-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response}
import dream/servers/mist/websocket
import dream/services/broadcaster
import gleam/erlang/process
import gleam/json
import gleam/option.{Some}
import services.{type Services}
import types/chat_message.{type ChatMessage, TextMessage, UserJoined, UserLeft}
```

**Why does this matter?**

If you use Mist types directly:
- Your code is locked to Mist
- Switching to a different WebSocket library requires rewriting everything
- Dream can't provide a consistent API across different servers

With Dream's abstraction:
- Your controller code is server-agnostic
- Dream could switch from Mist to another library without breaking your code
- The API is simpler and more focused on your use case

## Testing WebSocket Applications

### Running the Tests

From the repository root:

#### Run the integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/websocket_chat && make test-integration)
```

### What Gets Tested

The integration tests cover the complete user journey:

1. **HTTP Endpoints**
   - Home page returns HTML
   - Static assets (CSS, JS) are served correctly

2. **WebSocket Connection**
   - HTTP → WebSocket upgrade works
   - Connection stays open

3. **Message Flow**
   - Send a message as one user
   - Receive it as another user
   - Message format is correct

4. **Multiple Users**
   - Alice and Bob can chat
   - Both receive each other's messages

5. **Notifications**
   - Join notifications when users connect
   - Leave notifications when users disconnect
   - Notifications have different format than messages

6. **Edge Cases**
   - Anonymous users get default name
   - Missing query parameters handled gracefully

### Testing Technology: Cucumber/Gherkin

The tests are written in human-readable Gherkin. This is the scenario of two users who chat:

#### Two users chat <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/features/websocket_chat.feature#L22-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
    Scenario: Multiple users in chat
        Given user "Alice" connects to the chat
        And user "Bob" connects to the chat
        When user "Alice" sends message "Hi Bob!"
        Then user "Bob" should receive message from "Alice" saying "Hi Bob!"
        When user "Bob" sends message "Hi Alice!"
        Then user "Alice" should receive message from "Bob" saying "Hi Alice!"
```

**Why Gherkin?**

- Non-programmers can read and understand tests
- Serves as living documentation
- Forces you to think about user behavior, not implementation
- Can be shared with product managers and stakeholders

### Test Implementation (Step Definitions)

The Gherkin steps are implemented in Elixir using `WebSockex`, in `test/integration/features/step_definitions/websocket_steps.exs`. This step connects a user:

#### Connecting a user <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/test/integration/features/step_definitions/websocket_steps.exs#L138-L147"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```elixir
  step "user {string} connects to the chat", %{args: [username]} = context do
    url = "#{base_url()}/chat?user=#{URI.encode(username)}"
    {:ok, pid} = TestClient.start_link(url, self())
    
    # Wait for this user's join message only
    receive do
      {:ws_message, %{"type" => "joined", "user" => ^username}} -> :ok
    after
      2000 -> raise "Timeout waiting for #{username} join confirmation"
    end
```

The test creates REAL WebSocket connections to your running server. This is true integration testing.

## When to Use WebSockets

### Good Use Cases ✅

- **Chat/messaging** - The classic use case (this example!)
- **Real-time dashboards** - Stock prices, server metrics, live analytics
- **Notifications** - Push alerts to users without polling
- **Collaborative editing** - Google Docs-style simultaneous editing
- **Gaming** - Fast-paced multiplayer games
- **Live feeds** - Social media feeds, activity streams

**Rule of thumb**: If the server needs to push data to clients without them asking, use WebSockets.

### Bad Use Cases ❌

- **Simple APIs** - Use regular HTTP for request/response
- **File uploads** - HTTP handles this better with progress tracking
- **SEO content** - Search engines can't execute WebSocket code
- **Cacheable data** - HTTP caching (CDNs, browser cache) won't work
- **One-time requests** - WebSocket overhead not worth it

**Rule of thumb**: If you only need request → response, stick with HTTP.

## Common Patterns and Gotchas

### Pattern: Routing WebSocket Messages

The browser in this example sends plain text. If your client sends JSON in the same format that the server sends (`{"type": "message", "user": "Alice", "text": "hi"}`), parse the text into a typed message first. Then a `case` sends each type to its own handler. Text that does not parse, or has an unknown `type`, gets a separate result:

#### Parse and route chat messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websocket_chat_readme_message_routing.gleam#L9-L55"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ChatEvent {
  TextMessage(user: String, text: String)
  UserJoined(user: String)
  UserLeft(user: String)
}

pub fn route_chat_event(json_text: String) -> String {
  case parse_chat_event(json_text) {
    Ok(TextMessage(user, text)) -> handle_text_message(user, text)
    Ok(UserJoined(user)) -> handle_user_joined(user)
    Ok(UserLeft(user)) -> handle_user_left(user)
    Error(Nil) -> "Unknown message"
  }
}

pub fn parse_chat_event(json_text: String) -> Result(ChatEvent, Nil) {
  json.parse(from: json_text, using: chat_event_decoder())
  |> result.replace_error(Nil)
}

fn chat_event_decoder() -> decode.Decoder(ChatEvent) {
  use event_type <- decode.field("type", decode.string)
  use user <- decode.field("user", decode.string)
  case event_type {
    "message" -> text_message_decoder(user)
    "joined" -> decode.success(UserJoined(user))
    "left" -> decode.success(UserLeft(user))
    _ -> decode.failure(UserLeft(user), expected: "ChatEvent")
  }
}

fn text_message_decoder(user: String) -> decode.Decoder(ChatEvent) {
  use text <- decode.field("text", decode.string)
  decode.success(TextMessage(user, text))
}

fn handle_text_message(user: String, text: String) -> String {
  user <> ": " <> text
}

fn handle_user_joined(user: String) -> String {
  user <> " joined the chat"
}

fn handle_user_left(user: String) -> String {
  user <> " left the chat"
}
```

In a WebSocket handler, call `route_chat_event` with the text of each `websocket.TextMessage`.

### Pattern: Authentication in WebSocket

WebSocket messages do not have headers, so authenticate during the upgrade. The browser `WebSocket` API cannot set custom headers, so this example reads the token from the query string (`/chat?token=...`). A cookie also works. The controller upgrades the connection only when the token belongs to a user. Otherwise it returns 401 and no WebSocket opens:

#### Check a token before the upgrade <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/websocket_chat_readme_authentication.gleam#L17-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_upgrade(
  request: Request,
  _context: context,
  _services: services,
) -> Response {
  case authenticate(request) {
    Ok(user) -> upgrade_for_user(request, user)
    Error(Nil) -> text_response(status.unauthorized, "Invalid auth token")
  }
}

pub fn authenticate(request: Request) -> Result(String, Nil) {
  get_query_param(request.query, "token")
  |> option.to_result(Nil)
  |> result.try(user_for_token)
}

fn user_for_token(token: String) -> Result(String, Nil) {
  case token {
    "token-for-ada" -> Ok("ada")
    _ -> Error(Nil)
  }
}
```

`upgrade_for_user` gives the user to the handlers in a `Dependencies` value, as in the chat controller. A real app looks up the token in a store, not in a `case`.

### Gotcha: Connection State is Per-Connection

Each WebSocket connection has its own state. A list of messages in connection state would be a separate list for each user. If you need shared state across users, use a service. This example keeps only the username in connection state, and shares messages through the broadcaster:

#### State holds only the username <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L51-L61"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // 1. Subscribe to broadcaster
  let channel = broadcaster.subscribe(services.pubsub)

  // 2. Create selector for chat messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Notify join
  broadcaster.publish(services.pubsub, UserJoined(user))

  // Initial state is the username
  #(user, Some(selector))
```

## Troubleshooting

### "Address already in use" Error

**Problem:** Port 8080 is already in use by another process.

**Solution:**

```bash illustration
# Find the process using port 8080
lsof -i :8080

# Kill it
kill -9 <PID>

# Or change the port in src/main.gleam
```

### WebSocket Connection Fails

**Problem:** Browser shows "WebSocket connection failed" in console.

**Check:**

1. **Server is running** - Visit `http://localhost:8080` to verify
2. **Correct URL** - Should be `ws://localhost:8080/chat`, not `http://`
3. **Firewall** - Some corporate firewalls block WebSocket connections
4. **Browser dev tools** - Network tab shows the upgrade request details

### Messages Not Appearing

**Problem:** Sending messages but they don't show up for other users.

**Debug:**

1. **Check server logs** - Look for errors in the terminal where you ran `make run`
2. **Broadcaster subscribed?** - Verify `on_init` is subscribing to the broadcaster
3. **Multiple browser tabs** - Open two tabs to test (incognito mode helps)
4. **JavaScript console** - Check for client-side errors

### Tests Fail with "Connection refused"

**Problem:** Integration tests can't connect to the server.

**Solution:**

```bash illustration
# Make sure server isn't already running
pkill -f websocket_chat

# Tests will start their own server
make test-integration
```

### "Module not found" Errors

**Problem:** Gleam can't find `dream` or `broadcaster` modules.

**Solution:**

```bash illustration
# Install dependencies
gleam deps download

# Rebuild
gleam build
```

## Building Your Own WebSocket App

Want to adapt this example for your use case? Here's a step-by-step guide:

### 1. Define Your Message Types <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/types/chat_message.gleam#L4-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type ChatMessage {
  TextMessage(user: String, text: String)
  UserJoined(user: String)
  UserLeft(user: String)
}
```

### 2. Create Your Service

Start a broadcaster for your message type and keep it in `Services`. Handlers call `broadcaster.subscribe` and `broadcaster.publish` directly:

#### Broadcaster type for your messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/services/chat_service.gleam#L1-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/services/broadcaster
import types/chat_message.{type ChatMessage}

/// Chat PubSub service type
///
/// This is a type alias for a broadcaster specialized for chat messages.
/// The broadcaster handles all subscription and message distribution logic.
pub type ChatPubSub =
  broadcaster.Broadcaster(ChatMessage)
```

#### `Services` holds the broadcaster <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/services.gleam#L1-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import services/chat_service.{type ChatPubSub, init_chat_pubsub}

/// Application services
///
/// Holds all application-level dependencies shared across requests.
pub type Services {
  Services(pubsub: ChatPubSub)
}
```

#### Start it once <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/services.gleam#L19-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn initialize() -> Services {
  let pubsub = init_chat_pubsub()
  Services(pubsub: pubsub)
}
```

### 3. Create Your Dependencies Type <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L12-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Dependencies for WebSocket handlers
///
/// Wraps user and services to pass them through to handlers.
type ChatDependencies {
  ChatDependencies(user: String, services: Services)
}
```

### 4. Write Your Handlers

Each handler takes the dependencies as a parameter. Change what they publish and what state they keep:

#### `on_init` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L42-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Initialize WebSocket connection
///
/// Subscribes to the broadcaster and notifies other users of join.
fn handle_websocket_init(
  _connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> #(String, option.Option(process.Selector(ChatMessage))) {
  let ChatDependencies(user: user, services: services) = dependencies

  // 1. Subscribe to broadcaster
  let channel = broadcaster.subscribe(services.pubsub)

  // 2. Create selector for chat messages
  let selector = broadcaster.channel_to_selector(channel)

  // 3. Notify join
  broadcaster.publish(services.pubsub, UserJoined(user))

  // Initial state is the username
  #(user, Some(selector))
}
```

#### `on_message` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L64-L90"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Handle WebSocket messages
///
/// Processes text messages from the client and custom messages from the broadcaster.
fn handle_websocket_message(
  state: String,
  message: websocket.Message(ChatMessage),
  connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> websocket.Action(String, ChatMessage) {
  let ChatDependencies(services: services, ..) = dependencies

  case message {
    websocket.TextMessage(text) -> {
      // Broadcast user message
      broadcaster.publish(services.pubsub, TextMessage(state, text))
      websocket.continue_connection(state)
    }
    websocket.CustomMessage(chat_message) -> {
      // Received from PubSub, send to client
      let json_message = format_chat_message_to_json(chat_message)
      let _ = websocket.send_text(connection, json.to_string(json_message))
      websocket.continue_connection(state)
    }
    websocket.BinaryMessage(_) | websocket.ConnectionClosed ->
      websocket.continue_connection(state)
  }
}
```

#### `on_close` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/controllers/chat.gleam#L114-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Handle WebSocket close
///
/// Notifies other users when a user leaves.
fn handle_websocket_close(
  state: String,
  dependencies: ChatDependencies,
) -> Nil {
  let ChatDependencies(services: services, ..) = dependencies
  broadcaster.publish(services.pubsub, UserLeft(state))
}
```

### 5. Set Up Routing <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/src/router.gleam#L16-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create() {
  router()
  |> route(Get, "/", home.show, [])
  |> route(Get, "/chat", chat.handle_chat_upgrade, [])
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
}
```

### 6. Write Frontend JavaScript

```javascript illustration
// assets/scripts/app.js
const ws = new WebSocket('ws://localhost:8080/ws');

ws.onopen = () => {
  console.log('Connected');
  // Send initial message if needed
  ws.send(JSON.stringify({ type: 'hello', user: 'Alice' }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Handle your message types
  switch(data.type) {
    case 'typing':
      showTypingIndicator(data.user);
      break;
    case 'edit':
      applyEdit(data.doc_id, data.change);
      break;
    // ... your cases
  }
};

ws.onclose = () => {
  console.log('Disconnected');
  // Optionally attempt reconnection
};
```

### 7. Test It!

Write integration tests using the Cucumber pattern from this example:

```gherkin illustration
# test/integration/features/my_feature.feature
Feature: My WebSocket Feature

Scenario: User receives real-time updates
  Given the server is running on port 8080
  When user "Alice" connects to the chat
  And user "Bob" sends update "status changed"
  Then user "Alice" should receive the update
```

## Next Steps

### Extend This Example

Try adding these features to learn more:

1. **Private messages** - Send to specific users instead of broadcasting
   - Hint: Modify `broadcast()` to accept a list of specific client IDs
   
2. **Message history** - Store messages in a database, load on join
   - Hint: See `examples/database/` for Postgres integration
   
3. **Typing indicators** - Show "Alice is typing..."
   - Hint: Debounce the indicator (clear after 3 seconds of no typing)
   
4. **User list** - Display all connected users
   - Hint: The broadcaster service knows all subscriber IDs
   
5. **Authentication** - Require login before accessing chat
   - Hint: Validate a token in `handle_chat_upgrade` before upgrading
   
6. **Rate limiting** - Prevent message spam
   - Hint: Track message count per user in state, reject if > 10/minute
   
7. **Rich messages** - Support images, links, emoji
   - Hint: Parse URLs in `displayMessage()`, render as `<img>` or `<a>`

### Learn More About Dream

- **`examples/simple/`** - Start here if WebSockets are too advanced
- **`examples/database/`** - Learn to persist chat messages
- **`examples/streaming/`** - Another real-time pattern (Server-Sent Events)
- **`examples/rate_limiter/`** - Implement rate limiting
- **`docs/guides/`** - Deep dives into Dream concepts

### Learn More About WebSockets

- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455) - WebSocket protocol spec
- [WebSocket Best Practices](https://www.ably.io/topic/websockets)
- [WebSocket Security](https://owasp.org/www-community/vulnerabilities/WebSocket_Security)

### Community

- **Discord** - Join the Dream community for help and discussion
- **GitHub Issues** - Report bugs or request features
- **Examples** - Check other examples in this directory

---

## Summary

This example demonstrates a **production-ready WebSocket application** with:

✅ **Dream's clean architecture** - No closures, explicit dependencies  
✅ **Server-agnostic design** - No vendor lock-in to Mist  
✅ **Comprehensive testing** - Cucumber integration tests  
✅ **Real-time broadcasting** - Pub/sub pattern with broadcaster service  
✅ **Modern UI** - Beautiful gradient design with smooth animations  
✅ **Best practices** - Error handling, cleanup, UX considerations  

You now have a complete reference for building real-time applications in Dream. Happy coding! 🚀

