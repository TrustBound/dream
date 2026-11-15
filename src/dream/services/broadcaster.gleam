import gleam/erlang/process.{type Selector, type Subject}
import gleam/otp/actor
import gleam/result

/// Publish/subscribe broadcaster for concurrent consumers
///
/// This module implements a small publish/subscribe (pub/sub) service using
/// Gleam/OTP actors. It is a good fit for broadcasting messages to many
/// WebSocket connections, but it can also be used for any fan-out messaging
/// inside your application.
///
/// The flow is:
///
/// 1. Start a `Broadcaster(message)` at application startup and store it in
///    your `Services` type.
/// 2. Each consumer calls `subscribe/1` to obtain a `Channel(message)`.
/// 3. Convert the channel to a `Selector(message)` with `channel_to_selector/1`
///    when you want to receive messages in a select loop (for example inside a
///    WebSocket handler).
/// 4. Call `publish/2` from anywhere in your app to broadcast a message to all
///    current subscribers.
///
/// For more complex routing, per-room partitioning, or persistence, treat this
/// as a building block and layer additional actor logic on top.
///
/// ## Example
///
/// ### Broadcast chat messages <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster.gleam#L3-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/websocket
/// import dream/services/broadcaster
/// import gleam/erlang/process.{type Selector}
/// import gleam/option.{type Option, Some}
/// import gleam/otp/actor
/// import gleam/result
///
/// pub type ChatMessage {
///   ChatMessage(String)
/// }
///
/// // In services.gleam
/// pub type Services {
///   Services(chat_bus: broadcaster.Broadcaster(ChatMessage))
/// }
///
/// pub fn initialize() -> Result(Services, actor.StartError) {
///   use chat_bus <- result.map(broadcaster.start_broadcaster())
///   Services(chat_bus: chat_bus)
/// }
///
/// // In WebSocket init handler
/// fn handle_init(
///   _connection: websocket.Connection,
///   services: Services,
/// ) -> #(Nil, Option(Selector(ChatMessage))) {
///   let channel = broadcaster.subscribe(services.chat_bus)
///   let selector = broadcaster.channel_to_selector(channel)
///   #(Nil, Some(selector))
/// }
///
/// // Anywhere in your app
/// pub fn say_hello(services: Services) -> Nil {
///   broadcaster.publish(services.chat_bus, ChatMessage("hello"))
/// }
/// ```
pub opaque type Broadcaster(message) {
  Broadcaster(subject: Subject(BroadcasterMessage(message)))
}

/// A channel receives published messages from a broadcaster.
pub opaque type Channel(message) {
  Channel(subject: Subject(message))
}

type BroadcasterMessage(message) {
  Subscribe(Subject(message))
  Unsubscribe(Subject(message))
  Publish(message)
}

/// Start a new broadcaster service.
///
/// Returns an error if the broadcaster fails to start.
///
/// ## Example
///
/// ### Start a broadcaster <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster_functions.gleam#L12-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn start_chat_bus() -> Result(
///   broadcaster.Broadcaster(message),
///   actor.StartError,
/// ) {
///   broadcaster.start_broadcaster()
/// }
/// ```
pub fn start_broadcaster() -> Result(Broadcaster(message), actor.StartError) {
  actor.new([])
  |> actor.on_message(handle_broadcaster_message)
  |> actor.start
  |> result.map(wrap_broadcaster_subject)
}

fn wrap_broadcaster_subject(
  started: actor.Started(Subject(BroadcasterMessage(message))),
) -> Broadcaster(message) {
  Broadcaster(subject: started.data)
}

/// Subscribe to receive messages from the broadcaster.
///
/// Returns a channel that will receive all messages published
/// to the broadcaster.
///
/// ## Example
///
/// ### Subscribe <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster_functions.gleam#L19-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn listen_to(
///   my_broadcaster: broadcaster.Broadcaster(message),
/// ) -> Selector(message) {
///   let channel = broadcaster.subscribe(my_broadcaster)
///   let selector = broadcaster.channel_to_selector(channel)
///   selector
/// }
/// ```
pub fn subscribe(broadcaster: Broadcaster(message)) -> Channel(message) {
  let Broadcaster(subject) = broadcaster
  let subscriber = process.new_subject()
  process.send(subject, Subscribe(subscriber))
  Channel(subject: subscriber)
}

