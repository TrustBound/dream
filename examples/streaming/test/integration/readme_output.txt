Streaming Example Server

Routes:
  GET /stream - Stream a response from httpbin.org
  GET /fetch - Fetch and return a response from httpbin.org
Fetched response:

{"message":"Hello, World!","success":true}Streaming response:

Chunk 1
Chunk 2
Chunk 3
Chunk 4
Chunk 5
Chunk 6
Chunk 7
Chunk 8
Chunk 9
Chunk 10
src/controllers/stream_controller.gleam
src/main.gleam
src/router.gleam
src/services.gleam
src/views/stream_view.gleam
