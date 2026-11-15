//// Streaming API reference: yielder operations on streams
////
//// Common ways to transform, filter, count, limit and join streams.

import gleam/bit_array
import gleam/yielder.{type Yielder}

pub fn uppercase_stream(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.map(uppercase_chunk)
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  uppercase_bytes(chunk, <<>>)
}

fn uppercase_bytes(remaining: BitArray, uppercased: BitArray) -> BitArray {
  case remaining {
    <<byte, rest:bytes>> ->
      uppercase_bytes(rest, <<uppercased:bits, uppercase_byte(byte)>>)
    _ -> uppercased
  }
}

// Only the ASCII letters a to z change. Every byte of a multi-byte UTF-8
// character is 128 or more, so a character split across two chunks is kept.
fn uppercase_byte(byte: Int) -> Int {
  case byte >= 97 && byte <= 122 {
    True -> byte - 32
    False -> byte
  }
}

pub fn remove_empty_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.filter(is_non_empty_chunk)
}

fn is_non_empty_chunk(chunk: BitArray) -> Bool {
  bit_array.byte_size(chunk) > 0
}

pub fn count_total_bytes(stream: Yielder(BitArray)) -> Int {
  stream
  |> yielder.fold(0, add_chunk_size)
}

fn add_chunk_size(total: Int, chunk: BitArray) -> Int {
  total + bit_array.byte_size(chunk)
}

pub fn take_first_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.take(100)
}

pub fn create_csv_stream(names: List(String)) -> Yielder(BitArray) {
  let header = yielder.single(<<"name\n":utf8>>)
  let rows =
    yielder.from_list(names)
    |> yielder.map(to_csv_row)

  yielder.append(header, rows)
}

fn to_csv_row(name: String) -> BitArray {
  bit_array.from_string(name <> "\n")
}
