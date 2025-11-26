# Dream 2.2.0 Release Notes

**Release Date:** November 25, 2025

Dream 2.2.0 introduces comprehensive WebSocket support with a pub/sub broadcaster service, making it easy to build real-time applications with full server abstraction. This release also improves encapsulation of the Dream type, fixes several configuration bugs, and includes a 1,270+ line educational example with extensive integration tests.

## Key Highlights

- 🎯 **WebSocket Support** - Server-agnostic WebSocket API with no vendor lock-in
- 📡 **Pub/Sub Broadcaster** - Generic OTP-based broadcaster service for real-time messaging
- 🔒 **Dream Type Encapsulation** - Opaque type prevents coupling to internal implementation
- 🔍 **Configuration Accessors** - New functions to inspect Dream instance settings
- 🐛 **Bug Fixes** - Fixed `bind()` configuration persistence and type leakage issues
- 📚 **Comprehensive Example** - 1,270+ line README with complete WebSocket chat app
- ✅ **Integration Tests** - 9 Cucumber scenarios with CI/CD integration
- 📖 **Documentation Overhaul** - Beginner-friendly rewrite with standardized terminology and examples
- ⚙️ **Sensible Defaults** - 10MB max body size (was effectively infinite)

## What's New

### 🆕 WebSocket Support

Dream now includes comprehensive WebSocket support with a server-agnostic API that completely abstracts away the underlying Mist implementation.

**Key Features:**
- Upgrade HTTP requests to WebSocket connections
- Handle text messages, binary messages, and custom application messages
- Full connection lifecycle management (init, message, close)
- Server-agnostic design - users never see Mist types
- No closures required - explicit dependencies pattern
- Pub/sub broadcasting service for fan-out messaging

**New Module: `dream/servers/mist/websocket`**

```gleam
import dream/servers/mist/websocket

pub fn handle_chat_upgrade(request, context, services) {
  let dependencies = ChatDependencies(user: "Alice", services: services)
  
  websocket.upgrade_websocket(
    request,
    dependencies: dependencies,
    on_init: handle_init,
    on_message: handle_message,
    on_close: handle_close,
  )
}
```

**WebSocket Types:**
- `websocket.Connection` - Opaque connection type (hides Mist)
- `websocket.Message(custom)` - Text, Binary, Custom, or ConnectionClosed
- `websocket.Action(state, custom)` - Continue or stop connection
- `websocket.SendError` - Dream's own error type (not Mist's)

**New Module: `dream/services/broadcaster`**

A publish/subscribe broadcaster service for WebSocket and general fan-out messaging:

```gleam
import dream/services/broadcaster

// Start a broadcaster at application startup
let assert Ok(chat_bus) = broadcaster.start_broadcaster()

// Subscribe to receive messages (typically in WebSocket init)
let channel = broadcaster.subscribe(chat_bus)
let selector = broadcaster.channel_to_selector(channel)

// Publish messages to all subscribers
broadcaster.publish(chat_bus, ChatMessage("Hello!"))
```

**Broadcaster Features:**
- Generic OTP actor-based pub/sub service
- Type-safe message distribution to multiple consumers
- Integrates seamlessly with WebSocket selectors
- Automatic subscriber cleanup on process termination
- Suitable for chat rooms, notifications, live updates, etc.
- Building block for more complex routing/partitioning logic

**Complete Example:**
See `examples/websocket_chat/` for a full-featured chat application with:
- Real-time messaging with pub/sub broadcasting
- Join/leave notifications
- Multiple concurrent users
- Comprehensive integration tests
- 1,270+ line README with step-by-step walkthrough
- Complete frontend implementation (JavaScript, CSS)
- Cucumber/Gherkin BDD-style integration tests

### 🔍 Dream Type Accessors

Added public accessor functions to inspect Dream instance configuration:

```gleam
import dream/dream

let app = server.new()
  |> server.max_body_size(5_000_000)
  |> server.bind("0.0.0.0")

// Get configuration
let max_size = dream.get_max_body_size(app)  // Returns 5_000_000
case dream.get_bind_interface(app) {
  Some(interface) -> // Interface is configured
  None -> // Using default
}
```

**Available Accessors:**
- `dream.get_router()` - Get configured router
- `dream.get_context()` - Get configured context
- `dream.get_services()` - Get configured services
- `dream.get_max_body_size()` - Get max body size limit
- `dream.get_bind_interface()` - Get configured bind interface
- `dream.get_server()` - Get underlying server (requires `risks_understood: True`)

