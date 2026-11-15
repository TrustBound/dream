import dream/http/response.{type ResponseBody, Bytes, Stream, Text}
import gleam/json
import gleam/yielder.{type Yielder}

pub fn response_bodies(
  data: json.Json,
  image_data: BitArray,
  file_chunks: Yielder(BitArray),
) -> List(ResponseBody) {
  [
    // Text responses (most common)
    Text("Hello, World!"),
    Text(json.to_string(data)),
    // Binary response
    Bytes(image_data),
    // Streaming response
    Stream(file_chunks),
  ]
}
