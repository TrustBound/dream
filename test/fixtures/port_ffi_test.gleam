//// Tests for `port_ffi.free_port`, the one helper that gives each server
//// test its TCP port.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/erlang/process
import gleam/list

pub fn tests() -> TestSuite {
  describe("port_ffi", [
    it("gives a different port to each of 200 concurrent callers", fn() {
      // Arrange
      let caller_count = 200
      let ports_subject = process.new_subject()
      let start_subject = process.new_subject()
      list.repeat(Nil, caller_count)
      |> list.each(fn(_caller) {
        process.spawn(fn() {
          let go = process.new_subject()
          process.send(start_subject, go)
          let _ = process.receive(go, 5000)
          process.send(ports_subject, free_port())
        })
      })
      let go_subjects = receive_all(start_subject, caller_count, [])

      // Act
      list.each(go_subjects, fn(go) { process.send(go, Nil) })
      let ports = receive_all(ports_subject, caller_count, [])

      // Assert
      #(list.length(ports), list.length(list.unique(ports)))
      |> should()
      |> be_equal(#(caller_count, caller_count))
      |> or_fail_with("Expected 200 distinct ports from 200 concurrent callers")
    }),
  ])
}

fn receive_all(
  subject: process.Subject(value),
  count: Int,
  received: List(value),
) -> List(value) {
  case count {
    0 -> received
    _ ->
      case process.receive(subject, 5000) {
        Ok(value) -> receive_all(subject, count - 1, [value, ..received])
        Error(Nil) -> received
      }
  }
}

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int
