//// Database Initialization
////
//// Sets up the PostgreSQL connection pool and runs migrations using cigogne

import cigogne
import cigogne/config
import dream/core/singleton
import dream/services/postgres
import dream/services/service.{type DatabaseService}
import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import gleam/result
import pog

pub fn db_name() -> process.Name(
  singleton.SingletonMessage(postgres.PostgresMessage, postgres.PostgresReply),
) {
  process.new_name("dream_database")
}

pub fn init_database() -> Result(DatabaseService, String) {
  // Create connection pool name
  let pool_name = process.new_name("dream_postgres_pool")

  // Configure PostgreSQL connection
  let config =
    pog.default_config(pool_name: pool_name)
    |> pog.host("localhost")
    |> pog.port(5434)
    |> pog.database("dream_db")
    |> pog.user("postgres")
    |> pog.password(option.Some("postgres"))
    |> pog.pool_size(10)

  // Start the connection pool
  case pog.start(config) {
    Ok(actor.Started(_pid, connection)) -> {
      // Run migrations using cigogne
      case run_migrations(connection) {
        Ok(_) -> {
          // Start the postgres singleton service
          let name = db_name()
          case postgres.start_with_connection(name, connection) {
            Ok(_) ->
              Ok(service.DatabaseService(connection: connection, name: name))
            Error(e) -> Error("Failed to start postgres service: " <> e)
          }
        }
        Error(e) -> Error("Failed to run migrations: " <> e)
      }
    }
    Error(_) -> Error("Failed to start PostgreSQL connection pool")
  }
}

fn run_migrations(connection: pog.Connection) -> Result(Nil, String) {
  // Create cigogne config using the existing connection
  let cigogne_config =
    config.Config(
      database: config.ConnectionDbConfig(connection: connection),
      migration_table: config.default_mig_table_config,
      migrations: config.MigrationsConfig(
        application_name: "dream",
        migration_folder: option.Some("migrations"),
        dependencies: [],
        no_hash_check: option.None,
      ),
    )

  // Create engine and apply all migrations
  use engine <- result.try(
    cigogne.create_engine(cigogne_config)
    |> result.map_error(fn(e) { format_cigogne_error(e) }),
  )

  cigogne.apply_all(engine)
  |> result.map_error(fn(e) { format_cigogne_error(e) })
}

fn format_cigogne_error(e: cigogne.CigogneError) -> String {
  case e {
    cigogne.DatabaseError(_) -> "Database error during migration"
    cigogne.FSError(_) -> "File system error during migration"
    cigogne.MigrationError(_) -> "Migration error"
    cigogne.ParserError(_) -> "Parser error"
    cigogne.ConfigError(_) -> "Configuration error"
    cigogne.NothingToRollback -> "Nothing to rollback"
    cigogne.NothingToApply -> "Nothing to apply"
    cigogne.LibNotIncluded(name:) -> "Library not included: " <> name
    cigogne.CompoundError(errors:) ->
      "Multiple errors: " <> format_compound_errors(errors)
  }
}

fn format_compound_errors(_errors: List(cigogne.CigogneError)) -> String {
  // Simple error formatting - in production you'd want more detail
  "See logs for details"
}
