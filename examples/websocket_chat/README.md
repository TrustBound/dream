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

```
Browser                    Server
   |                          |
   |----"GET /api/users"----->|
   |<---[user list]-----------| 
   |                          |
   (connection closes)
```

Every request opens a new connection, gets a response, and closes. This is fine for most web pages.

### WebSocket (This Example)

```
Browser                    Server
   |                          |
   |---"Upgrade to WebSocket"-|
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

```
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
    │  │  GET /       → home.show                 │ │
    │  │  GET /chat   → chat.handle_chat_upgrade  │ │
    │  │  GET /assets → static_controller.serve   │ │
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
    │  │  on_close   → Unsubscribe & notify       │ │
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

```
examples/websocket_chat/
├── gleam.toml              # Project config
├── Makefile                # Build and test commands
├── mix.exs                 # Elixir test dependencies
├── assets/                 # Frontend assets
│   ├── scripts/
│   │   └── chat.js        # WebSocket client logic
│   └── styles/
│       └── chat.css       # Chat UI styling
├── src/
│   ├── main.gleam         # Application entry point
│   ├── router.gleam       # Route definitions
│   ├── services.gleam     # Application services
│   ├── controllers/
│   │   ├── chat.gleam     # WebSocket upgrade handler
│   │   ├── home.gleam     # HTML page controller
│   │   └── static_controller.gleam  # Asset serving
│   ├── services/
│   │   └── chat_service.gleam  # Broadcaster initialization
│   ├── types/
│   │   └── chat_message.gleam  # Message type definitions
│   ├── views/
│   │   └── chat_view.gleam  # HTML rendering
│   └── templates/          # Matcha templates
│       ├── components/
│       ├── elements/
│       ├── layouts/
│       └── pages/
└── test/
    └── integration/        # Cucumber tests
        ├── features/
        │   ├── websocket_chat.feature
        │   └── step_definitions/
        │       ├── http_steps.exs
        │       └── websocket_steps.exs
        └── test_helper.exs
```

## How It Works: Complete Walkthrough

### Step 1: User Opens the Page

When a user visits `http://localhost:8080`, the `home` controller serves an HTML page:

```gleam
// controllers/home.gleam
pub fn show(request: Request, context: EmptyContext, services: Services) -> Response {
  html_response(status.ok, chat_view.render_page())
}
```

The HTML contains:
- A **welcome screen** where users enter their name
- A **hidden chat screen** that appears after connecting
- JavaScript that handles the WebSocket connection

### Step 2: User Enters Name and Clicks "Join Chat"

The JavaScript creates a WebSocket connection:

```javascript
// assets/scripts/chat.js
function joinChat() {
  const name = nameInput.value.trim();
  const wsUrl = `ws://localhost:8080/chat?user=${encodeURIComponent(name)}`;
  ws = new WebSocket(wsUrl);  // This triggers the upgrade!
}
```

This sends an HTTP request with special headers:
```
GET /chat?user=Alice HTTP/1.1
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

### Step 3: Server Upgrades HTTP to WebSocket

The router sends this request to the chat controller:

```gleam
// router.gleam
router()
|> route(method: Get, path: "/chat", controller: chat.handle_chat_upgrade, middleware: [])
```

The controller extracts the username and prepares for the upgrade:

```gleam
// controllers/chat.gleam
pub fn handle_chat_upgrade(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  // 1. Extract username from query parameter
  let user = request.get_query_param(request.query, "user")
  let user = option.unwrap(user, "Anonymous")

  // 2. Bundle dependencies (user + services)
  // This is how Dream avoids closures - bundle everything into a type
  let dependencies = ChatDependencies(user: user, services: services)

  // 3. Upgrade to WebSocket, passing three handler functions
  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,     // Called once when connected
    on_message: handle_websocket_message, // Called for each message
    on_close: handle_websocket_close,    // Called when disconnected
  )
}
```