**⚠️ About `get_server()`:**

The `get_server()` function requires explicit acknowledgment of risks:

```gleam
// You MUST pass risks_understood: True
let mist_server = dream.get_server(app, risks_understood: True)
```

This function exposes Mist types and breaks Dream's abstraction. Passing `False` will panic. This is intentional - it forces you to consciously acknowledge that you're coupling your code to Mist.

## Improvements

### Dream Type Encapsulation

The `Dream` type is now opaque, preventing users from depending on internal server implementation details:

- Users cannot construct `Dream` values directly
- Users cannot access internal fields directly
- All interaction is through builder functions and accessors
- Prevents accidental coupling to Mist types
- Internal code uses `dream.create()` with labeled arguments for construction
- Framework provides controlled access through accessor functions

**Why This Matters:**
- Ensures backward compatibility for future changes to internal structure
- Makes it impossible to accidentally couple application code to Mist
- Provides cleaner separation between Dream's public API and internal implementation
- Allows Dream to change underlying server implementations without breaking user code

This is **not a breaking change** - users never constructed `Dream` directly, only through `server.new()`.

### Sensible Defaults

- **Max body size**: Changed from effectively infinite (max_int64) to 10MB (10,000,000 bytes)
  - Prevents accidental memory exhaustion from unbounded request bodies
  - Can be overridden with `server.max_body_size()` for specific use cases
  
### Internal Improvements

**Dream Type Construction:**
- Added internal `dream.create()` constructor with labeled arguments
- All internal Dream construction now uses explicit labeled parameters
- Improves maintainability and reduces errors from positional argument changes
- Provides single source of truth for Dream instance creation

**Dependency Management:**
- Removed `glisten` dependency (was only used transiently via `mist`)
- Dream now has zero direct dependencies on lower-level server libraries
- All server types are properly abstracted through Dream's API

## Bug Fixes

### Fixed `bind()` Configuration Persistence

**Bug:** Calling `server.bind("0.0.0.0")` before `server.listen()` would lose the bind configuration.

**Fix:** Bind interface is now stored in the Dream type and properly applied during `listen()`.

```gleam
// Now works correctly!
server.new()
  |> server.router(my_router)
  |> server.bind("0.0.0.0")  // This configuration persists
  |> server.listen(3000)      // Server binds to 0.0.0.0
```

### Fixed Vendor Lock-In in WebSocket API

**Bug:** WebSocket API was leaking Mist and Glisten types (`mist.Text`, `glisten.SocketReason`).

**Fix:** All types are now abstracted through Dream:
- `websocket.TextMessage` instead of `mist.Text`
- `websocket.SendError` instead of `glisten.SocketReason`
- `websocket.Connection` (opaque) instead of `mist.WebsocketConnection`

Users never see Mist types, maintaining Dream's server-agnostic design.

## Documentation

### Beginner-Friendly Documentation Overhaul

Completely revised and standardized all documentation to be more accessible for developers new to Dream:

**Consistency Improvements:**
- Standardized terminology across all documentation files
- Aligned code examples to match actual implementation patterns
- Fixed inconsistencies between different sections explaining the same concepts
- Updated example READMEs with consistent formatting and structure
- Ensured server implementation examples in docs match actual server code

**Enhanced Learning Resources:**
- Improved quickstart guide with clearer explanations
- Updated learning tutorials (hello-world, building-api, auth, advanced patterns)
- Enhanced guides for controllers, templates, testing, streaming, and operations
- Better architecture and design principle documentation
- More detailed examples documentation

**Example Code Improvements:**
- Updated rate_limiter example with better patterns
- Enhanced static file serving example documentation
- Improved streaming_capabilities example clarity
- All examples now follow consistent patterns and conventions

**Impact:**
- ~830 lines added, ~374 lines removed across 24 documentation files
- Every major documentation section touched for consistency
- Removed confusing terminology and ambiguous explanations
- Made it easier for newcomers to understand Dream's patterns

### WebSocket Chat Example

Added comprehensive WebSocket example with extensive documentation:

