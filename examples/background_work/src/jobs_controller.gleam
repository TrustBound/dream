//// `POST /jobs` gives a job to the worker and answers at once.
//// `GET /jobs/:id` reads the state of a job from the job table.

import dream/context.{type EmptyContext}
import dream/http/header.{add_header}
import dream/http/params.{require_int}
import dream/http/request.{type Request}
import dream/http/response.{type Response, Response, json_response}
import dream/http/status
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import job_table.{type Job, Done, Failed}
import job_worker.{NoAnswer, NotSaved, QueueFull, Stopping}
import services.{type Services}

/// `POST /jobs` with the input of the job as the body
pub fn create(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case request.body_as_string(request) {
    Error(Nil) ->
      json_response(status.bad_request, error_json("The body is not text"))
    Ok(input) -> submit(services, input)
  }
}

fn submit(services: Services, input: String) -> Response {
  case job_worker.submit(services.worker, input, within: 1000) {
    Ok(id) -> json_response(status.accepted, accepted_json(id))
    Error(QueueFull) ->
      busy("The job queue is full. Try again in a few seconds.")
    Error(Stopping) -> busy("The job worker is stopping.")
    Error(NoAnswer) -> busy("The job worker did not answer.")
    Error(NotSaved(reason:)) -> busy("The job was not saved: " <> reason)
  }
}

/// 503 with `retry-after`: the server is too busy now, for each client
fn busy(message: String) -> Response {
  let response = json_response(status.service_unavailable, error_json(message))
  Response(
    ..response,
    headers: add_header(response.headers, "retry-after", "5"),
  )
}

/// `GET /jobs/:id`
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_int(request, "id") {
    Error(_error) ->
      json_response(status.bad_request, error_json("The id must be a number"))
    Ok(id) -> show_job(services, id)
  }
}

fn show_job(services: Services, id: Int) -> Response {
  case job_table.lookup(services.table, id) {
    Ok(Some(job)) -> json_response(status.ok, job_json(job))
    Ok(None) ->
      json_response(
        status.not_found,
        error_json("No job " <> int.to_string(id)),
      )
    Error(error) ->
      json_response(
        status.internal_server_error,
        error_json("The job table was not read: " <> string.inspect(error)),
      )
  }
}

fn accepted_json(id: Int) -> String {
  json.object([
    #("id", json.int(id)),
    #("status_url", json.string("/jobs/" <> int.to_string(id))),
  ])
  |> json.to_string
}

fn job_json(job: Job) -> String {
  let result = case job.state {
    Done(result:) -> [#("result", json.string(result))]
    Failed(reason:) -> [#("reason", json.string(reason))]
    _ -> []
  }
  json.object([
    #("id", json.int(job.id)),
    #("state", json.string(job_table.state_name(job.state))),
    ..result
  ])
  |> json.to_string
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}
