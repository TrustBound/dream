import dream/context.{type EmptyContext}
import dream/http/request.{type Request, Request}
import dream/http/response.{type Response, Response, Stream as ResponseStream}
import gleam/bit_array
import gleam/option.{None, Some}
import gleam/string
import gleam/yielder
import services.{type Services}

/// Middleware that converts all incoming stream chunks to uppercase
pub fn uppercase_incoming(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  case request.stream {
    Some(stream) -> {
      let transformed_stream =
        stream
        |> yielder.map(uppercase_chunk)

      let new_request = Request(..request, stream: Some(transformed_stream))
      next(new_request, context, services)
    }
    // If not a stream or empty, pass through unchanged
    None -> next(request, context, services)
  }
}

/// Middleware that replaces spaces with underscores in outgoing stream chunks
pub fn replace_space_outgoing(
  request: Request,
  context: EmptyContext,
  services: Services,
  next: fn(Request, EmptyContext, Services) -> Response,
) -> Response {
  let response = next(request, context, services)

  case response.body {
    ResponseStream(stream) -> {
      let transformed_stream =
        stream
        |> yielder.map(replace_space_chunk)

      Response(..response, body: ResponseStream(transformed_stream))
    }
    // If not a stream, pass through unchanged
    _ -> response
  }
}

fn uppercase_chunk(chunk: BitArray) -> BitArray {
  case bit_array.to_string(chunk) {
    Ok(text) -> {
      text
      |> string.uppercase
      |> bit_array.from_string
    }
    // If invalid UTF-8, pass through (or handle error)
    Error(_) -> chunk
  }
}

fn replace_space_chunk(chunk: BitArray) -> BitArray {
  case bit_array.to_string(chunk) {
    Ok(text) -> {
      text
      |> string.replace(" ", "_")
      |> bit_array.from_string
    }
    // If invalid UTF-8, pass through
    Error(_) -> chunk
  }
}
