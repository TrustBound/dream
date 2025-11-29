import dream_http_client/recording
import dream_http_client/storage
import gleam/http
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should

@external(erlang, "erlang", "timestamp")
fn get_timestamp() -> #(Int, Int, Int)

fn create_test_recording() -> recording.Recording {
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
      headers: [],
      body: "{\"users\": []}",
    )
  recording.Recording(request: request, response: response)
}

pub fn load_recordings_with_nonexistent_file_returns_empty_list_test() {
  // Arrange
  let directory =
    "/tmp/nonexistent_recorder_test_" <> string.inspect(get_timestamp())

  // Act
  let result = storage.load_recordings(directory)

  // Assert
  case result {
    Ok(recordings) -> {
      list.length(recordings) |> should.equal(0)
    }
    Error(reason) -> {
      io.println("Unexpected error loading nonexistent directory: " <> reason)
      should.fail()
    }
  }
}

pub fn save_recordings_creates_file_and_load_recordings_loads_it_test() {
  // Arrange
  let directory = "/tmp/recorder_test_" <> string.inspect(get_timestamp())
  let test_recording = create_test_recording()

  // Act - Save
  let save_result = storage.save_recordings(directory, [test_recording])

  // Assert - Save should succeed
  case save_result {
    Ok(_) -> {
      // Act - Load
      let load_result = storage.load_recordings(directory)

      // Assert - Load should succeed and return the recording
      case load_result {
        Ok(loaded) -> {
          list.length(loaded) |> should.equal(1)
          case list.first(loaded) {
            Ok(entry) -> {
              entry.request.host |> should.equal("api.example.com")
              entry.request.path |> should.equal("/users")
            }
            Error(Nil) -> {
              io.println("Expected one recording")
              should.fail()
            }
          }
        }
        Error(reason) -> {
          io.println("Failed to load recordings after save: " <> reason)
          should.fail()
        }
      }
    }
    Error(save_reason) -> {
      io.println("Failed to save recordings: " <> save_reason)
      should.fail()
    }
  }
}

pub fn save_recordings_with_multiple_recordings_saves_all_test() {
  // Arrange
  let directory = "/tmp/recorder_test_multi_" <> string.inspect(get_timestamp())
  let recording1 = create_test_recording()
  let recording2 =
    recording.Recording(
      request: recording.RecordedRequest(
        method: http.Get,
        scheme: http.Https,
        host: "api.example.com",
        port: option.None,
        path: "/posts",
        query: option.None,
        headers: [],
        body: "",
      ),
      response: recording.BlockingResponse(
        status: 200,
        headers: [],
        body: "{\"posts\": []}",
      ),
    )

  // Act
  let save_result = storage.save_recordings(directory, [recording1, recording2])

  // Assert
  case save_result {
    Ok(_) -> {
      let load_result = storage.load_recordings(directory)
      case load_result {
        Ok(loaded) -> {
          list.length(loaded) |> should.equal(2)
        }
        Error(load_reason) -> {
          io.println("Failed to load recordings after save: " <> load_reason)
          should.fail()
        }
      }
    }
    Error(save_reason) -> {
      io.println("Failed to save multiple recordings: " <> save_reason)
      should.fail()
    }
  }
}
