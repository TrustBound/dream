//// Database Example
////
//// This example demonstrates how to use the PostgreSQL service with Dream.
//// It shows how to:
//// - Start a PostgreSQL connection pool
//// - Create database tables
//// - Perform CRUD operations (Create, Read, Update, Delete)
//// - Use the service pattern for database connections

import dream/servers/mist/server.{bind, context, listen, router, services} as dream
import examples/database/context as db_context
import examples/database/router.{create_router}
import examples/database/services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(db_context.context)
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> listen(3002)
}
