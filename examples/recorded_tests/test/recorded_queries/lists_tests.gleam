//// The lists suite of the guide "Test a Dream app's database code with
//// recorded queries". The tests share one database, so the run gives
//// this suite `max_concurrency: 1`.

import app_request.{body_text, send}
import dream/http/request.{type Method, Get, Post}
import dream/http/response.{type Response}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/int
import gleam/result
import gleam/string
import lists/list_model
import lists/router
import recorded_queries/database_setup.{
  type App, recorder_mode, start_app, stop_app,
}

pub fn tests() -> TestSuite {
  describe("Lists", context.setup(start_lists_app, teardown: stop_app), [
    it("creates a list with its items", fn(app: App) {
      let response =
        request(
          app,
          Post,
          "/lists",
          "{\"name\":\"Groceries\",\"items\":[\"Milk\",\"Eggs\"]}",
        )
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(
        201,
        "{\"id\":1,\"name\":\"Groceries\",\"items\":[\"Milk\",\"Eggs\"]}",
      ))
      |> or_fail_with("POST /lists should create Groceries")
    }),
    it("shows a list with its items", fn(app: App) {
      use hardware <- result.try(add_list(app, "Hardware", ["Nails", "Glue"]))
      let response = request(app, Get, "/lists/" <> hardware, "")
      body_text(response)
      |> should
      |> be_equal(
        "{\"id\":"
        <> hardware
        <> ",\"name\":\"Hardware\",\"items\":[\"Nails\",\"Glue\"]}",
      )
      |> or_fail_with("GET /lists/:id should show Hardware")
    }),
    it("keeps no list when an item is too long", fn(app: App) {
      let response =
        request(
          app,
          Post,
          "/lists",
          "{\"name\":\"Party\",\"items\":[\"Cake\",\""
            <> string.repeat("Balloons ", 5)
            <> "\"]}",
        )
      let lists = body_text(request(app, Get, "/lists", ""))
      #(response.status, string.contains(lists, "Party"))
      |> should
      |> be_equal(#(422, False))
      |> or_fail_with("the transaction should roll back, and keep no Party")
    }),
    it("shares a list with a link", fn(app: App) {
      use camping <- result.try(add_list(app, "Camping", ["Tent"]))
      // Playback gives "[hidden]": the recorder never wrote the token
      body_text(request(app, Get, "/lists/" <> camping <> "/share", ""))
      |> string.starts_with("{\"url\":\"/shared/")
      |> should
      |> be_equal(True)
      |> or_fail_with("GET /lists/:id/share should give a link")
    }),
    it("answers 404 for a list that does not exist", fn(app: App) {
      let response = request(app, Get, "/lists/999", "")
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(404, "{\"error\":\"No list 999\"}"))
      |> or_fail_with("GET /lists/999 should answer 404")
    }),
  ])
}

fn start_lists_app() -> Result(App, String) {
  use mode <- result.try(recorder_mode())
  start_app(mode, "lists")
}

fn request(app: App, method: Method, path: String, body: String) -> Response {
  send(router.create_router(), app.services, method, path, body)
}

// Makes a list with the model, and gives its id as text for a path
fn add_list(
  app: App,
  name: String,
  items: List(String),
) -> Result(String, String) {
  list_model.create(app.services.database, name, items)
  |> result.map(fn(created) { int.to_string(created.id) })
  |> result.map_error(string.inspect)
}
