//// The search route: `GET /search?q=<text>&page=<page>&size=<size>`

import dream/context.{type EmptyContext}
import dream/http/request.{type Request, get_query_param}
import dream/http/response.{type Response, json_response}
import dream/http/status
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import notes/search_failure
import notes/search_index.{type Paging, Paging, SearchFailed, UnexpectedAnswer}
import notes/services.{type Services}
import notes/views

/// OpenSearch gives no hit past the first 10000 (the index setting
/// `max_result_window`), and answers 400 to a page past it
const last_hit = 10_000

/// Searches the titles and the bodies of the notes. `q` is required.
/// `page` starts at 1, and `size` is from 1 to 50, 10 when not given.
pub fn search(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case read_search(request.query) {
    Ok(#(text, paging)) -> search_notes(services, text, paging)
    Error(message) ->
      json_response(status.bad_request, views.error_json(message))
  }
}

fn search_notes(services: Services, text: String, paging: Paging) -> Response {
  case
    search_index.search_notes(services.opensearch, services.index, text, paging)
  {
    Ok(page) -> json_response(status.ok, views.search_page_json(page))
    Error(SearchFailed(error:)) -> search_failure.to_response(error)
    Error(UnexpectedAnswer(reason:)) ->
      search_failure.unexpected_answer_response(reason)
  }
}

fn read_search(query: String) -> Result(#(String, Paging), String) {
  use text <- result.try(read_text(query))
  use page <- result.try(read_number(
    query,
    "page",
    default: 1,
    highest: last_hit,
  ))
  use size <- result.try(read_number(query, "size", default: 10, highest: 50))
  case page * size <= last_hit {
    True -> Ok(#(text, Paging(page:, size:)))
    False -> Error("page times size must be 10000 or less")
  }
}

fn read_text(query: String) -> Result(String, String) {
  case get_query_param(query, "q") {
    Some("") | None -> Error("Give the search text in q")
    Some(text) -> Ok(text)
  }
}

fn read_number(
  query: String,
  name: String,
  default default: Int,
  highest highest: Int,
) -> Result(Int, String) {
  case get_query_param(query, name) {
    None -> Ok(default)
    Some(text) -> parse_number(text, name, highest)
  }
}

fn parse_number(
  text: String,
  name: String,
  highest: Int,
) -> Result(Int, String) {
  case int.parse(text) {
    Ok(number) if number >= 1 && number <= highest -> Ok(number)
    Ok(_number) | Error(Nil) ->
      Error(name <> " must be a number from 1 to " <> int.to_string(highest))
  }
}
