//// Enrich Events Operation
////
//// Fetches events from OpenSearch and enriches with user data from Postgres.
//// Demonstrates multi-service coordination with clean pattern.

import gleam/list
import gleam/option
import gleam/result
import models/event/event as event_model
import models/user/user as user_model
import services.{type Services}
import types/errors.{type DataError}
import types/event.{type Event}
import types/user.{type User}

pub type EnrichedEvent {
  EnrichedEvent(event: Event, user: option.Option(User))
}

/// Execute enrich operation
pub fn execute(
  services: Services,
  limit: Int,
) -> Result(List(EnrichedEvent), DataError) {
  use events <- result.try(event_model.recent(services.opensearch, limit))
  Ok(enrich_all_events(events, services))
}

fn enrich_all_events(
  events: List(Event),
  services: Services,
) -> List(EnrichedEvent) {
  list.map(events, enrich_single_event(_, services))
}

fn enrich_single_event(evt: Event, services: Services) -> EnrichedEvent {
  EnrichedEvent(evt, load_user_for_event(evt, services))
}

fn load_user_for_event(evt: Event, services: Services) -> option.Option(User) {
  case evt.user_id {
    option.Some(id) -> user_model.get(services.db, id) |> result_to_option()
    option.None -> option.None
  }
}

fn result_to_option(res: Result(a, b)) -> option.Option(a) {
  case res {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

