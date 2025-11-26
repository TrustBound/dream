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
/// ```gleam
/// // In services.gleam
/// pub type Services {
///   Services(chat_bus: broadcaster.Broadcaster(ChatMessage))
/// }
///
/// pub fn initialize() -> Services {
///   let assert Ok(chat_bus) = broadcaster.start_broadcaster()
///   Services(chat_bus: chat_bus)
/// }
///
/// // In WebSocket init handler
/// fn handle_init(conn, services: Services) {
///   let channel = broadcaster.subscribe(services.chat_bus)
///   let selector = broadcaster.channel_to_selector(channel)
///   #(initial_state, Some(selector))
/// }
///
/// // Anywhere in your app
/// broadcaster.publish(services.chat_bus, ChatMessage("hello"))
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
/// ```gleam
/// let assert Ok(broadcaster) = broadcaster.start_broadcaster()
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
/// ```gleam
/// let channel = broadcaster.subscribe(my_broadcaster)
/// let selector = broadcaster.channel_to_selector(channel)
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
/// ```gleam
/// broadcaster.publish(my_broadcaster, UserJoined("Alice"))
/// ```
pub fn publish(broadcaster: Broadcaster(message), message: message) -> Nil {
  let Broadcaster(subject) = broadcaster
  process.send(subject, Publish(message))
}

/// Unsubscribe a channel from the broadcaster.
///
/// The channel will no longer receive published messages.
/// Note: This is typically not needed as channels are automatically
/// cleaned up when processes terminate.
///
/// ## Example
///
/// ```gleam
/// broadcaster.unsubscribe(my_broadcaster, channel)
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
/// ```gleam
/// let channel = broadcaster.subscribe(my_broadcaster)
/// let selector = broadcaster.channel_to_selector(channel)
/// #(initial_state, Some(selector))
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