**Important**: Notice the `dependencies` parameter. This is Dream's way of avoiding closures. Instead of capturing `user` and `services` in a closure, we bundle them into a `ChatDependencies` type and pass them explicitly to every handler.

### Step 4: Connection Established - `on_init` Handler Runs

When the WebSocket connection is established, Dream calls `handle_websocket_init`:

```gleam
pub fn handle_websocket_init(
  connection: websocket.Connection,
  dependencies: ChatDependencies,
) -> websocket.Action(ChatState, ChatMessage) {
  // 1. Subscribe this connection to the chat broadcaster
  // This is like saying "add me to the mailing list"
  let client_id = chat_service.subscribe(dependencies.services, connection)

  // 2. Send a join notification to all OTHER users
  let join_msg = ChatMessage(
    sender: dependencies.user,
    content: dependencies.user <> " joined the chat",
    message_type: "notification",
  )
  chat_service.broadcast(dependencies.services, join_msg, except: [client_id])

  // 3. Set up this connection's state
  // The state is stored by Dream and passed to future handler calls
  let state = ChatState(
    client_id: client_id,
    user: dependencies.user,
    services: dependencies.services,
  )

  // 4. Tell Dream to continue with this state
  websocket.continue_with_state(state)
}
```

**What's happening here:**

1. **Subscribe to broadcaster** - The broadcaster service is like a mailing list. Every connection subscribes so it can receive messages.

