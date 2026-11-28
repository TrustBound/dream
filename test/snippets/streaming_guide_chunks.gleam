//// Streaming guide: chunk sizes
////
//// Streams with small and large chunks, as shown in the "Use Appropriate
//// Buffer Sizes" and "Chunk Sizing" sections of docs/guides/streaming.md.

import gleam/bit_array
import gleam/int
import gleam/yielder.{type Yielder}

// Small chunks: one line per chunk, for a real-time feel
pub fn create_line_stream() -> Yielder(BitArray) {
  yielder.range(1, 1000)
  |> yielder.map(number_to_line)
}

// Larger chunks: 100 lines per chunk, for efficiency
pub fn create_batched_line_stream() -> Yielder(BitArray) {
  create_line_stream()
  |> yielder.sized_chunk(into: 100)
  |> yielder.map(bit_array.concat)
}

fn number_to_line(number: Int) -> BitArray {
  bit_array.from_string(int.to_string(number) <> "\n")
}

// Small chunks: more responsive, more overhead
pub fn create_tiny_chunks(data: BitArray) -> Yielder(BitArray) {
  yielder.repeat(data)
  |> yielder.take(1000)
}

// Large chunks: less responsive, more efficient
pub fn group_chunks(stream: Yielder(BitArray)) -> Yielder(BitArray) {
  stream
  |> yielder.sized_chunk(into: 64)
  |> yielder.map(bit_array.concat)
}

// Chunks that follow the data: one chunk per database row
pub fn create_row_chunks(rows: List(String)) -> Yielder(BitArray) {
  yielder.from_list(rows)
  |> yielder.map(bit_array.from_string)
}
