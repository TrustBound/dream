//// Table configuration and builder pattern
////
//// This module provides the builder pattern for creating ETS tables with
//// type-safe configuration. Use this module to create tables with custom
//// settings for concurrency, access control, and data types.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_ets/config
////
//// // Create a simple string-to-string table
//// let assert Ok(table) = config.new("users")
////   |> config.key_string()
////   |> config.value_string()
////   |> config.create()
////
//// // Create a counter table (String keys, Int values)
//// let assert Ok(counter) = config.new("page_views")
////   |> config.counter()
////   |> config.create()
////
//// // Create with custom configuration
//// let assert Ok(table) = config.new("cache")
////   |> config.table_type(config.table_type_set())
////   |> config.access(config.access_public())
////   |> config.read_concurrency(True)
////   |> config.write_concurrency(False)
////   |> config.key_string()
////   |> config.value_string()
////   |> config.create()
//// ```
////
//// ## Builder Pattern
////
//// The configuration follows the builder pattern:
////
//// 1. Start with `new(name)` to create a config
//// 2. Chain configuration methods to customize settings
//// 3. Specify key and value encoders (required)
//// 4. Call `create()` to build the table
////
//// ## Type Safety
////
//// Tables are parameterized by key and value types. The type system
//// ensures you cannot insert wrong types into a table.

import dream_ets/encoders
import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/option
import gleam/result

/// Table configuration builder
///
/// Opaque type that holds all configuration for creating an ETS table.
/// Use the builder methods to configure the table before calling `create()`.
///
/// ## Type Parameters
///
/// - `key`: The type of keys that will be stored in the table
/// - `value`: The type of values that will be stored in the table
pub opaque type TableConfig(key, value) {
  TableConfig(
    name: String,
    table_type: TableType,
    access: Access,
    keypos: Int,
    read_concurrency: Bool,
    write_concurrency: Bool,
    compressed: Bool,
    named_table: Bool,
    key_encoder: option.Option(fn(key) -> dynamic.Dynamic),
    key_decoder: option.Option(decode.Decoder(key)),
    value_encoder: option.Option(fn(value) -> dynamic.Dynamic),
    value_decoder: option.Option(decode.Decoder(value)),
  )
}

/// Table type for ETS tables
///
/// Determines how the table handles duplicate keys and ordering.
///
/// ## Variants
///
/// - `Set`: Keys are unique, no ordering guarantees. **Default and recommended.**
/// - `OrderedSet`: Keys are unique and sorted. Slower inserts but ordered iteration.
/// - `Bag`: Keys can have multiple values, order not preserved.
/// - `DuplicateBag`: Keys can have multiple identical values.
///
/// **Note:** Most applications should use `Set` (the default). Only use other
/// types if you have specific requirements for ordering or duplicate values.
pub type TableType {
  Set
  OrderedSet
  Bag
  DuplicateBag
}

/// Access control for ETS tables
///
/// Determines which processes can read and write to the table.
///
/// ## Variants
///
/// - `Public`: Any process can read and write. **Recommended for most cases.**
/// - `Protected`: Owner can write, any process can read. Use for read-heavy workloads.
/// - `Private`: Only the owner process can read and write. Rarely needed.
///
/// **Note:** In Dream applications, `Public` is usually the right choice since
/// the table typically outlives individual request processes.
pub type Access {
  Public
  Protected
  Private
}

/// Create a Set table type
///
/// Returns a `Set` table type, which is the default and recommended type for
/// most use cases. Keys are unique and insertion/lookup is fast.
///
/// ## Returns
///
/// A `Set` table type.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let table = config.new("cache")
///   |> config.table_type(config.table_type_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
pub fn table_type_set() -> TableType {
  Set
}

