//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.
//// Database Example
////
//// This example demonstrates how to use the PostgreSQL service with Dream.
//// It shows how to:
//// - Start a PostgreSQL connection pool
//// - Create database tables
//// - Perform CRUD operations (Create, Read, Update, Delete)
//// - Use the service pattern for database connections

import context as db_context
import dream/servers/mist/server.{bind, context, listen, router, services, tls} as dream
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  dream.new()
  |> context(db_context.context)
  |> services(initialize_services())
  |> router(create_router())
  |> bind("localhost")
  |> tls(certfile: "build/test_tls/cert.pem", keyfile: "build/test_tls/key.pem")
  |> listen(3002)
}
