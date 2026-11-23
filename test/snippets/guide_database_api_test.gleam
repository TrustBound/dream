//// Database API guide: a test of an operation, with no database
////
//// The operation is reorder_task of test/snippets/operations_guide_tasks.gleam.
//// Its tasks come from Services, so the test builds the services it needs.

import dream/http/error.{BadRequest, NotFound}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/operations_guide_tasks.{Services, Task}

fn three_tasks() -> operations_guide_tasks.Services {
  Services(tasks: [
    Task(id: 1, title: "Write"),
    Task(id: 2, title: "Test"),
    Task(id: 3, title: "Ship"),
  ])
}

pub fn tests() -> TestSuite {
  describe("reorder_task", [
    it("moves task 3 to the first place", fn() {
      // Arrange
      let services = three_tasks()

      // Act
      let reordered = operations_guide_tasks.reorder_task(services, 3, 1)

      // Assert
      reordered
      |> should
      |> be_equal(
        Ok([
          Task(id: 3, title: "Ship"),
          Task(id: 1, title: "Write"),
          Task(id: 2, title: "Test"),
        ]),
      )
      |> or_fail_with("task 3 should come first")
    }),
    it("keeps every task when it moves one", fn() {
      // Arrange
      let services = three_tasks()

      // Act
      let reordered = operations_guide_tasks.reorder_task(services, 1, 3)

      // Assert
      reordered
      |> should
      |> be_equal(
        Ok([
          Task(id: 2, title: "Test"),
          Task(id: 3, title: "Ship"),
          Task(id: 1, title: "Write"),
        ]),
      )
      |> or_fail_with("task 1 should come last, and no task should be lost")
    }),
    it("gives NotFound for an unknown task", fn() {
      // Arrange
      let services = three_tasks()

      // Act
      let reordered = operations_guide_tasks.reorder_task(services, 9, 1)

      // Assert
      reordered
      |> should
      |> be_equal(Error(NotFound("Task not found")))
      |> or_fail_with("task 9 should not be found")
    }),
    it("gives BadRequest for a position past the end", fn() {
      // Arrange
      let services = three_tasks()

      // Act
      let reordered = operations_guide_tasks.reorder_task(services, 1, 4)

      // Assert
      reordered
      |> should
      |> be_equal(
        Error(BadRequest("Position must be between 1 and the task count")),
      )
      |> or_fail_with("position 4 of 3 tasks should be refused")
    }),
  ])
}
