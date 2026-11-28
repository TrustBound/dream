//// Tests for connection URLs in `dream_postgres/client`.
////
//// `parse_config` is pure, so these tests check exact `Config` values and
//// need no database. The `from_url` tests use a local port that has no
//// listener.

import dream_postgres/client as postgres
import gleam/erlang/atom
import gleam/erlang/process
import gleam/list
import gleam/string
import gleeunit/should
import pog

@external(erlang, "port_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: atom.Atom) -> Int

fn now_in_milliseconds() -> Int {
  monotonic_time(atom.create("millisecond"))
}

fn test_pool_name() -> process.Name(pog.Message) {
  process.new_name("client_test_pool")
}

// ============================================================================
// parse_config: values
// ============================================================================

pub fn parse_config_with_readme_url_sets_every_value_test() {
  // Arrange
  let pool_name = test_pool_name()
  let expected =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.port(5432)
    |> postgres.database("myapp")
    |> postgres.user("user")
    |> postgres.password("pass")

  // Act
  let config =
    postgres.parse_config(
      pool_name,
      "postgresql://user:pass@localhost:5432/myapp",
    )

  // Assert
  config |> should.equal(Ok(expected))
}

pub fn parse_config_decodes_an_encoded_password_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config =
    postgres.parse_config(
      pool_name,
      "postgres://app%20user:p%40ss%3Aw%2Frd@db.example.com:6543/my%20db",
    )

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("db.example.com")
    |> postgres.port(6543)
    |> postgres.database("my db")
    |> postgres.user("app user")
    |> postgres.password("p@ss:w/rd")
  config |> should.equal(Ok(expected))
}

pub fn parse_config_keeps_a_colon_after_the_first_in_the_password_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config =
    postgres.parse_config(pool_name, "postgresql://user:pa:ss@localhost/myapp")

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.database("myapp")
    |> postgres.user("user")
    |> postgres.password("pa:ss")
  config |> should.equal(Ok(expected))
}

pub fn parse_config_without_a_port_uses_5432_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config =
    postgres.parse_config(pool_name, "postgresql://user@localhost/myapp")

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.port(5432)
    |> postgres.database("myapp")
    |> postgres.user("user")
  config |> should.equal(Ok(expected))
}

pub fn parse_config_without_a_user_keeps_the_default_user_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config = postgres.parse_config(pool_name, "postgresql://localhost/myapp")

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.database("myapp")
  config |> should.equal(Ok(expected))
}

pub fn parse_config_maps_supported_query_parameters_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config =
    postgres.parse_config(
      pool_name,
      "postgresql://user:pass@localhost:5432/myapp?sslmode=verify-full&application_name=my%20app",
    )

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.database("myapp")
    |> postgres.user("user")
    |> postgres.password("pass")
    |> pog.ssl(pog.SslVerified)
    |> pog.connection_parameter(name: "application_name", value: "my app")
  config |> should.equal(Ok(expected))
}

pub fn parse_config_maps_each_ssl_mode_test() {
  // Arrange
  let pool_name = test_pool_name()
  let url = "postgresql://localhost/myapp?sslmode="

  // Act
  let modes = [
    postgres.parse_config(pool_name, url <> "disable"),
    postgres.parse_config(pool_name, url <> "require"),
    postgres.parse_config(pool_name, url <> "verify-ca"),
    postgres.parse_config(pool_name, url <> "verify-full"),
  ]

  // Assert
  let base =
    postgres.new(pool_name)
    |> postgres.host("localhost")
    |> postgres.database("myapp")
  modes
  |> should.equal([
    Ok(pog.ssl(base, pog.SslDisabled)),
    Ok(pog.ssl(base, pog.SslUnverified)),
    Ok(pog.ssl(base, pog.SslVerified)),
    Ok(pog.ssl(base, pog.SslVerified)),
  ])
}

pub fn parse_config_with_an_ipv6_host_uses_ipv6_test() {
  // Arrange
  let pool_name = test_pool_name()

  // Act
  let config = postgres.parse_config(pool_name, "postgresql://[::1]:5433/myapp")

  // Assert
  let expected =
    postgres.new(pool_name)
    |> postgres.host("::1")
    |> postgres.port(5433)
    |> postgres.database("myapp")
    |> pog.ip_version(pog.Ipv6)
  config |> should.equal(Ok(expected))
}

// ============================================================================
// parse_config: errors
// ============================================================================

fn parse_error(url: String) -> Result(postgres.Config, postgres.UrlError) {
  postgres.parse_config(test_pool_name(), url)
}

pub fn parse_config_with_a_malformed_url_returns_malformed_url_test() {
  parse_error("postgresql://user:secret@localhost:abc/myapp")
  |> should.equal(Error(postgres.MalformedUrl))
}

pub fn parse_config_without_a_scheme_returns_missing_scheme_test() {
  parse_error("localhost/myapp")
  |> should.equal(Error(postgres.MissingScheme))
}

pub fn parse_config_with_another_scheme_returns_unsupported_scheme_test() {
  parse_error("mysql://user:secret@localhost/myapp")
  |> should.equal(Error(postgres.UnsupportedScheme("mysql")))
}

pub fn parse_config_without_a_host_returns_missing_host_test() {
  parse_error("postgresql:///myapp")
  |> should.equal(Error(postgres.MissingHost))
}

pub fn parse_config_with_port_zero_returns_invalid_port_test() {
  parse_error("postgresql://localhost:0/myapp")
  |> should.equal(Error(postgres.InvalidPort(0)))
}

pub fn parse_config_with_a_port_above_65535_returns_invalid_port_test() {
  parse_error("postgresql://localhost:65536/myapp")
  |> should.equal(Error(postgres.InvalidPort(65_536)))
}

