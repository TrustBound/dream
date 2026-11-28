//// Tests for dream/services/broadcaster subscriber cleanup.

import dream/services/broadcaster.{type Broadcaster}
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/result

/// How long a test waits for one message before it fails.
const receive_timeout_milliseconds = 1000

/// How many times a test asks for the subscriber count before it accepts the
/// last answer. The down message of a stopped subscriber can reach the
/// broadcaster after the test process sees that subscriber stop, so a test
/// asks again until the count is the expected count.
const count_attempts = 1000

pub fn tests() -> TestSuite {
  describe("dream/services/broadcaster", [
    it("unsubscribes a channel that is not the newest subscriber", fn() {
      // Arrange
      let started = start_test_broadcaster()

      // Act
      let count = {
        use chat_bus <- result.try(started)
        let first_channel = broadcaster.subscribe(chat_bus)
        let _second_channel = broadcaster.subscribe(chat_bus)
        broadcaster.unsubscribe(chat_bus, first_channel)
        broadcaster.count_subscribers(chat_bus)
      }

      // Assert
      count
      |> should()
      |> be_equal(Ok(1))
      |> or_fail_with("Only the second channel should stay subscribed")
    }),
    it("removes a subscriber whose process stops without unsubscribing", fn() {
      // Arrange
      let started = start_test_broadcaster()

      // Act
      let count = {
        use chat_bus <- result.try(started)
        use Nil <- result.try(run_subscriber_until_stopped(chat_bus, 1))
        wait_for_subscriber_count(chat_bus, 0, count_attempts)
      }

      // Assert
      count
      |> should()
      |> be_ok()
      |> be_equal(0)
      |> or_fail_with("A stopped subscriber should be removed")
    }),
    it("removes a live subscriber when it unsubscribes", fn() {
      // Arrange
      let started = start_test_broadcaster()

      // Act
      let count = {
        use chat_bus <- result.try(started)
        let channel = broadcaster.subscribe(chat_bus)
        broadcaster.unsubscribe(chat_bus, channel)
        broadcaster.count_subscribers(chat_bus)
      }

      // Assert
      count
      |> should()
      |> be_ok()
      |> be_equal(0)
      |> or_fail_with("An unsubscribed channel should be removed")
    }),
    it("delivers to a live subscriber after another subscriber stops", fn() {
      // Arrange
      let started = start_test_broadcaster()

      // Act
      let received = {
        use chat_bus <- result.try(started)
        let channel = broadcaster.subscribe(chat_bus)
        use Nil <- result.try(run_subscriber_until_stopped(chat_bus, 1))
        use _count <- result.try(wait_for_subscriber_count(
          chat_bus,
          1,
          count_attempts,
        ))
        broadcaster.publish(chat_bus, "hello")
        broadcaster.channel_to_selector(channel)
        |> process.selector_receive(receive_timeout_milliseconds)
      }

      // Assert
      received
      |> should()
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("The live subscriber should receive 'hello'")
    }),
    it("removes both subscriptions of a process that subscribed twice", fn() {
      // Arrange
      let started = start_test_broadcaster()

      // Act
      let count = {
        use chat_bus <- result.try(started)
        use Nil <- result.try(run_subscriber_until_stopped(chat_bus, 2))
        wait_for_subscriber_count(chat_bus, 0, count_attempts)
      }

      // Assert
      count
      |> should()
      |> be_ok()
      |> be_equal(0)
      |> or_fail_with("Both subscriptions of a stopped process should go")
    }),
  ])
}

fn start_test_broadcaster() -> Result(Broadcaster(String), Nil) {
  broadcaster.start_broadcaster()
  |> result.replace_error(Nil)
}

/// Start a process that subscribes `subscription_count` times, waits until the
/// broadcaster has handled its subscriptions, and then stops without
/// unsubscribing. Return when that process has stopped.
fn run_subscriber_until_stopped(
  chat_bus: Broadcaster(String),
  subscription_count: Int,
) -> Result(Nil, Nil) {
  let subscriber_pid =
    process.spawn_unlinked(fn() {
      subscribe_times(chat_bus, subscription_count)
      broadcaster.count_subscribers(chat_bus)
    })
  let subscriber_monitor = process.monitor(subscriber_pid)
  process.new_selector()
  |> process.select_specific_monitor(subscriber_monitor, discard_down)
  |> process.selector_receive(receive_timeout_milliseconds)
}

fn discard_down(_down: process.Down) -> Nil {
  Nil
}

fn subscribe_times(chat_bus: Broadcaster(String), remaining: Int) -> Nil {
  case remaining > 0 {
    True -> {
      broadcaster.subscribe(chat_bus)
      subscribe_times(chat_bus, remaining - 1)
    }
    False -> Nil
  }
}

fn wait_for_subscriber_count(
  chat_bus: Broadcaster(String),
  expected: Int,
  attempts_remaining: Int,
) -> Result(Int, Nil) {
  use count <- result.try(broadcaster.count_subscribers(chat_bus))
  case count == expected || attempts_remaining <= 1 {
    True -> Ok(count)
    False ->
      wait_for_subscriber_count(chat_bus, expected, attempts_remaining - 1)
  }
}
