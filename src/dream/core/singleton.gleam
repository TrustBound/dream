//// Singleton pattern for stateful services
////
//// Dream uses singletons to manage shared state across requests—database connections,
//// caches, rate limiters, etc. Each singleton runs as an OTP process that maintains
//// state and handles messages.
////
//// ## How It Works
////
//// 1. You start a singleton with initial state and a message handler
//// 2. The singleton runs in a loop, processing messages
//// 3. You send messages using `call()` (synchronous) or `cast()` (async)
//// 4. The handler updates state and optionally returns a reply
////
//// ## Example: Rate Limiter Service
////
//// ```gleam
//// // Define your messages
//// pub type RateLimiterMessage {
////   CheckLimit(user_id: String)
////   ResetLimit(user_id: String)
//// }
////
//// // Define your replies
//// pub type RateLimiterReply {
////   Allowed
////   RateLimited
////   ResetComplete
//// }
////
//// // Define your state
//// pub type RateLimiterState {
////   RateLimiterState(requests: Dict(String, Int))
//// }
////
//// // Message handler
//// fn handle_rate_limit(
////   msg: RateLimiterMessage,
////   state: RateLimiterState
//// ) -> #(RateLimiterState, Option(RateLimiterReply)) {
////   case msg {
////     CheckLimit(user_id) -> {
////       let count = dict.get(state.requests, user_id) |> option.unwrap(0)
////       case count < 100 {
////         True -> {
////           let new_requests = dict.insert(state.requests, user_id, count + 1)
////           #(RateLimiterState(new_requests), Some(Allowed))
////         }
////         False -> #(state, Some(RateLimited))
////       }
////     }
////     ResetLimit(user_id) -> {
////       let new_requests = dict.delete(state.requests, user_id)
////       #(RateLimiterState(new_requests), Some(ResetComplete))
////     }
////   }
//// }
////
//// // Start the service
//// pub fn start() {
////   let name = process.new_name()
////   let initial_state = RateLimiterState(requests: dict.new())
////   singleton.start(name, initial_state, handle_rate_limit)
//// }
////
//// // Use the service
//// pub fn check_user_limit(name, user_id: String) {
////   singleton.call(name, CheckLimit(user_id), timeout: 5000)
//// }
//// ```
////
//// ## Call vs Cast
////
//// - `call()`: Synchronous. Waits for a reply. Use for queries that need results.
//// - `cast()`: Asynchronous. Fire-and-forget. Use for updates that don't need confirmation.
////
//// The postgres service uses this pattern to safely share database connections.

import gleam/erlang/process
import gleam/option

/// Message envelope for singleton communication
///
//// Wraps your custom message types with metadata needed for the singleton pattern.
//// You don't create these directly—use `call()` or `cast()` instead.
pub type SingletonMessage(msg, reply) {
  Call(msg, process.Subject(reply))
  // Synchronous call with reply-to subject
  Cast(msg)
  // Asynchronous cast (no reply)
  Stop
  // Graceful shutdown
}

/// Start a singleton service
///
//// Spawns an OTP process that maintains state and handles messages. The process
//// is registered with the given name so you can call it later.
////
//// ## Parameters
////
//// - `name`: Process name for registration (create with `process.new_name()`)
//// - `initial_state`: Starting state for your service
//// - `handle_message`: Function that processes messages and updates state
////
//// ## Example
////
//// ```gleam
//// let name = process.new_name()
//// let initial_state = CacheState(items: dict.new())
//// singleton.start(name, initial_state, handle_cache_message)
//// ```
pub fn start(
  name: process.Name(SingletonMessage(msg, reply)),
  initial_state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Result(process.Pid, String) {
  case process.named(name) {
    Ok(_) -> Error("Singleton already started")
    Error(_) -> {
      let pid =
        process.spawn(fn() { loop(name, initial_state, handle_message) })
      case process.register(pid, name) {
        Ok(_) -> Ok(pid)
        Error(_) -> Error("Failed to register singleton")
      }
    }
  }
}

/// Recursive loop maintaining state
fn loop(
  name: process.Name(SingletonMessage(msg, reply)),
  state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Nil {
  let subject = process.named_subject(name)
  let msg = process.receive_forever(from: subject)
  case msg {
    Call(message, from) -> {
      let #(new_state, reply) = handle_message(message, state)
      case reply {
        option.Some(response) -> process.send(from, response)
        option.None -> Nil
      }
      loop(name, new_state, handle_message)
    }
    Cast(message) -> {
      let #(new_state, _) = handle_message(message, state)
      loop(name, new_state, handle_message)
    }
    Stop -> Nil
    // Exit loop gracefully
  }
}

/// Send a synchronous message and wait for a reply
///
//// Blocks until the singleton processes the message and returns a reply,
//// or until the timeout expires.
////
//// ## Example
////
//// ```gleam
//// case singleton.call(cache_name, Get("user:123"), timeout: 5000) {
////   Ok(Found(data)) -> Ok(data)
////   Ok(NotFound) -> Error("Not in cache")
////   Error(msg) -> Error("Service error: " <> msg)
//// }
//// ```
pub fn call(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
  timeout: Int,
  // milliseconds
) -> Result(reply, String) {
  case process.named(name) {
    Ok(_pid) -> {
      let subject = process.new_subject()
      let name_subject = process.named_subject(name)
      process.send(name_subject, Call(message, subject))
      case process.receive(from: subject, within: timeout) {
        Ok(reply) -> Ok(reply)
        Error(_) -> Error("Call timeout")
      }
    }
    Error(_) -> Error("Singleton not started")
  }
}

/// Send an asynchronous message (fire-and-forget)
///
//// Sends a message without waiting for a reply. Use this for updates that
//// don't need confirmation. Returns immediately.
////
//// ## Example
////
//// ```gleam
//// // Update cache, don't wait for confirmation
//// singleton.cast(cache_name, Set("user:123", user_data))
//// ```
pub fn cast(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
) -> Result(Nil, String) {
  case process.named(name) {
    Ok(_) -> {
      process.send(process.named_subject(name), Cast(message))
      Ok(Nil)
    }
    Error(_) -> Error("Singleton not started")
  }
}

/// Check if a singleton service is running
///
//// Returns `True` if the singleton is started and registered.
pub fn is_running(name: process.Name(SingletonMessage(msg, reply))) -> Bool {
  case process.named(name) {
    Ok(_) -> True
    Error(_) -> False
  }
}