pub fn parse_config_without_a_database_returns_missing_database_test() {
  parse_error("postgresql://localhost:5432")
  |> should.equal(Error(postgres.MissingDatabase))
}

pub fn parse_config_with_an_empty_database_returns_missing_database_test() {
  parse_error("postgresql://localhost:5432/")
  |> should.equal(Error(postgres.MissingDatabase))
}

pub fn parse_config_with_a_nested_path_returns_invalid_database_test() {
  parse_error("postgresql://localhost/my/app")
  |> should.equal(Error(postgres.InvalidDatabase("/my/app")))
}

pub fn parse_config_with_an_empty_user_returns_missing_user_test() {
  parse_error("postgresql://:secret@localhost/myapp")
  |> should.equal(Error(postgres.MissingUser))
}

pub fn parse_config_with_a_bad_user_encoding_returns_invalid_user_encoding_test() {
  parse_error("postgresql://us%zzer:secret@localhost/myapp")
  |> should.equal(Error(postgres.InvalidUserEncoding))
}

pub fn parse_config_with_a_bad_password_encoding_returns_invalid_password_encoding_test() {
  parse_error("postgresql://user:sec%zzret@localhost/myapp")
  |> should.equal(Error(postgres.InvalidPasswordEncoding))
}

pub fn parse_config_with_a_bad_database_encoding_returns_invalid_database_encoding_test() {
  parse_error("postgresql://localhost/my%zzapp")
  |> should.equal(Error(postgres.InvalidDatabaseEncoding))
}

pub fn parse_config_with_an_unsupported_parameter_returns_its_name_test() {
  parse_error("postgresql://localhost/myapp?sslmode=require&connect_timeout=10")
  |> should.equal(Error(postgres.UnsupportedParameter("connect_timeout")))
}

pub fn parse_config_with_an_unsupported_ssl_mode_returns_the_mode_test() {
  parse_error("postgresql://localhost/myapp?sslmode=prefer")
  |> should.equal(Error(postgres.UnsupportedSslMode("prefer")))
}

pub fn parse_config_with_a_fragment_returns_unsupported_fragment_test() {
  parse_error("postgresql://localhost/myapp#main")
  |> should.equal(Error(postgres.UnsupportedFragment))
}

pub fn parse_config_errors_never_contain_the_password_test() {
  // Arrange
  let urls = [
    "postgresql://user:hunter2@localhost:abc/myapp",
    "mysql://user:hunter2@localhost/myapp",
    "postgresql://user:hunter2@localhost:0/myapp",
    "postgresql://user:hunter2@localhost/",
    "postgresql://user:hunter2@localhost/a/b",
    "postgresql://user:hunter2%zz@localhost/myapp",
    "postgresql://user:hunter2@localhost/myapp?password=hunter2",
    "postgresql://user:hunter2@localhost/myapp?sslmode=prefer",
    "postgresql://user:hunter2@localhost/myapp#hunter2",
  ]

  // Act
  let texts = list.map(urls, inspect_error)

  // Assert
  list.filter(texts, contains_password) |> should.equal([])
  list.length(texts) |> should.equal(9)
}

fn inspect_error(url: String) -> String {
  case postgres.from_url(url) {
    Ok(_) -> "unexpected success for one of the URLs"
    Error(error) -> string.inspect(error)
  }
}

fn contains_password(text: String) -> Bool {
  string.contains(text, "hunter2")
}

// ============================================================================
// from_url
// ============================================================================

pub fn from_url_with_an_invalid_url_returns_invalid_url_test() {
  postgres.from_url("mysql://user:secret@localhost/myapp")
  |> should.equal(
    Error(postgres.InvalidUrl(postgres.UnsupportedScheme("mysql"))),
  )
}

pub fn from_url_without_a_listening_database_returns_ok_quickly_test() {
  // Arrange
  let url =
    "postgresql://user:pass@127.0.0.1:"
    <> string.inspect(free_port())
    <> "/myapp"
  let started_at = now_in_milliseconds()

  // Act
  let result = postgres.from_url(url)

  // Assert: the pool connects in the background, so the start succeeds
  let elapsed = now_in_milliseconds() - started_at
  is_ok(result) |> should.be_true()
  { elapsed < 1000 } |> should.be_true()
}

pub fn query_without_a_listening_database_returns_connection_unavailable_test() {
  // Arrange
  let url =
    "postgresql://user:pass@127.0.0.1:"
    <> string.inspect(free_port())
    <> "/myapp"
  let started_at = now_in_milliseconds()

  // Act
  let result = from_url_then_query(url)

  // Assert
  let elapsed = now_in_milliseconds() - started_at
  result |> should.equal(Ok(Error(pog.ConnectionUnavailable)))
  { elapsed < 6000 } |> should.be_true()
}

pub fn from_url_called_twice_starts_two_pools_test() {
  // Arrange
  let url =
    "postgresql://user:pass@127.0.0.1:"
    <> string.inspect(free_port())
    <> "/myapp"

  // Act
  let first = postgres.from_url(url)
  let second = postgres.from_url(url)

  // Assert
  #(is_ok(first), is_ok(second), first == second)
  |> should.equal(#(True, True, False))
}

fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Starts a pool with `from_url` and runs one query on it with a short
/// timeout. The outer `Result` is the `from_url` result; the inner one is
/// the query result.
fn from_url_then_query(
  url: String,
) -> Result(Result(pog.Returned(Nil), pog.QueryError), postgres.FromUrlError) {
  case postgres.from_url(url) {
    Error(error) -> Error(error)
    Ok(connection) -> Ok(run_select_one(connection))
  }
}

fn run_select_one(
  connection: postgres.Connection,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  pog.query("SELECT 1")
  |> pog.timeout(500)
  |> pog.execute(connection)
}
