import dream_http_client/recording
import gleam/http
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should

pub fn encode_recording_file_with_single_entry_creates_valid_json_test() {
  // Arrange
  let request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "",
    )
  let response =
    recording.BlockingResponse(
      status: 200,
      headers: [#("Content-Type", "application/json")],
      body: "{\"users\": []}",
    )
  let entry = recording.Recording(request: request, response: response)
  let file = recording.RecordingFile(version: "1.0", entries: [entry])

  // Act
  let json_value = recording.encode_recording_file(file)
  let json_string = json.to_string(json_value)

  // Assert
  string.contains(json_string, "1.0") |> should.be_true()
  string.contains(json_string, "api.example.com") |> should.be_true()
  string.contains(json_string, "GET") |> should.be_true()
}

pub fn encode_recording_file_with_streaming_response_includes_chunks_test() {
  // Arrange
  let request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/stream",
      query: option.None,
      headers: [],
      body: "",
    )
  let chunk1 = recording.Chunk(data: <<"chunk1":utf8>>, delay_ms: 50)
  let chunk2 = recording.Chunk(data: <<"chunk2":utf8>>, delay_ms: 50)
  let response =
    recording.StreamingResponse(
      status: 200,
      headers: [#("Content-Type", "text/event-stream")],
      chunks: [chunk1, chunk2],
    )
  let entry = recording.Recording(request: request, response: response)
  let file = recording.RecordingFile(version: "1.0", entries: [entry])

  // Act
  let json_value = recording.encode_recording_file(file)
  let json_string = json.to_string(json_value)

  // Assert
  string.contains(json_string, "streaming") |> should.be_true()
  string.contains(json_string, "chunk1") |> should.be_true()
  string.contains(json_string, "chunk2") |> should.be_true()
}

pub fn encode_recording_file_with_optional_fields_handles_none_test() {
  // Arrange
  let request =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Https,
      host: "api.example.com",
      port: option.None,
      path: "/users",
      query: option.None,
      headers: [],
      body: "",
    )
  let response =
    recording.BlockingResponse(status: 200, headers: [], body: "{}")
  let entry = recording.Recording(request: request, response: response)
  let file = recording.RecordingFile(version: "1.0", entries: [entry])

  // Act
  let json_value = recording.encode_recording_file(file)
  let json_string = json.to_string(json_value)

  // Assert
  string.contains(json_string, "null") |> should.be_true()
}

pub fn decode_recording_file_with_valid_json_returns_recording_file_test() {
  // Arrange
  let json_string =
    "{\"version\":\"1.0\",\"entries\":[{\"request\":{\"method\":\"GET\",\"scheme\":\"https\",\"host\":\"api.example.com\",\"port\":null,\"path\":\"/users\",\"query\":null,\"headers\":[],\"body\":\"\"},\"response\":{\"mode\":\"blocking\",\"status\":200,\"headers\":[],\"body\":\"{\\\"users\\\": []}\"}}]}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  case result {
    Ok(file) -> {
      file.version |> should.equal("1.0")
      list.length(file.entries) |> should.equal(1)
      case list.first(file.entries) {
        Ok(entry) -> {
          entry.request.host |> should.equal("api.example.com")
          entry.request.path |> should.equal("/users")
        }
        Error(_) -> {
          io.println("Expected one entry")
          should.fail()
        }
      }
    }
    Error(reason) -> {
      io.println("Expected Ok, got Error: " <> reason)
      should.fail()
    }
  }
}

pub fn decode_recording_file_with_invalid_json_returns_error_test() {
  // Arrange
  let json_string = "{invalid json}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  result |> should.be_error()
}

pub fn decode_recording_file_with_missing_fields_returns_error_test() {
  // Arrange
  let json_string = "{\"version\":\"1.0\"}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  result |> should.be_error()
}