/// Create an OrderedSet table type
///
/// Returns an `OrderedSet` table type. Keys are unique and maintained in
/// sorted order. Use this when you need ordered iteration, but note that
/// insertions are slower than `Set`.
///
/// ## Returns
///
/// An `OrderedSet` table type.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Useful for leaderboards or sorted data
/// let table = config.new("leaderboard")
///   |> config.table_type(config.table_type_ordered_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
pub fn table_type_ordered_set() -> TableType {
  OrderedSet
}

/// Create a Bag table type
///
/// Returns a `Bag` table type. A key can have multiple different values.
/// This is rarely needed in most applications.
///
/// ## Returns
///
/// A `Bag` table type.
pub fn table_type_bag() -> TableType {
  Bag
}

/// Create a DuplicateBag table type
///
/// Returns a `DuplicateBag` table type. A key can have multiple identical
/// values. This is rarely needed in most applications.
///
/// ## Returns
///
/// A `DuplicateBag` table type.
pub fn table_type_duplicate_bag() -> TableType {
  DuplicateBag
}

/// Create Public access mode
///
/// Returns `Public` access, allowing any process to read and write to the
/// table. **This is the recommended default** for most applications.
///
/// ## Returns
///
/// A `Public` access mode.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let table = config.new("sessions")
///   |> config.access(config.access_public())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
pub fn access_public() -> Access {
  Public
}

/// Create Protected access mode
///
/// Returns `Protected` access. Only the owner process can write, but any
/// process can read. Use this for read-heavy workloads where you want to
/// control writes.
///
/// ## Returns
///
/// A `Protected` access mode.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Useful for configuration that rarely changes
/// let table = config.new("config")
///   |> config.access(config.access_protected())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
pub fn access_protected() -> Access {
  Protected
}

/// Create Private access mode
///
/// Returns `Private` access. Only the owner process can read and write.
/// This is rarely needed in most applications.
///
/// ## Returns
///
/// A `Private` access mode.
pub fn access_private() -> Access {
  Private
}

/// Create a new table configuration with sensible defaults
///
/// This is the starting point for the builder pattern. After calling `new()`,
/// you must chain methods to specify key and value encoders, then call `create()`
/// to build the table.
///
/// ## Defaults
///
/// - **Table type**: `Set` - Keys are unique, fast operations
/// - **Access**: `Public` - Any process can read/write
/// - **Key position**: 1 (for tuple-based tables)
/// - **Read concurrency**: `False` - Enable with `read_concurrency(True)` if needed
/// - **Write concurrency**: `False` - Enable with `write_concurrency(True)` if needed
/// - **Compressed**: `False` - Can reduce memory for large values
/// - **Named table**: `True` - Table is registered by name
///
/// ## Parameters
///
/// - `name`: A unique name for the table. Must be unique across the application.
///
/// ## Returns
///
/// A new `TableConfig` with default settings. You must set key and value
/// encoders before calling `create()`.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(table) = config.new("users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `create()` - Create the table after configuration
/// - `key_string()` - Set string keys
/// - `value_string()` - Set string values
pub fn new(name: String) -> TableConfig(k, v) {
  TableConfig(
    name: name,
    table_type: Set,
    access: Public,
    keypos: 1,
    read_concurrency: False,
    write_concurrency: False,
    compressed: False,
    named_table: True,
    key_encoder: option.None,
    key_decoder: option.None,
    value_encoder: option.None,
    value_decoder: option.None,
  )
}

