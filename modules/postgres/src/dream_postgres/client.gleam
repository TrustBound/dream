//// PostgreSQL client wrapper
////
//// Provides a clean builder interface to Pog connection management.
//// Follows Dream's builder pattern for consistency.
////
//// ## Example
////
//// ```gleam
//// import dream_postgres/client as postgres
////
//// // Builder pattern
//// let db = postgres.new()
////   |> postgres.host("localhost")
////   |> postgres.port(5432)
////   |> postgres.database("myapp")
////   |> postgres.user("postgres")
////   |> postgres.pool_size(15)
////   |> postgres.connect()
////
//// // Or from URL
//// let db = postgres.from_url("postgresql://user:pass@localhost:5432/myapp")
//// ```

import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import pog

// Re-export Pog types
pub type Connection =
  pog.Connection

pub type Config =
  pog.Config

pub type QueryError =
  pog.QueryError

pub type Value =
  pog.Value

pub type Returned(a) =
  pog.Returned(a)

/// Create a new default PostgreSQL configuration
///
/// Creates a configuration with sensible defaults. You must provide a pool name
/// which is used to identify the connection pool in the process registry.
///
/// ## Parameters
///
/// - `pool_name`: A process name for the connection pool
///
/// ## Returns
///
/// A new `Config` with default values. Use builder functions to customize it.
///
/// ## Example
///
/// ```gleam
/// import dream_postgres/client as postgres
/// import gleam/erlang/process
///
/// let pool_name = process.new_name("my_db_pool")
/// let config = postgres.new(pool_name)
/// ```
pub fn new(pool_name: process.Name(pog.Message)) -> Config {
  pog.default_config(pool_name: pool_name)
}

/// Set the database host
///
/// Sets the hostname or IP address of the PostgreSQL server.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The hostname (e.g., "localhost" or "db.example.com")
///
/// ## Returns
///
/// A new `Config` with the host updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.host("localhost")
/// ```
pub fn host(config: Config, value: String) -> Config {
  pog.Config(..config, host: value)
}

/// Set the database port
///
/// Sets the port number for the PostgreSQL server. Defaults to 5432.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The port number
///
/// ## Returns
///
/// A new `Config` with the port updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.port(5432)
/// ```
pub fn port(config: Config, value: Int) -> Config {
  pog.Config(..config, port: value)
}

/// Set the database name
///
/// Sets the name of the PostgreSQL database to connect to.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The database name
///
/// ## Returns
///
/// A new `Config` with the database name updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.database("myapp_prod")
/// ```
pub fn database(config: Config, value: String) -> Config {
  pog.Config(..config, database: value)
}

/// Set the database user
///
/// Sets the username for authenticating to PostgreSQL.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The username
///
/// ## Returns
///
/// A new `Config` with the user updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.user("postgres")
/// ```
pub fn user(config: Config, value: String) -> Config {
  pog.Config(..config, user: value)
}

/// Set the database password
///
/// Sets the password for authenticating to PostgreSQL.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The password
///
/// ## Returns
///
/// A new `Config` with the password updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.password("secret123")
/// ```
pub fn password(config: Config, value: String) -> Config {
  pog.Config(..config, password: option.Some(value))
}

/// Set the connection pool size
///
/// Sets the maximum number of connections in the pool. The pool manages
/// connections automatically, creating and reusing them as needed.
///
/// ## Parameters
///
/// - `config`: The configuration to modify
/// - `value`: The maximum number of connections (e.g., 15)
///
/// ## Returns
///
/// A new `Config` with the pool size updated.
///
/// ## Example
///
/// ```gleam
/// config
/// |> postgres.pool_size(20)  // Allow up to 20 concurrent connections
/// ```
pub fn pool_size(config: Config, value: Int) -> Config {
  pog.Config(..config, pool_size: value)
}

/// Start the connection pool
///
/// Creates and starts the PostgreSQL connection pool with the provided
/// configuration. The pool will be registered with the process name you
/// provided to `new()`.
///
/// ## Parameters
///
/// - `config`: The complete configuration
///
/// ## Returns
///
/// - `Ok(Connection)`: Successfully started the pool
/// - `Error(StartError)`: Failed to start (e.g., connection refused, invalid config)
///
/// ## Example
///
/// ```gleam
/// import dream_postgres/client as postgres
/// import gleam/erlang/process
///
/// let pool_name = process.new_name("db_pool")
/// let assert Ok(db) = postgres.new(pool_name)
///   |> postgres.host("localhost")
///   |> postgres.port(5432)
///   |> postgres.database("myapp")
///   |> postgres.user("postgres")
///   |> postgres.password("secret")
///   |> postgres.pool_size(15)
///   |> postgres.connect()
/// ```
pub fn connect(config: Config) -> Result(Connection, actor.StartError) {
  pog.start(config)
  |> result.map(extract_connection_from_started)
}

