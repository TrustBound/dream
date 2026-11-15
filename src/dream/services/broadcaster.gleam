import gleam/erlang/process.{type Monitor, type Selector, type Subject}
import gleam/list
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
/// The broadcaster monitors the process that owns each channel. When that
/// process stops, the broadcaster removes all of its channels, so a consumer
/// that stops without calling `unsubscribe/2` does not stay subscribed.
///
/// For more complex routing, per-room partitioning, or persistence, treat this
/// as a building block and layer additional actor logic on top.
///
/// ## Example
///
/// ### Broadcast chat messages <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster.gleam#L3-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
  CountSubscribers(reply_to: Subject(Int))
  SubscriberDown(process.Down)
}

/// A subscribed channel subject and the monitor on the process that owns it.
type Subscriber(message) {
  Subscriber(subject: Subject(message), monitor: Monitor)
}

/// Start a new broadcaster service.
///
/// Returns an error if the broadcaster fails to start.
///
/// ## Example
///
/// ### Start a broadcaster <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L12-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
  actor.new_with_initialiser(
    initialisation_timeout_milliseconds,
    initialise_broadcaster,
  )
  |> actor.on_message(handle_broadcaster_message)
  |> actor.start
  |> result.map(wrap_broadcaster_subject)
}

const initialisation_timeout_milliseconds = 1000

/// Select the broadcaster's own subject and the down messages of all monitors
/// that the broadcaster sets up, so one selector serves every subscriber.
fn initialise_broadcaster(
  subject: Subject(BroadcasterMessage(message)),
) -> Result(
  actor.Initialised(
    List(Subscriber(message)),
    BroadcasterMessage(message),
    Subject(BroadcasterMessage(message)),
  ),
  String,
) {
  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_monitors(SubscriberDown)
  actor.initialised([])
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn wrap_broadcaster_subject(
  started: actor.Started(Subject(BroadcasterMessage(message))),
) -> Broadcaster(message) {
  Broadcaster(subject: started.data)
}

/// Subscribe to receive messages from the broadcaster.
///
/// Returns a channel that will receive all messages published
/// to the broadcaster. The calling process owns the channel. When that
/// process stops, the broadcaster removes the channel.
///
/// ## Example
///
/// ### Subscribe <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L19-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
/// ### Publish a message <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L27-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
/// The channel will no longer receive published messages, and the
/// broadcaster stops monitoring the channel's owner for this channel.
/// You do not have to call this before the subscribing process stops: the
/// broadcaster removes the channels of a stopped process automatically.
///
/// ## Example
///
/// ### Unsubscribe a channel <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L31-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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

/// Count the channels that are subscribed to the broadcaster.
///
/// Returns an error if the broadcaster does not reply within 5 seconds, for
/// example because it has stopped. A channel whose owner has stopped is
/// counted until the broadcaster handles the down message for that owner.
///
/// ## Example
///
/// ### Count subscribers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L46-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn listener_count(
///   my_broadcaster: broadcaster.Broadcaster(message),
/// ) -> Result(Int, Nil) {
///   broadcaster.count_subscribers(my_broadcaster)
/// }
/// ```
pub fn count_subscribers(
  broadcaster: Broadcaster(message),
) -> Result(Int, Nil) {
  let Broadcaster(subject) = broadcaster
  let reply_subject = process.new_subject()
  process.send(subject, CountSubscribers(reply_subject))
  process.selector_receive(
    process.new_selector() |> process.select(reply_subject),
    count_timeout_milliseconds,
  )
}

const count_timeout_milliseconds = 5000

/// Convert a channel to a selector for use in WebSocket message loops.
///
/// This allows the channel to be used with `process.Selector` to receive
/// messages in the WebSocket handler's event loop.
///
/// ## Example
///
/// ### Use a channel in a selector <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_broadcaster_functions.gleam#L38-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
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
  subscribers: List(Subscriber(message)),
  message: BroadcasterMessage(message),
) -> actor.Next(List(Subscriber(message)), BroadcasterMessage(message)) {
  case message {
    Subscribe(subscriber) -> {
      actor.continue(add_subscriber(subscribers, subscriber))
    }
    Unsubscribe(subscriber) -> {
      let remaining_subscribers = remove_subscriber(subscribers, subscriber)
      actor.continue(remaining_subscribers)
    }
    Publish(broadcast_message) -> {
      send_to_all_subscribers(subscribers, broadcast_message)
      actor.continue(subscribers)
    }
    CountSubscribers(reply_to) -> {
      process.send(reply_to, list.length(subscribers))
      actor.continue(subscribers)
    }
    SubscriberDown(process.ProcessDown(monitor:, ..)) -> {
      actor.continue(remove_monitored_subscriber(subscribers, monitor))
    }
    SubscriberDown(process.PortDown(..)) -> {
      actor.continue(subscribers)
    }
  }
}

/// Monitor the owner of the subject and add the subject as a subscriber.
///
/// A subject without an owner is a named subject with no registered process.
/// No process can receive its messages and no down message can ever remove
/// it, so the broadcaster does not add it. `subscribe/1` always creates an
/// unnamed subject, so this does not happen through the public API.
fn add_subscriber(
  subscribers: List(Subscriber(message)),
  subject: Subject(message),
) -> List(Subscriber(message)) {
  case process.subject_owner(subject) {
    Ok(owner) -> [
      Subscriber(subject:, monitor: process.monitor(owner)),
      ..subscribers
    ]
    Error(Nil) -> subscribers
  }
}

fn remove_subscriber(
  subscribers: List(Subscriber(message)),
  to_remove: Subject(message),
) -> List(Subscriber(message)) {
  case subscribers {
    [] -> []
    [subscriber, ..rest] ->
      case_remove_subscriber_item(subscriber, rest, to_remove)
  }
}

fn case_remove_subscriber_item(
  subscriber: Subscriber(message),
  rest: List(Subscriber(message)),
  to_remove: Subject(message),
) -> List(Subscriber(message)) {
  case subscriber.subject == to_remove {
    True -> {
      process.demonitor_process(subscriber.monitor)
      remove_subscriber(rest, to_remove)
    }
    False -> [subscriber, ..remove_subscriber(rest, to_remove)]
  }
}

fn remove_monitored_subscriber(
  subscribers: List(Subscriber(message)),
  down_monitor: Monitor,
) -> List(Subscriber(message)) {
  case subscribers {
    [] -> []
    [subscriber, ..rest] ->
      case_remove_monitored_subscriber_item(subscriber, rest, down_monitor)
  }
}

fn case_remove_monitored_subscriber_item(
  subscriber: Subscriber(message),
  rest: List(Subscriber(message)),
  down_monitor: Monitor,
) -> List(Subscriber(message)) {
  case subscriber.monitor == down_monitor {
    True -> remove_monitored_subscriber(rest, down_monitor)
    False -> [subscriber, ..remove_monitored_subscriber(rest, down_monitor)]
  }
}

fn send_to_all_subscribers(
  subscribers: List(Subscriber(message)),
  broadcast_message: message,
) -> Nil {
  case subscribers {
    [] -> Nil
    [subscriber, ..rest] ->
      send_and_continue(subscriber, rest, broadcast_message)
  }
}

fn send_and_continue(
  subscriber: Subscriber(message),
  rest: List(Subscriber(message)),
  broadcast_message: message,
) -> Nil {
  process.send(subscriber.subject, broadcast_message)
  send_to_all_subscribers(rest, broadcast_message)
}