- **1,270+ line README** covering:
  - What WebSockets are and when to use them (vs. polling, SSE, etc.)
  - Complete architectural overview with data flow diagrams
  - Step-by-step walkthrough of every component (services, controllers, views, templates)
  - Message lifecycle from user input → WebSocket → pub/sub → all clients
  - Frontend JavaScript implementation explained line-by-line
  - CSS styling and modern UI patterns explained
  - Deep dive into Dream's no-closure pattern and why it matters
  - Server-agnostic design philosophy and abstraction benefits
  - Common patterns: room management, user presence, message history
  - Common gotchas: connection handling, state management, error recovery
  - Comprehensive troubleshooting guide
  - Building your own WebSocket app from scratch guide
  - When NOT to use WebSockets (with better alternatives)

- **Complete Frontend Implementation:**
  - Modern, responsive chat UI with welcome screen
  - Vanilla JavaScript (no framework dependencies)
  - Clean CSS with thoughtful UX (auto-scroll, enter-to-send, etc.)
  - Name entry before chat access
  - Join/leave chat flow with notifications
  - Real-time message updates

- **Integration Tests (Cucumber/BDD):**
  - 9 comprehensive scenarios covering all functionality
  - HTTP endpoints (home page, static assets)
  - WebSocket upgrade and connection handling
  - Real-time messaging between multiple users
  - Join and leave notifications
  - Anonymous user defaults
  - Full test suite runs in CI/CD pipeline

## Testing

### New Integration Tests

**WebSocket Chat Example (Cucumber/BDD):**
- Comprehensive integration test suite using Cucumber and Elixir
- 9 behavioral scenarios covering all WebSocket functionality:
  - HTTP endpoint serving (home page, static assets)
  - WebSocket upgrade and connection establishment
  - Real-time messaging between multiple users
  - Join/leave notifications
  - Anonymous user handling
- Custom `TestClient` GenServer for managing WebSocket connections in tests
- Message queue management for async message verification
- Tests run in CI/CD pipeline via `make test-integration`

**Testing Infrastructure:**
- Added Mix dependencies: `cucumber`, `httpoison`, `jason`, `websockex`
- Step definitions for HTTP (`http_steps.exs`) and WebSocket (`websocket_steps.exs`)
- Reusable test patterns for future WebSocket examples
- Full integration with main Dream testing Makefile

### Regression Tests

- Added tests for `bind()` configuration persistence bug fix
- Tests verify bind to localhost, 127.0.0.1, and 0.0.0.0 all work correctly
- Tests verify `max_body_size` default is 10MB (10,000,000 bytes)
- Tests verify Dream type accessors work correctly

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.2.0 and < 3.0.0"
```

Then run:
```bash
gleam deps download
```

### Migration Guide

**No breaking changes!** This release is fully backward compatible.

If you want to use WebSockets:

1. Import the WebSocket module:
   ```gleam
   import dream/servers/mist/websocket
   ```

2. Create a controller that upgrades HTTP to WebSocket:
   ```gleam
   pub fn handle_upgrade(request, context, services) {
     websocket.upgrade_websocket(
       request,
       dependencies: MyDependencies(...),
       on_init: handle_init,
       on_message: handle_message,
       on_close: handle_close,
     )
   }
   ```

3. See `examples/websocket_chat/` for complete working example

If you want to inspect Dream configuration:

```gleam
import dream/dream

let max_size = dream.get_max_body_size(app)
case dream.get_bind_interface(app) {
  Some(interface) -> // Interface configured
  None -> // Using default
}
```

## Acknowledgements

Special thanks to the Dream community for feedback on WebSocket support and the need for better server abstraction.

## Documentation

All packages are available with updated documentation on HexDocs:
- [dream](https://hexdocs.pm/dream) - v2.2.0
- [dream_http_client](https://hexdocs.pm/dream_http_client) - v2.0.0
- [dream_mock_server](https://hexdocs.pm/dream_mock_server) - v1.0.0
- [dream_config](https://hexdocs.pm/dream_config)
- [dream_postgres](https://hexdocs.pm/dream_postgres)
- [dream_opensearch](https://hexdocs.pm/dream_opensearch)
- [dream_json](https://hexdocs.pm/dream_json)
- [dream_ets](https://hexdocs.pm/dream_ets)

## Community

- 📖 [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- 💬 [Discussions](https://github.com/TrustBound/dream/discussions)
- 🐛 [Report Issues](https://github.com/TrustBound/dream/issues)
- 🤝 [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)

