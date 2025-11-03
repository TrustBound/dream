//// Singleton pattern for managing stateful services
////
//// This module provides a standardized singleton pattern using OTP processes
//// and recursion. Services maintain state in a recursive loop and handle messages.

import gleam/erlang/process
import gleam/option

/// Message types for singleton communication
pub type SingletonMessage(msg, reply) {
  Call(msg, process.Subject(reply))
  // Synchronous call with reply-to subject
  Cast(msg)
  // Asynchronous cast (no reply)
  Stop
  // Graceful shutdown
}

/// Start a singleton process that maintains state
/// Returns the PID and registers with the given name
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

/// Call singleton synchronously (waits for reply)
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

/// Cast to singleton asynchronously (no reply)
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

/// Check if singleton is running
pub fn is_running(name: process.Name(SingletonMessage(msg, reply))) -> Bool {
  case process.named(name) {
    Ok(_) -> True
    Error(_) -> False
  }
}
