//// A lists test with no recording, for the guide. It runs only from the
//// output checks, which compare its report.

import dream_postgres/recorder
import dream_test/context
import dream_test/matchers.{fail_with, succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/string
import lists/list_model.{QueryFailed}
import recorded_queries/database_setup.{
  type App, describe_query_error, start_app, stop_app,
}

pub fn tests() -> TestSuite {
  describe(
    "Lists",
    context.setup(
      fn() { start_app(recorder.Playback, "lists") },
      teardown: stop_app,
    ),
    [
      it("finds list 7", fn(app: App) {
        case list_model.get(app.services.database, 7) {
          Ok(_list) -> Ok(succeed())
          // The failure message is the text of the miss
          Error(QueryFailed(error:)) ->
            Ok(fail_with(describe_query_error(error)))
          Error(error) -> Ok(fail_with(string.inspect(error)))
        }
      }),
    ],
  )
}