/// Set the table type
///
/// Configures how the table handles keys and ordering. The default is `Set`,
/// which is appropriate for most use cases.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `type_`: The table type to use (Set, OrderedSet, Bag, or DuplicateBag)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(table) = config.new("sorted_cache")
///   |> config.table_type(config.table_type_ordered_set())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## Performance Notes
///
/// - `Set`: Fastest for most operations (default)
/// - `OrderedSet`: Slower insertions but supports ordered iteration
/// - `Bag` / `DuplicateBag`: Rarely needed, use only for specific use cases
pub fn table_type(
  config: TableConfig(k, v),
  type_: TableType,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    _,
    access,
    keypos,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: type_,
    access: access,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set the access mode
///
/// Controls which processes can read and write to the table. The default is
/// `Public`, which allows any process to access the table.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `access_mode`: The access mode (Public, Protected, or Private)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Protected: only owner can write, anyone can read
/// let assert Ok(table) = config.new("config_cache")
///   |> config.access(config.access_protected())
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## Access Modes
///
/// - **Public**: Any process can read/write (recommended)
/// - **Protected**: Owner writes, anyone reads
/// - **Private**: Only owner can read/write (rarely needed)
pub fn access(
  config: TableConfig(k, v),
  access_mode: Access,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    _,
    keypos,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access_mode,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set the key position in tuples (default: 1)
///
/// Configures which element of a tuple to use as the key. This is an advanced
/// feature for tuple-based tables. **Most users will never need this.**
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `pos`: The 1-based position of the key in tuples (default: 1)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Note
///
/// This is only relevant when storing tuples directly in ETS. For typed
/// tables using encoders/decoders (the recommended approach), this setting
/// is handled automatically.
pub fn keypos(config: TableConfig(k, v), pos: Int) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    _,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: pos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable read concurrency
///
/// Optimizes the table for concurrent read operations. Enable this if
/// multiple processes will be reading from the table simultaneously.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable read concurrency, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Optimize for many simultaneous readers
/// let assert Ok(table) = config.new("user_cache")
///   |> config.read_concurrency(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## When to Use
///
/// - **Enable**: High read traffic from multiple processes
/// - **Disable**: Single-threaded access or write-heavy workloads
///
/// ## Performance Impact
///
/// - **Pro**: Significantly improves concurrent read performance
/// - **Con**: Slightly increases memory usage and write overhead
pub fn read_concurrency(
  config: TableConfig(k, v),
  enabled: Bool,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    keypos,
    _,
    write_concurrency,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: keypos,
    read_concurrency: enabled,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable write concurrency
///
/// Optimizes the table for concurrent write operations. Enable this if
/// multiple processes will be writing to the table simultaneously.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable write concurrency, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Optimize for many simultaneous writers
/// let assert Ok(table) = config.new("metrics")
///   |> config.write_concurrency(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## When to Use
///
/// - **Enable**: High write traffic from multiple processes
/// - **Disable**: Single-threaded access or read-heavy workloads
///
/// ## Performance Impact
///
/// - **Pro**: Improves concurrent write performance
/// - **Con**: May increase memory usage slightly
///
/// ## Note
///
/// Write concurrency uses fine-grained locking. Best results when keys
/// are well-distributed across the keyspace.
pub fn write_concurrency(
  config: TableConfig(k, v),
  enabled: Bool,
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    keypos,
    read_concurrency,
    _,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: enabled,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Enable or disable table compression
///
/// Compresses table data to reduce memory usage. This trades CPU time for
/// memory space. Only consider this for tables with large values.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `enabled`: `True` to enable compression, `False` to disable (default)
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Compress large JSON values
/// let assert Ok(table) = config.new("documents")
///   |> config.compressed(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## When to Use
///
/// - **Enable**: Storing large values (e.g., JSON documents, HTML)
/// - **Disable**: Small values or performance-critical code (default)
///
/// ## Trade-offs
///
/// - **Pro**: Reduces memory usage (especially for large, compressible data)
/// - **Con**: Slower read/write operations due to compression overhead
/// - **Note**: Only worth it if values are large and compressible
pub fn compressed(config: TableConfig(k, v), enabled: Bool) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    keypos,
    read_concurrency,
    write_concurrency,
    _,
    named_table,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: enabled,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set key encoder and decoder
///
/// Configures custom encoding/decoding functions for keys. This is required
/// for creating a table - you must specify how to convert keys to/from
/// Erlang's dynamic types.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `encoder`: Function to convert keys to `Dynamic` for storage
/// - `decoder`: Decoder to convert `Dynamic` back to keys
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
/// import gleam/dynamic
///
/// // Using built-in encoders
/// let assert Ok(table) = config.new("users")
///   |> config.key(encoders.string_encoder, encoders.string_decoder())
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## Custom Encoders
///
/// For custom types, provide your own encoder/decoder:
///
/// ```gleam
/// import gleam/dynamic/decode
///
/// pub type UserId {
///   UserId(Int)
/// }
///
/// fn encode_user_id(id: UserId) -> dynamic.Dynamic {
///   let UserId(n) = id
///   dynamic.from(n)
/// }
///
/// fn decode_user_id() -> decode.Decoder(UserId) {
///   decode.int |> decode.map(UserId)
/// }
///
/// let assert Ok(table) = config.new("users")
///   |> config.key(encode_user_id, decode_user_id())
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `key_string()` - Convenience function for string keys
/// - `value()` - Set value encoder/decoder
pub fn key(
  config: TableConfig(k, v),
  encoder: fn(k) -> dynamic.Dynamic,
  decoder: decode.Decoder(k),
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    keypos,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    _,
    _,
    value_encoder,
    value_decoder,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: option.Some(encoder),
    key_decoder: option.Some(decoder),
    value_encoder: value_encoder,
    value_decoder: value_decoder,
  )
}

/// Set value encoder and decoder
///
/// Configures custom encoding/decoding functions for values. This is required
/// for creating a table - you must specify how to convert values to/from
/// Erlang's dynamic types.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
/// - `encoder`: Function to convert values to `Dynamic` for storage
/// - `decoder`: Decoder to convert `Dynamic` back to values
///
/// ## Returns
///
/// The updated configuration.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/encoders
///
/// // Using built-in encoders
/// let assert Ok(table) = config.new("cache")
///   |> config.key_string()
///   |> config.value(encoders.string_encoder, encoders.string_decoder())
///   |> config.create()
/// ```
///
/// ## Custom Encoders
///
/// For custom types like JSON or complex structures:
///
/// ```gleam
/// import gleam/json
/// import gleam/dynamic/decode
///
/// pub type User {
///   User(name: String, age: Int)
/// }
///
/// fn encode_user(user: User) -> dynamic.Dynamic {
///   json.object([
///     #("name", json.string(user.name)),
///     #("age", json.int(user.age)),
///   ])
///   |> json.to_string
///   |> dynamic.from
/// }
///
/// fn decode_user() -> decode.Decoder(User) {
///   decode.string
///   |> decode.then(fn(str) {
///     // Parse JSON and decode User...
///   })
/// }
/// ```
///
/// ## See Also
///
/// - `value_string()` - Convenience function for string values
/// - `key()` - Set key encoder/decoder
pub fn value(
  config: TableConfig(k, v),
  encoder: fn(v) -> dynamic.Dynamic,
  decoder: decode.Decoder(v),
) -> TableConfig(k, v) {
  let TableConfig(
    name,
    table_type,
    access,
    keypos,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    key_encoder,
    key_decoder,
    _,
    _,
  ) = config

  TableConfig(
    name: name,
    table_type: table_type,
    access: access,
    keypos: keypos,
    read_concurrency: read_concurrency,
    write_concurrency: write_concurrency,
    compressed: compressed,
    named_table: named_table,
    key_encoder: key_encoder,
    key_decoder: key_decoder,
    value_encoder: option.Some(encoder),
    value_decoder: option.Some(decoder),
  )
}

/// Convenience: Set string key encoding
///
/// Configures the table to use string keys. This is a convenience function
/// that calls `key()` with built-in string encoders.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration with string key encoding.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(table) = config.new("users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `key()` - For custom key types
/// - `value_string()` - For string values
pub fn key_string(config: TableConfig(String, v)) -> TableConfig(String, v) {
  config
  |> key(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Set string value encoding
///
/// Configures the table to use string values. This is a convenience function
/// that calls `value()` with built-in string encoders.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration with string value encoding.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// let assert Ok(table) = config.new("cache")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## See Also
///
/// - `value()` - For custom value types
/// - `key_string()` - For string keys
pub fn value_string(config: TableConfig(k, String)) -> TableConfig(k, String) {
  config
  |> value(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Configure as counter table (String keys, Int values)
///
/// Configures the table for use as a counter with string keys and integer
/// values. This is a convenience function that sets both key and value
/// encoders appropriately.
///
/// ## Parameters
///
/// - `config`: The table configuration to modify
///
/// ## Returns
///
/// The updated configuration ready for use as a counter.
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
/// import dream_ets/helpers
///
/// // Create a counter table
/// let assert Ok(counter) = config.new("page_views")
///   |> config.counter()
///   |> config.create()
///
/// // Use with increment helpers
/// let assert Ok(count) = helpers.increment(counter, "homepage")
/// ```
///
/// ## See Also
///
/// - `helpers.new_counter()` - Even simpler counter creation
/// - `helpers.increment()` - Increment counter values
/// - `helpers.decrement()` - Decrement counter values
pub fn counter(config: TableConfig(String, Int)) -> TableConfig(String, Int) {
  config
  |> key_string()
  |> value(encoders.int_encoder, encoders.int_decoder())
}

/// Create the table from configuration
///
/// Validates the configuration and creates the ETS table. This is the final
/// step in the builder pattern - it actually creates the table in memory.
///
/// ## Parameters
///
/// - `config`: The table configuration with all settings applied
///
/// ## Returns
///
/// - `Ok(Table)`: Successfully created table
/// - `Error(TableAlreadyExists)`: A table with this name already exists
/// - `Error(InvalidKey)`: Key encoder/decoder not set
/// - `Error(InvalidValue)`: Value encoder/decoder not set
/// - `Error(OperationFailed)`: ETS creation failed
///
/// ## Example
///
/// ```gleam
/// import dream_ets/config
///
/// // Create a simple table
/// let assert Ok(table) = config.new("users")
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
///
/// // Create with custom settings
/// let assert Ok(table) = config.new("cache")
///   |> config.read_concurrency(True)
///   |> config.write_concurrency(True)
///   |> config.key_string()
///   |> config.value_string()
///   |> config.create()
/// ```
///
/// ## Errors
///
/// This function will return an error if:
///
/// 1. A table with the same name already exists
/// 2. Key encoder/decoder was not configured
/// 3. Value encoder/decoder was not configured
/// 4. ETS table creation fails for any reason
///
/// ## See Also
///
/// - `new()` - Start the builder
/// - `key_string()` / `value_string()` - Common encoder shortcuts
pub fn create(
  config: TableConfig(k, v),
) -> Result(table.Table(k, v), table.EtsError) {
  use validated_config <- result.try(validate_config(config))
  use options <- result.try(build_ets_options(validated_config))
  create_table_with_options(validated_config, options)
}

// Private helper functions

fn validate_config(
  config: TableConfig(k, v),
) -> Result(TableConfig(k, v), table.EtsError) {
  let TableConfig(
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    key_encoder,
    _key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  case key_encoder {
    option.None -> Error(table.InvalidKey)
    option.Some(_) ->
      validate_value_encoding(config, value_encoder, value_decoder)
  }
}

fn validate_value_encoding(
  config: TableConfig(k, v),
  value_encoder: option.Option(fn(v) -> dynamic.Dynamic),
  _value_decoder: option.Option(decode.Decoder(v)),
) -> Result(TableConfig(k, v), table.EtsError) {
  case value_encoder {
    option.None -> Error(table.InvalidValue)
    option.Some(_) -> Ok(config)
  }
}

fn build_ets_options(
  config: TableConfig(k, v),
) -> Result(List(dynamic.Dynamic), table.EtsError) {
  let TableConfig(
    _,
    table_type,
    access,
    keypos,
    read_concurrency,
    write_concurrency,
    compressed,
    named_table,
    _,
    _,
    _,
    _,
  ) = config

  let type_option = table_type_to_atom(table_type)
  let access_option = access_to_atom(access)
  let base_options = [type_option, access_option]

  let options_with_read =
    add_read_concurrency_option(read_concurrency, base_options)
  let options_with_write =
    add_write_concurrency_option(write_concurrency, options_with_read)
  let options_with_compressed =
    add_compressed_option(compressed, options_with_write)
  let options_with_named =
    add_named_table_option(named_table, options_with_compressed)
  let final_options = add_keypos_option(keypos, options_with_named)

  Ok(final_options)
}

fn table_type_to_atom(table_type: TableType) -> dynamic.Dynamic {
  case table_type {
    Set -> atom.create("set") |> atom_to_dynamic
    OrderedSet -> atom.create("ordered_set") |> atom_to_dynamic
    Bag -> atom.create("bag") |> atom_to_dynamic
    DuplicateBag -> atom.create("duplicate_bag") |> atom_to_dynamic
  }
}

fn access_to_atom(access: Access) -> dynamic.Dynamic {
  case access {
    Public -> atom.create("public") |> atom_to_dynamic
    Protected -> atom.create("protected") |> atom_to_dynamic
    Private -> atom.create("private") |> atom_to_dynamic
  }
}

fn add_read_concurrency_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [create_concurrency_tuple("read_concurrency", True), ..options]
    False -> options
  }
}

fn add_write_concurrency_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [create_concurrency_tuple("write_concurrency", True), ..options]
    False -> options
  }
}

fn add_compressed_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [atom.create("compressed") |> atom_to_dynamic, ..options]
    False -> options
  }
}

fn add_named_table_option(
  enabled: Bool,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case enabled {
    True -> [atom.create("named_table") |> atom_to_dynamic, ..options]
    False -> options
  }
}

fn add_keypos_option(
  pos: Int,
  options: List(dynamic.Dynamic),
) -> List(dynamic.Dynamic) {
  case pos {
    1 -> options
    n -> [create_keypos_tuple(n), ..options]
  }
}

fn create_concurrency_tuple(option_name: String, value: Bool) -> dynamic.Dynamic {
  let key_atom = atom.create(option_name)
  internal.to_dynamic(#(key_atom, value))
}

fn create_keypos_tuple(pos: Int) -> dynamic.Dynamic {
  let key_atom = atom.create("keypos")
  internal.to_dynamic(#(key_atom, pos))
}

fn atom_to_dynamic(a: atom.Atom) -> dynamic.Dynamic {
  internal.to_dynamic(a)
}

fn create_table_with_options(
  config: TableConfig(k, v),
  options: List(dynamic.Dynamic),
) -> Result(table.Table(k, v), table.EtsError) {
  let TableConfig(
    name,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    key_encoder,
    key_decoder,
    value_encoder,
    value_decoder,
  ) = config

  let assert option.Some(encoder_k) = key_encoder
  let assert option.Some(decoder_k) = key_decoder
  let assert option.Some(encoder_v) = value_encoder
  let assert option.Some(decoder_v) = value_decoder

  case internal.new_table(name, options) {
    Ok(table_ref) -> {
      Ok(table.new_table(
        table_ref,
        name,
        encoder_k,
        decoder_k,
        encoder_v,
        decoder_v,
      ))
    }
    Error(internal.AlreadyExists) -> Error(table.TableAlreadyExists)
    Error(internal.InvalidOperation(msg)) -> Error(table.OperationFailed(msg))
    Error(internal.NotFound) -> Error(table.TableNotFound)
    Error(internal.EmptyTable) -> Error(table.EmptyTable)
    Error(internal.EndOfTable) -> Error(table.EndOfTable)
  }
}
