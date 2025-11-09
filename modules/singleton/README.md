# dream_singleton

Generic singleton pattern for Dream applications.

Provides OTP process-based state management for services that need to share state across requests (caches, rate limiters, connection pools).

## Usage

```gleam
import dream_singleton
import gleam/erlang/process

// Define your state
pub type CacheState {
  CacheState(items: Dict(String, String))
}

// Define messages
pub type CacheMessage {
  Get(String)
  Set(String, String)
}

// Define replies
pub type CacheReply {
  Found(String)
  NotFound
  SetComplete
}

// Start singleton
let name = process.new_name()
let initial_state = CacheState(items: dict.new())
dream_singleton.start(name, initial_state, handle_message)

// Use it
dream_singleton.call(name, Get("key"), timeout: 5000)
```

