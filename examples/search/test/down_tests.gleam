//// The suite of the guide "Add search to a Dream app" for the time when
//// OpenSearch is down. Nothing listens on the port of the base request, so
//// this suite needs no recording. The note IDs follow the order of the
//// tests, so the run gives this suite `max_concurrency: 1`.

import app_request.{answer, send}
import dream/http/request.{Delete, Get, Post}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import search_setup.{type App, add_note, start_app_without_search, stop_app}

pub fn tests() -> TestSuite {
  describe(
    "Notes with search down",
    context.setup(start_app_without_search, teardown: stop_app),
    [
      it("answers 503 to a search", fn(app: App) {
        let response = send(app.services, Get, "/search", "q=garden", "")

        answer(response)
        |> should
        |> be_equal(#(
          503,
          "{\"error\":\"Search is unavailable. Try again later.\"}",
        ))
        |> or_fail_with("a search should answer 503 while OpenSearch is down")
      }),
      it("keeps a new note and answers that the index missed it", fn(app: App) {
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
          "{\"id\":1,\"title\":\"Buy seeds\",\"body\":\"Carrots and beans\",\"indexed\":false}",
        ))
        |> or_fail_with("POST /notes should keep the note while search is down")
      }),
      it("deletes a note and answers that the index missed it", fn(app: App) {
        use Nil <- result.try(add_note(app, "Sell the bike", "Ask 80 euros"))

        let response = send(app.services, Delete, "/notes/2", "", "")

        answer(response)
        |> should
        |> be_equal(#(200, "{\"id\":2,\"indexed\":false}"))
        |> or_fail_with("DELETE /notes/2 should remove the note from the store")
      }),
    ],
  )
}
