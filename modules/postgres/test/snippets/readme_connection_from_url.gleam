//// README: Or from URL
////
//// Starts the connection pool from a connection URL.

import dream_postgres/client as postgres

pub fn connect_from_url() -> postgres.Connection {
  postgres.from_url("postgresql://user:pass@localhost:5432/myapp")
}