fn extract_connection_from_started(
  started: actor.Started(Connection),
) -> Connection {
  let actor.Started(_pid, connection) = started
  connection
}

/// Connect from a PostgreSQL connection URL
///
/// Parses a PostgreSQL connection URL and creates a connection pool.
/// This is a convenience function for quick setup, but the builder pattern
/// is recommended for production code as it's more explicit and type-safe.
///
/// **Note**: This uses a simple URL parser. For production applications with
/// complex connection requirements, use the builder pattern instead.
///
/// ## URL Format
///
/// ```
/// postgresql://user:password@host:port/database
/// ```
///
/// Examples:
/// - `postgresql://postgres:secret@localhost:5432/myapp`
/// - `postgresql://user@localhost/myapp` (no password)
/// - `postgresql://localhost/myapp` (defaults: user=postgres, port=5432)
///
/// ## Parameters
///
/// - `url`: The PostgreSQL connection URL
///
/// ## Returns
///
/// A `Connection` (panics on parse failure - use builder pattern for error handling).
///
/// ## Example
///
/// ```gleam
/// import dream_postgres/client as postgres
///
/// let db = postgres.from_url("postgresql://postgres:secret@localhost:5432/myapp")
/// ```
pub fn from_url(url: String) -> Connection {
  let pool_name = process.new_name("postgres_pool")

  let assert Ok(connection) =
    new(pool_name)
    |> host(extract_host_from_url(url))
    |> port(extract_port_from_url(url))
    |> database(extract_database_from_url(url))
    |> user(extract_user_from_url(url))
    |> set_password_if_present(extract_password_from_url(url))
    |> pool_size(15)
    |> connect()

  connection
}

fn set_password_if_present(
  config: Config,
  pass: option.Option(String),
) -> Config {
  case pass {
    option.Some(p) -> password(config, p)
    option.None -> config
  }
}

// Private URL parsing - flat functions, no nesting

fn extract_host_from_url(url: String) -> String {
  case string.contains(url, "@") {
    True -> extract_host_after_at(url)
    False -> "localhost"
  }
}

fn extract_host_after_at(url: String) -> String {
  case string.split(url, "@") {
    [_, rest] -> extract_host_from_rest(rest)
    _ -> "localhost"
  }
}

fn extract_host_from_rest(rest: String) -> String {
  case string.split(rest, ":") {
    [host, _] -> host
    _ -> "localhost"
  }
}

fn extract_port_from_url(url: String) -> Int {
  case string.contains(url, "@") {
    True -> extract_port_after_at(url)
    False -> 5432
  }
}

fn extract_port_after_at(url: String) -> Int {
  case string.split(url, "@") {
    [_, rest] -> extract_port_from_rest(rest)
    _ -> 5432
  }
}

fn extract_port_from_rest(rest: String) -> Int {
  case string.split(rest, ":") {
    [_, port_and_db] -> parse_port_from_segment(port_and_db)
    _ -> 5432
  }
}

fn parse_port_from_segment(segment: String) -> Int {
  case string.split(segment, "/") {
    [port_str, _] -> parse_port_string(port_str)
    _ -> 5432
  }
}

fn parse_port_string(port_str: String) -> Int {
  case int.parse(port_str) {
    Ok(port) -> port
    Error(_) -> 5432
  }
}

fn extract_database_from_url(url: String) -> String {
  url
  |> string.split("/")
  |> list.last()
  |> result.unwrap("postgres")
}

fn extract_user_from_url(url: String) -> String {
  case string.contains(url, "://") {
    True -> extract_user_after_protocol(url)
    False -> "postgres"
  }
}

fn extract_user_after_protocol(url: String) -> String {
  case string.split(url, "://") {
    [_, rest] -> extract_user_from_rest(rest)
    _ -> "postgres"
  }
}

fn extract_user_from_rest(rest: String) -> String {
  case string.split(rest, ":") {
    [user, _] -> user
    _ -> "postgres"
  }
}

fn extract_password_from_url(url: String) -> option.Option(String) {
  case string.contains(url, "://") {
    True -> extract_password_after_protocol(url)
    False -> option.None
  }
}

fn extract_password_after_protocol(url: String) -> option.Option(String) {
  case string.split(url, "://") {
    [_, rest] -> extract_password_from_rest(rest)
    _ -> option.None
  }
}

fn extract_password_from_rest(rest: String) -> option.Option(String) {
  case string.split(rest, ":") {
    [_, pass_and_rest] -> extract_password_before_at(pass_and_rest)
    _ -> option.None
  }
}

fn extract_password_before_at(pass_and_rest: String) -> option.Option(String) {
  case string.split(pass_and_rest, "@") {
    [pass, _] -> option.Some(pass)
    _ -> option.None
  }
}
