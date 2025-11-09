//// Singleton pattern for stateful services
////
//// Provides OTP process-based state management for services that need to share
//// state across requests (caches, rate limiters, connection pools).

import gleam/erlang/process
import gleam/option

/// Message envelope for singleton communication
pub type SingletonMessage(msg, reply) {
  Call(msg, process.Subject(reply))
  Cast(msg)
  Stop
}

/// Start a singleton service
pub fn start(
  name: process.Name(SingletonMessage(msg, reply)),
  initial_state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Result(process.Pid, String) {
  case process.named(name) {
    Ok(_) -> Error("Singleton already started")
    Error(_) -> start_new_singleton(name, initial_state, handle_message)
  }
}

fn start_new_singleton(
  name: process.Name(SingletonMessage(msg, reply)),
  initial_state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Result(process.Pid, String) {
  let pid = process.spawn(fn() { loop(name, initial_state, handle_message) })
  
  case process.register(pid, name) {
    Ok(_) -> Ok(pid)
    Error(_) -> Error("Failed to register singleton")
  }
}

fn loop(
  name: process.Name(SingletonMessage(msg, reply)),
  state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Nil {
  let subject = process.named_subject(name)
  let msg = process.receive_forever(from: subject)
  
  case msg {
    Call(message, from) -> handle_call(message, from, name, state, handle_message)
    Cast(message) -> handle_cast(message, name, state, handle_message)
    Stop -> Nil
  }
}

fn handle_call(
  message: msg,
  from: process.Subject(reply),
  name: process.Name(SingletonMessage(msg, reply)),
  state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Nil {
  let #(new_state, reply) = handle_message(message, state)
  
  case reply {
    option.Some(response) -> process.send(from, response)
    option.None -> Nil
  }
  
  loop(name, new_state, handle_message)
}

fn handle_cast(
  message: msg,
  name: process.Name(SingletonMessage(msg, reply)),
  state: state,
  handle_message: fn(msg, state) -> #(state, option.Option(reply)),
) -> Nil {
  let #(new_state, _) = handle_message(message, state)
  loop(name, new_state, handle_message)
}

/// Send a synchronous message and wait for a reply
pub fn call(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
  timeout: Int,
) -> Result(reply, String) {
  case process.named(name) {
    Ok(_pid) -> send_call(name, message, timeout)
    Error(_) -> Error("Singleton not started")
  }
}

fn send_call(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
  timeout: Int,
) -> Result(reply, String) {
  let subject = process.new_subject()
  let name_subject = process.named_subject(name)
  process.send(name_subject, Call(message, subject))
  
  case process.receive(from: subject, within: timeout) {
    Ok(reply) -> Ok(reply)
    Error(_) -> Error("Call timeout")
  }
}

/// Send an asynchronous message (fire-and-forget)
pub fn cast(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
) -> Result(Nil, String) {
  case process.named(name) {
    Ok(_) -> send_cast(name, message)
    Error(_) -> Error("Singleton not started")
  }
}

fn send_cast(
  name: process.Name(SingletonMessage(msg, reply)),
  message: msg,
) -> Result(Nil, String) {
  process.send(process.named_subject(name), Cast(message))
  Ok(Nil)
}

/// Check if a singleton service is running
pub fn is_running(name: process.Name(SingletonMessage(msg, reply))) -> Bool {
  case process.named(name) {
    Ok(_) -> True
    Error(_) -> False
  }
}

