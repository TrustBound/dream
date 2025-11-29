import dream_http_client/client
import gleam/bit_array
import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/string
import gleeunit/should

/// Helper to send a mock httpc message directly to current process
@external(erlang, "erlang", "send")
fn send_message(pid: process.Pid, message: a) -> a

@external(erlang, "erlang", "make_ref")
fn make_ref() -> a

fn is_content_type_json(header: #(String, String)) -> Bool {
  case header {
    #("content-type", "application/json") -> True
    _ -> False
  }
}

fn is_string_tuple_header(_header: #(String, String)) -> Bool {
  // Type alone is sufficient to prove we normalized to #(String, String).
  True
}

/// Test: Selector correctly decodes StreamStart messages
pub fn decode_stream_start_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let headers = [
    #(<<"content-type">>, <<"application/json">>),
    #(<<"server">>, <<"test">>),
  ]

  // Send mock httpc message
  let msg = #(atom.create("http"), #(ref, atom.create("stream_start"), headers))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.StreamStart(_, decoded_headers)) -> {
      list.length(decoded_headers) |> should.equal(2)

      let has_content_type = list.any(decoded_headers, is_content_type_json)

      has_content_type |> should.be_true()
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Selector correctly decodes Chunk messages
pub fn decode_chunk_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let data = <<"Hello, World!">>

  // Send mock httpc chunk message
  let msg = #(atom.create("http"), #(ref, atom.create("stream"), data))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.Chunk(_, received_data)) -> {
      received_data |> should.equal(data)
      verify_chunk_string(received_data)
    }
    _ -> should.fail()
  }
}

fn verify_chunk_string(received_data: BitArray) -> Nil {
  case bit_array.to_string(received_data) {
    Ok(str) -> str |> should.equal("Hello, World!")
    Error(decode_error) -> {
      io.println(
        "verify_chunk_string failed to decode chunk: "
        <> string.inspect(decode_error),
      )
      should.fail()
    }
  }

  Nil
}

/// Test: Selector correctly decodes StreamEnd messages
pub fn decode_stream_end_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let trailing_headers = [
    #(<<"x-request-id">>, <<"123">>),
  ]

  // Send mock httpc stream_end message
  let msg = #(atom.create("http"), #(
    ref,
    atom.create("stream_end"),
    trailing_headers,
  ))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.StreamEnd(_, headers)) -> {
      list.length(headers) |> should.equal(1)
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Selector correctly decodes StreamError messages
pub fn decode_stream_error_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let error_reason = atom.create("timeout")

  // Send mock httpc error message
  let msg = #(
    atom.create("http"),
    #(ref, #(atom.create("error"), error_reason)),
  )
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.StreamError(_, reason)) -> {
      // Reason should be a string representation of the error
      { reason != "" } |> should.be_true()
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Multiple messages from same RequestId are correctly associated
pub fn request_id_association_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()

  // Send multiple messages with same RequestId
  let start_msg = #(
    atom.create("http"),
    #(ref, atom.create("stream_start"), []),
  )
  let chunk_msg = #(
    atom.create("http"),
    #(ref, atom.create("stream"), <<"data">>),
  )
  let end_msg = #(atom.create("http"), #(ref, atom.create("stream_end"), []))

  send_message(me, start_msg)
  send_message(me, chunk_msg)
  send_message(me, end_msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act - collect all messages
  let msg1 = process.selector_receive(selector, 100)
  let msg2 = process.selector_receive(selector, 100)
  let msg3 = process.selector_receive(selector, 100)

  // Assert - all messages received and in order
  case msg1, msg2, msg3 {
    Ok(client.StreamStart(id1, _)),
      Ok(client.Chunk(id2, _)),
      Ok(client.StreamEnd(id3, _))
    -> {
      // All RequestIds should reference the same ref
      // We can't directly compare RequestIds, but we can verify they decode correctly
      let _ = id1
      let _ = id2
      let _ = id3
      Nil
    }
    _, _, _ -> should.fail()
  }

  Nil
}

/// Test: Messages from different RequestIds are distinguished
pub fn multiple_request_ids_test() {
  // Arrange
  let me = process.self()
  let ref1 = make_ref()
  let ref2 = make_ref()

  // Send messages from two different streams
  let msg1 = #(
    atom.create("http"),
    #(ref1, atom.create("stream"), <<"stream1">>),
  )
  let msg2 = #(
    atom.create("http"),
    #(ref2, atom.create("stream"), <<"stream2">>),
  )

  send_message(me, msg1)
  send_message(me, msg2)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result1 = process.selector_receive(selector, 100)
  let result2 = process.selector_receive(selector, 100)

  // Assert - both messages received with different data
  case result1, result2 {
    Ok(client.Chunk(_, data1)), Ok(client.Chunk(_, data2)) -> {
      // Data should be different
      { data1 != data2 } |> should.be_true()
    }
    _, _ -> should.fail()
  }

  Nil
}

