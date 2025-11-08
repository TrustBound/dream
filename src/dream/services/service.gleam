//// Service patterns and types
////
//// This module shows example service structures. Most applications define their own
//// `Services` type that holds all the shared dependencies they need.
////
//// ## Your Services Type
////
//// Create a custom type to hold your application's services:
////
//// ```gleam
//// pub type Services {
////   Services(
////     db: process.Name(singleton.SingletonMessage(postgres.PostgresMessage, postgres.PostgresReply)),
////     cache: process.Name(singleton.SingletonMessage(CacheMessage, CacheReply)),
////     http_client: HttpClient,
////   )
//// }
////
//// pub fn initialize_services() -> Services {
////   // Set up database
////   let db_config = pog.Config(..pog.default_config(), database: "myapp")
////   let db = pog.connect(db_config)
////   let db_name = process.new_name()
////   let assert Ok(_) = postgres.start_with_connection(db_name, db)
////   
////   // Set up cache
////   let cache_name = process.new_name()
////   let assert Ok(_) = cache.start(cache_name)
////   
////   // Return services
////   Services(db: db_name, cache: cache_name, http_client: http_client.new())
//// }
//// ```
////
//// Then pass your services to the server and they'll be available in all controllers.

import dream/core/singleton
import dream/services/postgres
import gleam/erlang/process
import pog

/// Example database service wrapper
///
//// This shows one way to structure a database service. Most applications will
//// define their own `Services` type instead of using this directly.
pub type DatabaseService {
  DatabaseService(
    connection: pog.Connection,
    name: process.Name(
      singleton.SingletonMessage(
        postgres.PostgresMessage,
        postgres.PostgresReply,
      ),
    ),
  )
}
