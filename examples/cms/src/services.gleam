//// Services - external dependencies
////
//// Just connections and clients, not business logic.
//// Uses dream_config to load configuration from environment.

import config.{type Config}
import dream_opensearch/client as opensearch
import dream_postgres/client as postgres
import services/events_service

pub type Services {
  Services(
    db: postgres.Connection,
    opensearch: opensearch.Client,
    events: events_service.EventsService,
  )
}

pub fn initialize(cfg: Config) -> Services {
  let db = postgres.from_url(cfg.database_url)
  let opensearch_client = opensearch.new(cfg.opensearch_url)
  let events = events_service.init()

  Services(db: db, opensearch: opensearch_client, events: events)
}
