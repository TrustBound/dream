//// Base Services type for Dream web framework
////
//// This module provides the base service infrastructure.
//// Applications can define their own Services types with specific services.

import dream/core/singleton
import dream/services/postgres
import gleam/erlang/process
import pog

/// Database service wrapping PostgreSQL connection
pub type DatabaseService {
  DatabaseService(
    connection: pog.Connection,
    name: process.Name(
      singleton.SingletonMessage(postgres.PostgresMessage, postgres.PostgresReply),
    ),
  )
}

