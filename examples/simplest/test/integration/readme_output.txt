Hello, World!
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 13
date: (the time of the request)
connection: keep-alive

Hello, World!
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
content-length: 15
date: (the time of the request)
connection: keep-alive

Route not found
HTTP/1.1 405 Method Not Allowed
content-type: text/plain; charset=utf-8
allow: GET
content-length: 18
date: (the time of the request)
connection: keep-alive

Method not allowed
Failed to start server: InitFailed("Port 3000 already in use on localhost. Stop the process using that port or choose a different one.")
