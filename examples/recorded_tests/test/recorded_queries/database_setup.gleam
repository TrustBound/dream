//// The setup and the teardown of the lists suites: a query recorder, and
//// the services of the app with the connection that it makes.

import dream_postgres/client as postgres
import dream_postgres/recorder.{type Recorder}
import dream_postgres/recording.{
  type RecordedQuery, type RecordedResult, Returned, Text, Tuple,
}
import dream_postgres_client.{type QueryError}
import envoy
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import lists/services.{type Services, Services}

/// What each lists test gets: the services of the app, and the recorder
/// that made their connection.
pub type App {
  App(services: Services, recorder: Recorder)
}

/// The database of `make record`. Only a record run connects to it.
const database_url = "postgresql://dream:dream@localhost:5441/lists"

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no database.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}

/// Starts a recorder that keeps the queries in
/// `test/recordings/queries/<name>.json`, and connects through it.
pub fn start_app(mode: recorder.Mode, name: String) -> Result(App, String) {
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/queries")
    |> recorder.name(name)
    |> recorder.mode(mode)
    |> recorder.result_transformer(hide_share_tokens)
    |> recorder.start(),
  )
  use config <- result.try(
    postgres.parse_config(process.new_name("lists_database"), database_url)
    |> result.map_error(string.inspect),
  )
  // In playback mode, nothing connects to the database
  use database <- result.try(
    recorder.connect(recorder, config) |> result.map_error(string.inspect),
  )
  Ok(App(services: Services(database:), recorder:))
}

pub fn stop_app(app: App) -> Result(Nil, String) {
  recorder.stop(app.recorder)
}

/// Runs in record mode only, before the recorder writes a result: the
/// file never holds a share token.
fn hide_share_tokens(
  query: RecordedQuery,
  result: RecordedResult,
) -> RecordedResult {
  case string.starts_with(query.sql, "SELECT share_token"), result {
    True, Returned(count:, rows:) ->
      Returned(
        count:,
        rows: list.map(rows, fn(_row) { Tuple([Text("[hidden]")]) }),
      )
    _, _ -> result
  }
}

/// The text of a query error: for a query that the recorder failed, the
/// text of its `RecorderError`.
pub fn describe_query_error(error: QueryError) -> String {
  case recorder.error(error) {
    Ok(recorder_error) -> recorder.describe_error(recorder_error)
    Error(Nil) -> string.inspect(error)
  }
}
