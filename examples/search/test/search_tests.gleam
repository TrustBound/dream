//// The search suite of the guide "Add search to a Dream app"

import app_request.{answer, send}
import dream/http/request.{Get}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import search_setup.{
  type App, add_note, recorder_mode, refresh, start_app, stop_app,
}

pub fn tests() -> TestSuite {
  describe("Search notes", context.setup(start_search_app, teardown: stop_app), [
    it("finds the notes that match the search text", fn(app: App) {
      let response = send(app.services, Get, "/search", "q=garden", "")

      answer(response)
      |> should
      |> be_equal(#(
        200,
        "{\"total\":2,\"page\":1,\"size\":10,\"notes\":[{\"id\":1,\"title\":\"Water the garden\",\"body\":\"The tomatoes need water every morning\"},{\"id\":2,\"title\":\"Plan the garden\",\"body\":\"Beans go in the north bed this year\"}]}",
      ))
      |> or_fail_with("GET /search?q=garden should find two notes")
    }),
    it("gives the second page of the hits", fn(app: App) {
      let response =
        send(app.services, Get, "/search", "q=garden&page=2&size=1", "")

      answer(response)
      |> should
      |> be_equal(#(
        200,
        "{\"total\":2,\"page\":2,\"size\":1,\"notes\":[{\"id\":2,\"title\":\"Plan the garden\",\"body\":\"Beans go in the north bed this year\"}]}",
      ))
      |> or_fail_with("page 2 of size 1 should hold the second note")
    }),
    it("answers an empty page when no note matches", fn(app: App) {
      let response = send(app.services, Get, "/search", "q=violin", "")

      answer(response)
      |> should
      |> be_equal(#(200, "{\"total\":0,\"page\":1,\"size\":10,\"notes\":[]}"))
      |> or_fail_with("GET /search?q=violin should find no note")
    }),
    it("answers 400 without a search text", fn(app: App) {
      let response = send(app.services, Get, "/search", "", "")

      answer(response)
      |> should
      |> be_equal(#(400, "{\"error\":\"Give the search text in q\"}"))
      |> or_fail_with("GET /search should ask for q")
    }),
    it("answers 400 for a page past hit 10000", fn(app: App) {
      let response =
        send(app.services, Get, "/search", "q=garden&page=1001&size=10", "")

      answer(response)
      |> should
      |> be_equal(#(
        400,
        "{\"error\":\"page times size must be 10000 or less\"}",
      ))
      |> or_fail_with("a page past hit 10000 should get 400")
    }),
  ])
}

/// Starts the app with the index `notes_search`, adds three notes, and
/// makes them searchable
fn start_search_app() -> Result(App, String) {
  use mode <- result.try(recorder_mode())
  use app <- result.try(start_app(mode, "notes_search"))
  use Nil <- result.try(add_note(
    app,
    "Water the garden",
    "The tomatoes need water every morning",
  ))
  use Nil <- result.try(add_note(
    app,
    "Plan the garden",
    "Beans go in the north bed this year",
  ))
  use Nil <- result.try(add_note(
    app,
    "Call the plumber",
    "The kitchen tap drips at night",
  ))
  use Nil <- result.try(refresh(app))
  Ok(app)
}