2. **Broadcast join notification** - Tell everyone else "Alice joined". The `except: [client_id]` means "send to everyone BUT Alice" (she doesn't need to know she joined).

3. **Create state** - This `ChatState` will be passed to every future message handler. It's how we remember the user's name and client ID.

4. **Return continuation** - Tell Dream "keep this connection alive with this state".

### Step 5: User Sends a Message - `on_message` Handler Runs

When the JavaScript calls `ws.send("Hello!")`, Dream receives it and calls `handle_websocket_message`:

```gleam
pub fn handle_websocket_message(
  state: ChatState,
  message: websocket.Message(ChatMessage),
  dependencies: ChatDependencies,
) -> websocket.Action(ChatState, ChatMessage) {
  case message {
    // User sent text like "Hello!"
    websocket.TextMessage(text) -> {
      // 1. Create a chat message with sender's name
      let chat_msg = ChatMessage(
        sender: state.user,
        content: text,
        message_type: "message",
      )

      // 2. Broadcast to ALL users (including sender)
      // This is different from join - everyone sees chat messages
      chat_service.broadcast(state.services, chat_msg, except: [])

      // 3. Keep the state unchanged and continue
      websocket.continue_with_state(state)
    }

    // Handle other message types (binary, close, etc.)
    _ -> websocket.continue_with_state(state)
  }
}
```

**Message Flow Diagram:**

```
Alice's Browser            Server            Bob's Browser
      |                      |                      |
      |--"Hello!"----------->|                      |
      |                      |                      |
      |          [Create ChatMessage]               |
      |          [sender: "Alice"]                  |
      |          [content: "Hello!"]                |
      |                      |                      |
      |          [Broadcast to all]                 |
      |<--Alice: Hello!------|                      |
      |                      |---Alice: Hello!----->|
```

### Step 6: The Broadcaster Service - How Multi-User Chat Works

You might be wondering: "How does the server send messages to all connected users?"

This is where the **broadcaster service** comes in. It's the infrastructure that makes real-time chat possible.

#### What is the Broadcaster?

The broadcaster is a long-running process that:
1. **Keeps a registry** of all connected WebSocket connections
2. **Receives messages** from any part of your application
3. **Sends to all subscribers** (or all except certain IDs)

Think of it like a radio station - clients "tune in" by subscribing, and the broadcaster sends signals to everyone listening.

#### How to Use the Broadcaster

**Initialize it once when your app starts:**

```gleam
// services/chat_service.gleam
pub fn initialize() -> Services {
  // Start the broadcaster process
  let assert Ok(broadcaster) = broadcaster.start_broadcaster()
  Services(broadcaster: broadcaster)
}
```

**Subscribe when a WebSocket connects:**

```gleam
// Returns a unique ClientId for this connection
let client_id = chat_service.subscribe(services, connection)
```

**Broadcast a message to all subscribers:**

```gleam
// Send to everyone
chat_service.broadcast(services, message, except: [])

// Send to everyone EXCEPT certain IDs (e.g., the sender)
chat_service.broadcast(services, message, except: [client_id])
```

**Unsubscribe when disconnecting:**

```gleam
chat_service.unsubscribe(services, client_id)
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

```gleam
pub fn handle_websocket_close(
  state: ChatState,
  dependencies: ChatDependencies,
) -> Nil {
  // 1. Unsubscribe from the broadcaster
  // This is like removing yourself from the mailing list
  chat_service.unsubscribe(state.services, state.client_id)

  // 2. Tell everyone else that this user left
  let leave_msg = ChatMessage(
    sender: state.user,
    content: state.user <> " left the chat",
    message_type: "notification",
  )
  chat_service.broadcast(state.services, leave_msg, except: [state.client_id])
}
```

**Cleanup is critical:**
- If you don't unsubscribe, the broadcaster will try to send to a closed connection (crashes!)
- Sending a leave notification gives good UX (users know who left)
- The `on_close` handler always runs, even if the connection dies unexpectedly

---

## Complete Message Type Reference

### Gleam ChatMessage Type

```gleam
pub type ChatMessage {
  ChatMessage(
    sender: String,        // Who sent this message?
    content: String,       // What's the message content?
    message_type: String,  // "message" or "notification"
  )
}
```

### JSON Format Sent to Browsers

```json
// Regular chat message
{
  "sender": "Alice",
  "content": "Hello everyone!",
  "type": "message"
}

// Join notification
{
  "sender": "Bob",
  "content": "Bob joined the chat",
  "type": "notification"
}

// Leave notification
{
  "sender": "Alice",
  "content": "Alice left the chat",
  "type": "notification"
}
```

The JavaScript client parses these and displays them differently (messages in white, notifications in gray).

---

## Frontend Code Explained (JavaScript + CSS)

The frontend has two main parts: **JavaScript** for WebSocket logic and **CSS** for styling.

### JavaScript: Managing WebSocket Connection

The file `assets/scripts/chat.js` handles all client-side WebSocket logic:

#### 1. Welcome Screen → Chat Screen Flow

```javascript
// Start on welcome screen
function showWelcomeScreen() {
  welcomeScreen.style.display = 'flex';
  chatScreen.style.display = 'none';
}

// User clicks "Join Chat"
function joinChat() {
  const name = nameInput.value.trim();
  if (!name) return;  // Require a name
  
  currentUser = name;
  connect(name);      // Establish WebSocket
  showChatScreen();   // Show chat interface
}

// Show chat screen after connecting
function showChatScreen() {
  welcomeScreen.style.display = 'none';
  chatScreen.style.display = 'flex';
  usernameDisplay.textContent = currentUser;
}
```

#### 2. WebSocket Connection Management

```javascript
function connect(username) {
  // Construct WebSocket URL with username
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const host = window.location.host;
  const wsUrl = `${protocol}//${host}/chat?user=${encodeURIComponent(username)}`;
  
  // Create WebSocket connection
  ws = new WebSocket(wsUrl);
  
  // Set up event handlers
  ws.onopen = () => {
    console.log('Connected to chat');
    connectionStatus.textContent = 'Connected';
  };
  
  ws.onmessage = (event) => {
    // Parse JSON message from server
    const data = JSON.parse(event.data);
    displayMessage(data);
  };
  
  ws.onerror = (error) => {
    console.error('WebSocket error:', error);
    connectionStatus.textContent = 'Connection error';
  };
  
  ws.onclose = () => {
    console.log('Disconnected from chat');
    connectionStatus.textContent = 'Disconnected';
    // Return to welcome screen on disconnect
    showWelcomeScreen();
  };
}
```

**Important Details:**

- `encodeURIComponent(username)` prevents injection attacks and handles special characters
- The protocol switches between `ws:` and `wss:` based on HTTP/HTTPS
- `ws.onclose` returns to welcome screen - users can rejoin with a different name

#### 3. Sending Messages

```javascript
function sendMessage() {
  const text = messageInput.value.trim();
  if (!text || !ws || ws.readyState !== WebSocket.OPEN) return;
  
  // Send as plain text to server
  ws.send(text);
  
  // Clear input
  messageInput.value = '';
}

// Send on Enter key (without Shift)
messageInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});
```

**Why check `ws.readyState`?**

If the connection is closed, `ws.send()` will throw an error. Checking prevents crashes.

#### 4. Displaying Messages

```javascript
function displayMessage(data) {
  const messageDiv = document.createElement('div');
  
  // Different styling for messages vs notifications
  if (data.type === 'notification') {
    messageDiv.className = 'message notification';
    messageDiv.textContent = data.content;  // "Alice joined the chat"
  } else {
    messageDiv.className = 'message';
    
    const senderSpan = document.createElement('span');
    senderSpan.className = 'sender';
    senderSpan.textContent = data.sender + ': ';
    
    const contentSpan = document.createElement('span');
    contentSpan.className = 'content';
    contentSpan.textContent = data.content;
    
    messageDiv.appendChild(senderSpan);
    messageDiv.appendChild(contentSpan);
  }
  
  // Add to message list
  messagesList.appendChild(messageDiv);
  
  // Auto-scroll to bottom
  messagesList.scrollTop = messagesList.scrollHeight;
}
```

**UX Considerations:**

- Notifications have gray text, messages have white
- Auto-scroll keeps latest messages visible
- Sender name is bolded for readability

### CSS: Modern Gradient Design

The file `assets/styles/chat.css` provides the visual design:

#### Key Design Elements

```css
/* Animated gradient background */
body {
  background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
  background-size: 400% 400%;
  animation: gradient 15s ease infinite;
}