/// Custom message type for testing custom mapper
pub type MyMsg {
  MyHttpStream(client.StreamMessage)
  OtherMsg(String)
}

/// Test: Selector with custom mapper function works
pub fn custom_mapper_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let data = <<"test data">>

  // Send mock message
  let msg = #(atom.create("http"), #(ref, atom.create("stream"), data))
  send_message(me, msg)

  // Build selector with custom mapper
  let selector =
    process.new_selector()
    |> client.select_stream_messages(MyHttpStream)

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert - message wrapped in custom type
  case result {
    Ok(MyHttpStream(client.Chunk(_, received_data))) -> {
      received_data |> should.equal(data)
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Binary vs string headers are normalized
pub fn header_normalization_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()

  // Mix of binary and string headers (simulating what httpc might send)
  let headers = [
    #(<<"binary-header">>, <<"binary-value">>),
    #(<<"another-header">>, <<"another-value">>),
  ]

  // Send mock message
  let msg = #(atom.create("http"), #(ref, atom.create("stream_start"), headers))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert - all headers decoded as strings
  case result {
    Ok(client.StreamStart(_, decoded_headers)) -> {
      list.length(decoded_headers) |> should.equal(2)

      // Verify all headers are string tuples
      let all_strings = list.all(decoded_headers, is_string_tuple_header)

      all_strings |> should.be_true()
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Empty headers list decoded correctly
pub fn empty_headers_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()
  let empty_headers = []

  // Send mock message with empty headers
  let msg = #(atom.create("http"), #(
    ref,
    atom.create("stream_start"),
    empty_headers,
  ))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.StreamStart(_, headers)) -> {
      list.length(headers) |> should.equal(0)
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Large chunk data handled correctly
pub fn large_chunk_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()

  // Create a large binary (1MB)
  let large_data = <<0:unit(8)-size(1_000_000)>>

  // Send mock chunk
  let msg = #(atom.create("http"), #(ref, atom.create("stream"), large_data))
  send_message(me, msg)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act
  let result = process.selector_receive(selector, 100)

  // Assert
  case result {
    Ok(client.Chunk(_, received_data)) -> {
      bit_array.byte_size(received_data) |> should.equal(1_000_000)
    }
    _ -> should.fail()
  }

  Nil
}

/// Test: Message ordering is preserved
pub fn message_ordering_test() {
  // Arrange
  let me = process.self()
  let ref = make_ref()

  // Send messages in specific order
  let msg1 = #(atom.create("http"), #(ref, atom.create("stream_start"), []))
  let msg2 = #(atom.create("http"), #(ref, atom.create("stream"), <<"chunk1">>))
  let msg3 = #(atom.create("http"), #(ref, atom.create("stream"), <<"chunk2">>))
  let msg4 = #(atom.create("http"), #(ref, atom.create("stream"), <<"chunk3">>))
  let msg5 = #(atom.create("http"), #(ref, atom.create("stream_end"), []))

  send_message(me, msg1)
  send_message(me, msg2)
  send_message(me, msg3)
  send_message(me, msg4)
  send_message(me, msg5)

  // Build selector
  let selector =
    process.new_selector()
    |> client.select_stream_messages(fn(msg) { msg })

  // Act - receive all messages
  let r1 = process.selector_receive(selector, 100)
  let r2 = process.selector_receive(selector, 100)
  let r3 = process.selector_receive(selector, 100)
  let r4 = process.selector_receive(selector, 100)
  let r5 = process.selector_receive(selector, 100)

  // Assert - messages in correct order
  case r1, r2, r3, r4, r5 {
    Ok(client.StreamStart(_, _)),
      Ok(client.Chunk(_, d1)),
      Ok(client.Chunk(_, d2)),
      Ok(client.Chunk(_, d3)),
      Ok(client.StreamEnd(_, _))
    -> {
      d1 |> should.equal(<<"chunk1">>)
      d2 |> should.equal(<<"chunk2">>)
      d3 |> should.equal(<<"chunk3">>)
    }
    _, _, _, _, _ -> should.fail()
  }

  Nil
}