/// Publish a message to all subscribers.
///
/// The message will be sent to all channels that have subscribed
/// to this broadcaster.
///
/// ## Example
///
/// ### Publish a message <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster_functions.gleam#L27-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn announce(my_broadcaster: broadcaster.Broadcaster(ChatEvent)) -> Nil {
///   broadcaster.publish(my_broadcaster, UserJoined("Alice"))
/// }
/// ```
pub fn publish(broadcaster: Broadcaster(message), message: message) -> Nil {
  let Broadcaster(subject) = broadcaster
  process.send(subject, Publish(message))
}

/// Unsubscribe a channel from the broadcaster.
///
/// The channel will no longer receive published messages.
/// Note: The broadcaster does not remove a channel when the subscribing
/// process stops, so call this before that process stops.
///
/// ## Example
///
/// ### Unsubscribe a channel <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster_functions.gleam#L31-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn leave(
///   my_broadcaster: broadcaster.Broadcaster(message),
///   channel: broadcaster.Channel(message),
/// ) -> Nil {
///   broadcaster.unsubscribe(my_broadcaster, channel)
/// }
/// ```
pub fn unsubscribe(
  broadcaster: Broadcaster(message),
  channel: Channel(message),
) -> Nil {
  let Broadcaster(subject) = broadcaster
  let Channel(subscriber) = channel
  process.send(subject, Unsubscribe(subscriber))
}

/// Convert a channel to a selector for use in WebSocket message loops.
///
/// This allows the channel to be used with `process.Selector` to receive
/// messages in the WebSocket handler's event loop.
///
/// ## Example
///
/// ### Use a channel in a selector <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/doc_server_broadcaster_functions.gleam#L38-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn initial_state(
///   my_broadcaster: broadcaster.Broadcaster(message),
/// ) -> #(Int, Option(Selector(message))) {
///   let channel = broadcaster.subscribe(my_broadcaster)
///   let selector = broadcaster.channel_to_selector(channel)
///   #(0, Some(selector))
/// }
/// ```
pub fn channel_to_selector(channel: Channel(message)) -> Selector(message) {
  let Channel(subject) = channel
  process.new_selector()
  |> process.select_map(subject, identity)
}

fn identity(value: a) -> a {
  value
}

fn handle_broadcaster_message(
  subscribers: List(Subject(message)),
  message: BroadcasterMessage(message),
) -> actor.Next(List(Subject(message)), BroadcasterMessage(message)) {
  case message {
    Subscribe(subscriber) -> {
      actor.continue([subscriber, ..subscribers])
    }
    Unsubscribe(subscriber) -> {
      let remaining_subscribers = remove_subscriber(subscribers, subscriber)
      actor.continue(remaining_subscribers)
    }
    Publish(broadcast_message) -> {
      send_to_all_subscribers(subscribers, broadcast_message)
      actor.continue(subscribers)
    }
  }
}

fn remove_subscriber(
  subscribers: List(Subject(message)),
  to_remove: Subject(message),
) -> List(Subject(message)) {
  case subscribers {
    [] -> []
    [subscriber, ..rest] ->
      case_remove_subscriber_item(subscriber, rest, to_remove)
  }
}

fn case_remove_subscriber_item(
  subscriber: Subject(message),
  rest: List(Subject(message)),
  to_remove: Subject(message),
) -> List(Subject(message)) {
  case subscriber == to_remove {
    True -> remove_subscriber(rest, to_remove)
    False -> [subscriber, ..remove_subscriber(rest, to_remove)]
  }
}

fn send_to_all_subscribers(
  subscribers: List(Subject(message)),
  broadcast_message: message,
) -> Nil {
  case subscribers {
    [] -> Nil
    [subscriber, ..rest] ->
      send_and_continue(subscriber, rest, broadcast_message)
  }
}

fn send_and_continue(
  subscriber: Subject(message),
  rest: List(Subject(message)),
  broadcast_message: message,
) -> Nil {
  process.send(subscriber, broadcast_message)
  send_to_all_subscribers(rest, broadcast_message)
}