pub fn decode_recording_file_with_streaming_response_decodes_chunks_test() {
  // Arrange
  let json_string =
    "{\"version\":\"1.0\",\"entries\":[{\"request\":{\"method\":\"GET\",\"scheme\":\"https\",\"host\":\"api.example.com\",\"port\":null,\"path\":\"/stream\",\"query\":null,\"headers\":[],\"body\":\"\"},\"response\":{\"mode\":\"streaming\",\"status\":200,\"headers\":[],\"chunks\":[{\"data\":\"chunk1\",\"delay_ms\":50},{\"data\":\"chunk2\",\"delay_ms\":50}]}}]}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  case result {
    Ok(file) -> {
      case list.first(file.entries) {
        Ok(entry) -> {
          case entry.response {
            recording.StreamingResponse(_, _, chunks) -> {
              list.length(chunks) |> should.equal(2)
            }
            recording.BlockingResponse(_, _, _) -> {
              io.println("Expected StreamingResponse")
              should.fail()
            }
          }
        }
        Error(_) -> {
          io.println("Expected one entry")
          should.fail()
        }
      }
    }
    Error(reason) -> {
      io.println("Expected Ok, got Error: " <> reason)
      should.fail()
    }
  }
}

pub fn encode_recording_file_with_empty_entries_creates_valid_json_test() {
  // Arrange
  let file = recording.RecordingFile(version: "1.0", entries: [])

  // Act
  let json_value = recording.encode_recording_file(file)
  let json_string = json.to_string(json_value)

  // Assert
  string.contains(json_string, "1.0") |> should.be_true()
  string.contains(json_string, "entries") |> should.be_true()
}

pub fn decode_recording_file_with_empty_entries_returns_empty_list_test() {
  // Arrange
  let json_string = "{\"version\":\"1.0\",\"entries\":[]}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  case result {
    Ok(file) -> {
      file.version |> should.equal("1.0")
      list.length(file.entries) |> should.equal(0)
    }
    Error(reason) -> {
      io.println("Expected Ok, got Error: " <> reason)
      should.fail()
    }
  }
}

pub fn decode_recording_file_with_invalid_version_returns_error_test() {
  // Arrange
  let json_string = "{\"version\":null,\"entries\":[]}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  result |> should.be_error()
}

pub fn decode_recording_file_with_missing_version_returns_error_test() {
  // Arrange
  let json_string = "{\"entries\":[]}"

  // Act
  let result = recording.decode_recording_file(json_string)

  // Assert
  result |> should.be_error()
}

pub fn encode_and_decode_recording_file_round_trips_correctly_test() {
  // Arrange
  let request =
    recording.RecordedRequest(
      method: http.Post,
      scheme: http.Http,
      host: "localhost",
      port: option.Some(8080),
      path: "/api/data",
      query: option.Some("key=value"),
      headers: [#("Authorization", "Bearer token")],
      body: "{\"data\": \"test\"}",
    )
  let response =
    recording.BlockingResponse(
      status: 201,
      headers: [#("Content-Type", "application/json")],
      body: "{\"id\": 123}",
    )
  let entry = recording.Recording(request: request, response: response)
  let file = recording.RecordingFile(version: "1.0", entries: [entry])

  // Act
  let json_value = recording.encode_recording_file(file)
  let json_string = json.to_string(json_value)
  let decoded_result = recording.decode_recording_file(json_string)

  // Assert
  case decoded_result {
    Ok(decoded_file) -> {
      decoded_file.version |> should.equal("1.0")
      case list.first(decoded_file.entries) {
        Ok(decoded_entry) -> {
          decoded_entry.request.method |> should.equal(http.Post)
          decoded_entry.request.scheme |> should.equal(http.Http)
          decoded_entry.request.host |> should.equal("localhost")
          case decoded_entry.request.port {
            option.Some(p) -> p |> should.equal(8080)
            option.None -> {
              io.println("Expected port")
              should.fail()
            }
          }
          case decoded_entry.request.query {
            option.Some(q) -> q |> should.equal("key=value")
            option.None -> {
              io.println("Expected query")
              should.fail()
            }
          }
          list.length(decoded_entry.request.headers) |> should.equal(1)
          decoded_entry.request.body |> should.equal("{\"data\": \"test\"}")
          case decoded_entry.response {
            recording.BlockingResponse(status, headers, body) -> {
              status |> should.equal(201)
              list.length(headers) |> should.equal(1)
              body |> should.equal("{\"id\": 123}")
            }
            recording.StreamingResponse(_, _, _) -> {
              io.println("Expected BlockingResponse")
              should.fail()
            }
          }
        }
        Error(_) -> {
          io.println("Expected one entry")
          should.fail()
        }
      }
    }
    Error(reason) -> {
      io.println("Expected Ok, got Error: " <> reason)
      should.fail()
    }
  }
}
