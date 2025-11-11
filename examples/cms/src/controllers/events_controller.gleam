//// Events Controller - HTTP handlers
////
//// Demonstrates SSE (Server-Sent Events) with clean pattern.
//// No nested cases, no anonymous functions.

import context.{type Context}
import dream/core/http/response.{json_response, sse_response}
import dream/core/http/status
import dream/core/http/transaction.{type Request, type Response}
import gleam/yielder
import operations/enrich_events
import services.{type Services}
import types/event.{type Event}
import views/event_view

/// List recent events (enriched with user data)
pub fn index(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  case enrich_events.execute(services, 50) {
    Ok(enriched) ->
      json_response(
        status.ok,
        "{\"events\": " <> serialize_enriched_events(enriched) <> "}",
      )
    Error(_) ->
      json_response(status.internal_server_error, "{\"error\": \"Internal error\"}")
  }
}

/// Stream events via SSE (real-time push)
pub fn stream(
  _request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let subscribe = services.events.subscribe
  let event_stream =
    subscribe()
    |> yielder.map(format_event_as_sse)
    |> yielder.map(string_to_bits)
  
  sse_response(status.ok, event_stream, "text/event-stream")
}

// Private helpers - all named functions

fn format_event_as_sse(evt: Event) -> String {
  "data: " <> event_view.to_json(evt) <> "\n\n"
}

fn string_to_bits(s: String) -> BitArray {
  <<s:utf8>>
}

fn serialize_enriched_events(_enriched: List(enrich_events.EnrichedEvent)) -> String {
  // Simplified serialization for now
  "[]"
}