/* Welcome screen centered on page */
.welcome-screen {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100vh;
}

/* Chat screen takes full viewport */
.chat-screen {
  display: flex;
  flex-direction: column;
  height: 100vh;
  max-width: 800px;
  margin: 0 auto;
}

/* Messages scroll independently */
.messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
}

/* Input area fixed at bottom */
.input-area {
  display: flex;
  gap: 10px;
  padding: 20px;
  background: rgba(255, 255, 255, 0.95);
}
```

**Design Principles:**

- **Flexbox layout** - Responsive, easy to maintain
- **Full viewport height** - Chat uses entire screen
- **Translucent panels** - Modern glassmorphism effect
- **Smooth animations** - Gradient background, hover effects

## Dream's No-Closure Pattern (Important!)

### Why No Closures?

Dream has a strict rule: **no closures in controller code**. This might seem restrictive, but there's a good reason:

**Problem with closures:**
```gleam
// ❌ BAD - Closure captures dependencies invisibly
pub fn handle_upgrade(request, context, services) {
  let user = get_user(request)
  
  // This looks innocent, but it's hiding dependencies
  websocket.upgrade(request, on_init: fn(conn) {
    // `user` and `services` are captured from outer scope
    // A future developer can't see what this function needs!
    subscribe(services, conn, user)
  })
}
```

**Dream's solution: explicit dependencies:**
```gleam
// ✅ GOOD - Dependencies are explicit parameters
pub fn handle_upgrade(request, context, services) {
  let user = get_user(request)
  let dependencies = ChatDependencies(user: user, services: services)
  
  // Clear: every handler receives dependencies as a parameter
  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_websocket_init,  // Gets dependencies as parameter
  )
}
```

**Benefits:**
1. **Visible dependencies** - You can see exactly what each function needs
2. **Easier testing** - Mock the `dependencies` parameter
3. **Better documentation** - Type signatures show all inputs
4. **Prevents bugs** - Can't accidentally capture stale values

### The ChatDependencies Pattern

This example bundles dependencies into a single type:

```gleam
pub type ChatDependencies {
  ChatDependencies(
    user: String,      // The username from the query parameter
    services: Services, // App services (broadcaster, database, etc.)
  )
}
```

**Why bundle?**

Without bundling, every handler would need many parameters:

```gleam
// Without bundling - too many parameters!
fn handle_init(conn, user, services, config, logger, ...) { ... }

