[]{"id":1,"name":"Alice","email":"alice@example.com","created_at":"(a time)"}{"id":1,"name":"Alice","email":"alice@example.com","created_at":"(a time)"}[{"id":1,"name":"Alice","email":"alice@example.com","created_at":"(a time)"}]{"id":1,"name":"Alice","email":"alice@example.com","created_at":"(a time)"}{"id":2,"name":"Bob","email":"bob@example.com","created_at":"(a time)"}{"id":1,"name":"Alice Updated","email":"alice.updated@example.com","created_at":"(a time)"}{"id":1,"user_id":1,"title":"My First Post","content":"This is my first post!","created_at":"(a time)"}[{"id":1,"user_id":1,"title":"My First Post","content":"This is my first post!","created_at":"(a time)"}]{"message": "User deleted"}
HTTP/1.1 201 Created
content-type: application/json; charset=utf-8
content-length: 94
date: (the time of the request)
connection: keep-alive

{"id":3,"name":"Grace","email":"grace@example.com","created_at":"(a time)"}
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
content-length: 94
date: (the time of the request)
connection: keep-alive

{"id":3,"name":"Grace","email":"grace@example.com","created_at":"(a time)"}
HTTP/1.1 404 Not Found
content-type: application/json; charset=utf-8
content-length: 27
date: (the time of the request)
connection: keep-alive

{"error": "User not found"}
HTTP/1.1 400 Bad Request
content-type: application/json; charset=utf-8
content-length: 34
date: (the time of the request)
connection: keep-alive

{"error": "id must be an integer"}
HTTP/1.1 400 Bad Request
content-type: application/json; charset=utf-8
content-length: 54
date: (the time of the request)
connection: keep-alive

{"error": "Expected Field but found Nothing at email"}
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
content-length: 21
date: (the time of the request)
connection: keep-alive

{"status": "healthy"}
HTTP/1.1 409 Conflict
content-type: application/json; charset=utf-8
content-length: 32
date: (the time of the request)
connection: keep-alive

{"error": "Email already taken"}
src/context.gleam
src/context_helpers.gleam
src/controllers/health_controller.gleam
src/controllers/posts_controller.gleam
src/controllers/users_controller.gleam
src/database.gleam
src/main.gleam
src/models/post.gleam
src/models/user.gleam
src/operations/post_operations.gleam
src/operations/user_operations.gleam
src/router.gleam
src/services.gleam
src/types/errors.gleam
src/utilities/response_helpers.gleam
src/views/errors.gleam
src/views/post_view.gleam
src/views/time_text.gleam
src/views/user_view.gleam
