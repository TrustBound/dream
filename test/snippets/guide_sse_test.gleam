//// SSE guide: a test of the code around the SSE connection
////
//// The functions are from test/snippets/sse_guide_controller.gleam and
//// test/snippets/sse_guide_broadcast.gleam. The test needs no server: it
//// calls the event builder, the decision before the upgrade, and on_init
//// with a subject of the test process.

import dream/context.{EmptyContext}
import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request, Text}
import dream/router.{EmptyServices}
import dream/servers/mist/sse
import dream/services/broadcaster
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process
import gleam/option.{None, Some}
import snippets/sse_guide_broadcast.{AppEvent}
import snippets/sse_guide_controller.{Dependencies, Tick}

fn events_request(headers: List(Header)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/events/private",
    query: "",
    params: [],
    host: None,
    port: None,
    remote_address: None,
    body: Text(""),
    headers: headers,
    cookies: [],
    content_type: None,
    content_length: None,
  )
}

pub fn tests() -> TestSuite {
  describe("SSE ticker", [
    group("tick_event", [
      it("names the event tick and numbers it with the count", fn() {
        // Act
        let event = sse_guide_controller.tick_event(3)

        // Assert
        event
        |> should
        |> be_equal(
          sse.event("{\"count\": 3}")
          |> sse.event_name("tick")
          |> sse.event_id("3"),
        )
        |> or_fail_with("tick 3 should carry count 3, name tick and id 3")
      }),
    ]),
    group("handle_private_events", [
      it("answers 401 when the token is missing", fn() {
        // Arrange
        let request = events_request([])

        // Act
        let response =
          sse_guide_controller.handle_private_events(
            request,
            EmptyContext,
            EmptyServices,
          )

        // Assert
        response.status
        |> should
        |> be_equal(401)
        |> or_fail_with("a request without a token should get 401")
      }),
      it("upgrades when the token is right", fn() {
        // Arrange
        let request =
          events_request([Header("Authorization", "Bearer secret-token")])

        // Act
        let response =
          sse_guide_controller.handle_private_events(
            request,
            EmptyContext,
            EmptyServices,
          )

        // Assert
        response.status
        |> should
        |> be_equal(200)
        |> or_fail_with("200 tells the server to upgrade to SSE")
      }),
    ]),
    group("handle_init", [
      it("starts the count at counter_start", fn() {
        // Arrange
        let subject = process.new_subject()

        // Act
        let #(state, _selector) =
          sse_guide_controller.handle_init(
            subject,
            Dependencies(counter_start: 5),
          )

        // Assert
        state.count
        |> should
        |> be_equal(5)
        |> or_fail_with("the first tick should carry counter_start")
      }),
      it("sends the first tick to the actor", fn() {
        // Arrange
        let subject = process.new_subject()

        // Act
        let _started =
          sse_guide_controller.handle_init(
            subject,
            Dependencies(counter_start: 0),
          )

        // Assert
        process.receive(subject, 0)
        |> should
        |> be_equal(Ok(Tick))
        |> or_fail_with("on_init should send Tick to its own subject")
      }),
      it("subscribes the actor to the event bus", fn() {
        // Arrange
        let assert Ok(event_bus) = broadcaster.start_broadcaster()
        let dependencies = sse_guide_broadcast.Dependencies(event_bus:)
        let #(_count, selector) =
          sse_guide_broadcast.handle_init(process.new_subject(), dependencies)

        // Act
        broadcaster.publish(event_bus, AppEvent("hello"))

        // Assert
        receive_from(selector)
        |> should
        |> be_equal(Ok(AppEvent("hello")))
        |> or_fail_with("a published event should reach the actor")
      }),
    ]),
  ])
}

fn receive_from(
  selector: option.Option(process.Selector(message)),
) -> Result(message, Nil) {
  case selector {
    Some(selector) -> process.selector_receive(selector, 100)
    None -> Error(Nil)
  }
}