// With bundling - clean!
fn handle_init(conn, dependencies: ChatDependencies) { ... }
```

You can add more fields to `ChatDependencies` without changing every handler signature.

## Server-Agnostic Design (No Vendor Lock-In)

Dream abstracts the underlying WebSocket server (Mist) so your application isn't locked to one implementation.

### What You Use (Dream Types)

```gleam
import dream/servers/mist/websocket

// Dream's message types
case message {
  websocket.TextMessage(text) -> ...
  websocket.BinaryMessage(data) -> ...
  websocket.CustomMessage(custom) -> ...
  websocket.ConnectionClosed -> ...
}

// Dream's action types
websocket.continue_with_state(state)
websocket.stop_connection()
```

### What You Don't See (Mist Types - Internal Only)

```gleam
// ❌ You NEVER import or use these in your controller
import mist

mist.Text(text)           // Hidden by websocket.TextMessage
mist.Binary(data)         // Hidden by websocket.BinaryMessage
mist.ServerClose(...)     // Hidden by websocket.ConnectionClosed
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

```bash
cd examples/websocket_chat
make test-integration
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

The tests are written in human-readable Gherkin:

```gherkin
Scenario: Send and receive chat messages
  Given the server is running
  When user "Alice" connects to the chat
  And user "Alice" sends message "Hello, World!"
  Then user "Alice" should receive message from "Alice" saying "Hello, World!"
```

**Why Gherkin?**

- Non-programmers can read and understand tests
- Serves as living documentation
- Forces you to think about user behavior, not implementation
- Can be shared with product managers and stakeholders

### Test Implementation (Step Definitions)

The Gherkin steps are implemented in Elixir using `WebSockex`:

```elixir
# test/integration/features/step_definitions/websocket_steps.exs
defmodule WebsocketSteps do
  use Cucumber.StepDefinition

  when_ ~r/^user "(?<user>[^"]+)" connects to the chat$/, fn state, %{user: user} ->
    # Actually connect to WebSocket using WebSockex
    {:ok, pid} = TestClient.start_link(user)
    # Store the connection for later steps
    users = Map.put(state.users || %{}, user, pid)
    {:ok, %{state | users: users}}
  end
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

You might want different handlers for different message types:

```gleam
fn handle_websocket_message(state, message, deps) {
  case message {
    websocket.TextMessage(text) -> {
      // Parse the text to determine message type
      case parse_message_type(text) {
        ChatMessage(content) -> handle_chat_message(state, content, deps)
        TypingIndicator -> handle_typing_indicator(state, deps)
        ReadReceipt(msg_id) -> handle_read_receipt(state, msg_id, deps)
      }
    }
    _ -> websocket.continue_with_state(state)
  }
}
```

### Pattern: Authentication in WebSocket

WebSockets don't have headers for each message, so authenticate during upgrade:

```gleam
pub fn handle_upgrade(request, context, services) {
  // Check auth token during upgrade
  case validate_auth_token(request) {
    Ok(user) -> {
      let dependencies = ChatDependencies(user: user.name, services: services)
      websocket.upgrade_websocket(request, dependencies: dependencies, ...)
    }
    Error(_) -> response.unauthorized("Invalid auth token")
  }
}
```

### Gotcha: Unsubscribe or Leak Memory!

Always unsubscribe in `on_close`:

```gleam
fn handle_websocket_close(state, deps) {
  // ⚠️ CRITICAL: Always unsubscribe!
  chat_service.unsubscribe(state.services, state.client_id)
  
  // Without this, the broadcaster keeps trying to send to a dead connection
}
```

