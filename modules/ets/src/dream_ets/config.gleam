import dream_ets/encoders
import dream_ets/internal
import dream_ets/table
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/option
import gleam/result

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

pub type TableType {
  Set
  OrderedSet
  Bag
  DuplicateBag
}

pub type Access {
  Public
  Protected
  Private
}

/// Helper functions to create TableType values
pub fn table_type_set() -> TableType {
  Set
}

pub fn table_type_ordered_set() -> TableType {
  OrderedSet
}

pub fn table_type_bag() -> TableType {
  Bag
}

pub fn table_type_duplicate_bag() -> TableType {
  DuplicateBag
}

/// Helper functions to create Access values
pub fn access_public() -> Access {
  Public
}

pub fn access_protected() -> Access {
  Protected
}

pub fn access_private() -> Access {
  Private
}

/// Create a new table configuration with sensible defaults
///
/// Defaults:
/// - Table type: Set
/// - Access: Public
/// - Key position: 1
/// - Read concurrency: True
/// - Write concurrency: False
/// - Compressed: False
/// - Named table: True
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// let config = ets.new("my_table")
/// ```
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
pub fn key_string(config: TableConfig(String, v)) -> TableConfig(String, v) {
  config
  |> key(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Set string value encoding
pub fn value_string(config: TableConfig(k, String)) -> TableConfig(k, String) {
  config
  |> value(encoders.string_encoder, encoders.string_decoder())
}

/// Convenience: Configure as counter table (String keys, Int values)
pub fn counter(config: TableConfig(String, Int)) -> TableConfig(String, Int) {
  config
  |> key_string()
  |> value(encoders.int_encoder, encoders.int_decoder())
}

/// Create the table from configuration
///
/// Validates configuration and creates the ETS table.
/// Returns an error if the table name already exists or configuration is invalid.
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
    Error(_) -> Error(table.OperationFailed("Unknown error"))
  }
}
