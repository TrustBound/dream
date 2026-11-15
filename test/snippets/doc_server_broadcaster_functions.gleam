//// Doc comment examples: the functions of dream/services/broadcaster

import dream/services/broadcaster
import gleam/erlang/process.{type Selector}
import gleam/option.{type Option, Some}
import gleam/otp/actor

pub type ChatEvent {
  UserJoined(String)
}

pub fn start_chat_bus() -> Result(
  broadcaster.Broadcaster(message),
  actor.StartError,
) {
  broadcaster.start_broadcaster()
}

pub fn listen_to(
  my_broadcaster: broadcaster.Broadcaster(message),
) -> Selector(message) {
  let channel = broadcaster.subscribe(my_broadcaster)
  let selector = broadcaster.channel_to_selector(channel)
  selector
}

pub fn announce(my_broadcaster: broadcaster.Broadcaster(ChatEvent)) -> Nil {
  broadcaster.publish(my_broadcaster, UserJoined("Alice"))
}

pub fn leave(
  my_broadcaster: broadcaster.Broadcaster(message),
  channel: broadcaster.Channel(message),
) -> Nil {
  broadcaster.unsubscribe(my_broadcaster, channel)
}

pub fn initial_state(
  my_broadcaster: broadcaster.Broadcaster(message),
) -> #(Int, Option(Selector(message))) {
  let channel = broadcaster.subscribe(my_broadcaster)
  let selector = broadcaster.channel_to_selector(channel)
  #(0, Some(selector))
}
