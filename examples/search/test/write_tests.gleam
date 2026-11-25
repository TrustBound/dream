//// The write suite of the guide "Add search to a Dream app". The note IDs
//// follow the order of the tests, so the run gives this suite
//// `max_concurrency: 1`.

import app_request.{answer, send}
import dream/http/request.{Delete, Post, Put}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import search_setup.{type App, add_note, recorder_mode, start_app, stop_app}

pub fn tests() -> TestSuite {
  describe("Write notes", context.setup(start_write_app, teardown: stop_app), [
    it("creates a note and indexes it", fn(app: App) {
      let response =
        send(
          app.services,
          Post,
          "/notes",
          "",
          "{\"title\":\"Buy seeds\",\"body\":\"Carrots and beans\"}",
        )

      answer(response)
      |> should
      |> be_equal(#(
        201,
        "{\"id\":1,\"title\":\"Buy seeds\",\"body\":\"Carrots and beans\",\"indexed\":true}",
      ))
      |> or_fail_with("POST /notes should create and index note 1")
    }),
    it("changes a note and indexes it again", fn(app: App) {
      use Nil <- result.try(add_note(app, "Fix the fence", "The gate is loose"))

      let response =
        send(
          app.services,
          Put,
          "/notes/2",
          "",
          "{\"title\":\"Fix the fence\",\"body\":\"The gate and two posts are loose\"}",
        )

      answer(response)
      |> should
      |> be_equal(#(
        200,
        "{\"id\":2,\"title\":\"Fix the fence\",\"body\":\"The gate and two posts are loose\",\"indexed\":true}",
      ))
      |> or_fail_with("PUT /notes/2 should change and index note 2")
    }),
    it("deletes a note and removes it from the index", fn(app: App) {
      use Nil <- result.try(add_note(app, "Sell the bike", "Ask 80 euros"))

      let response = send(app.services, Delete, "/notes/3", "", "")

      answer(response)
      |> should
      |> be_equal(#(200, "{\"id\":3,\"indexed\":true}"))
      |> or_fail_with("DELETE /notes/3 should remove note 3 from both")
    }),
    it("answers 404 for a note that does not exist", fn(app: App) {
      let response = send(app.services, Delete, "/notes/99", "", "")

      answer(response)
      |> should
      |> be_equal(#(404, "{\"error\":\"No note 99\"}"))
      |> or_fail_with("DELETE /notes/99 should answer 404")
    }),
  ])
}

fn start_write_app() -> Result(App, String) {
  use mode <- result.try(recorder_mode())
  start_app(mode, "notes_write")
}