### Gotcha: Connection State is Per-Connection

Each WebSocket connection has its own state. If you need shared state across users, use a service:

```gleam
// ❌ BAD - State is per-connection, not shared
type ChatState {
  ChatState(
    all_messages: List(String), // Each connection has its own list!
  )
}

// ✅ GOOD - Shared state in a service
// Each connection subscribes to the service
let client_id = chat_service.subscribe(services, connection)
```

## Troubleshooting

### "Address already in use" Error

**Problem:** Port 8080 is already in use by another process.

**Solution:**

```bash
# Find the process using port 8080
lsof -i :8080

# Kill it
kill -9 <PID>

# Or use a different port
PORT=3000 make run
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

```bash
# Make sure server isn't already running
pkill -f websocket_chat

# Tests will start their own server
make test-integration
```

### "Module not found" Errors

**Problem:** Gleam can't find `dream` or `broadcaster` modules.

**Solution:**

```bash
# Install dependencies
gleam deps download

# Rebuild
gleam build
```

## Building Your Own WebSocket App

Want to adapt this example for your use case? Here's a step-by-step guide:

### 1. Define Your Message Types

```gleam
// types/my_message.gleam
pub type MyMessage {
  // What messages will your app send/receive?
  UserTyping(user: String)
  DocumentEdit(doc_id: String, change: String)
  StatusUpdate(user_id: String, status: String)
}
```

### 2. Create Your Service

```gleam
// services/my_service.gleam
import dream/services/broadcaster

pub type Services {
  Services(broadcaster: broadcaster.Broadcaster)
}

pub fn initialize() -> Services {
  let assert Ok(broadcaster) = broadcaster.start_broadcaster()
  Services(broadcaster: broadcaster)
}

pub fn subscribe(services, connection) {
  broadcaster.subscribe(services.broadcaster, connection)
}

pub fn broadcast(services, message) {
  let json = encode_message(message)
  broadcaster.send(services.broadcaster, json, except: [])
}
```

### 3. Create Your Dependencies Type

```gleam
// controllers/my_controller.gleam
pub type MyDependencies {
  MyDependencies(
    // What does your app need?
    user_id: String,
    session_id: String,
    services: Services,
  )
}
```

### 4. Write Your Handlers

```gleam
pub fn handle_websocket_init(
  connection: websocket.Connection,
  dependencies: MyDependencies,
) -> websocket.Action(MyState, MyMessage) {
  // Subscribe, set up state, notify others, etc.
  let client_id = my_service.subscribe(dependencies.services, connection)
  
  let state = MyState(
    client_id: client_id,
    user_id: dependencies.user_id,
    // ... other state
  )
  
  websocket.continue_with_state(state)
}

pub fn handle_websocket_message(
  state: MyState,
  message: websocket.Message(MyMessage),
  dependencies: MyDependencies,
) -> websocket.Action(MyState, MyMessage) {
  case message {
    websocket.TextMessage(text) -> {
      // Handle your specific message format
      // Broadcast to others, update state, etc.
      websocket.continue_with_state(state)
    }
    _ -> websocket.continue_with_state(state)
  }
}

pub fn handle_websocket_close(
  state: MyState,
  dependencies: MyDependencies,
) -> Nil {
  // Always unsubscribe!
  my_service.unsubscribe(state.services, state.client_id)
}
```

### 5. Set Up Routing

```gleam
// router.gleam
import dream/router.{route, router}

pub fn routes() -> Router {
  router()
  |> route(method: Get, path: "/ws", controller: my_controller.handle_upgrade, middleware: [])
  |> route(method: Get, path: "/", controller: home_controller.show, middleware: [])
}
```

### 6. Write Frontend JavaScript

```javascript
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

```gherkin
# test/integration/features/my_feature.feature
Feature: My WebSocket Feature

Scenario: User receives real-time updates
  Given the server is running
  When user "Alice" connects
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

