# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# Simple hello world
curl http://localhost:3000/

# Path parameters with external API call
curl http://localhost:3000/users/1/posts/2

# The request of docs/guides/http2.md, over plain HTTP. "echo" ends the
# line of the response above, which has no line break at its end.
echo
curl --http2-prior-knowledge -s -o /dev/null -w "%{http_version}\n" http://localhost:3000/

# The requests of docs/guides/request-data.md. "echo" ends each response,
# which has no line break at its end.
curl -i http://localhost:3000/users/42
echo
curl -i http://localhost:3000/users/abc
echo
curl -i "http://localhost:3000/search?q=gleam%20web"
echo
curl -i http://localhost:3000/search
echo
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":"Ada","email":"ada@example.com","age":36}'
echo
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":7,"age":"old"}'
echo
curl -i -X POST http://localhost:3000/signups \
  -H "Content-Type: application/json" \
  -d '{"name":'
echo
curl -i -X POST http://localhost:3000/contact \
  -d "email=ada%40example.com&topic=billing"
echo
curl -i -X POST http://localhost:3000/contact -d "topic=billing"
echo

# The requests of docs/guides/responses.md
curl -i http://localhost:3000/visits
echo
curl -i --cookie "visits=4" http://localhost:3000/visits
echo
curl -i http://localhost:3000/old-home
curl -i -X DELETE http://localhost:3000/sessions
curl -i http://localhost:3000/report.csv

# The requests of docs/guides/routing.md
curl -i -X PURGE http://localhost:3000/cache
echo
curl -i -X PURGE http://localhost:3000/missing
echo
curl -i -X DELETE http://localhost:3000/cache
echo

# The start of docs/guides/operating.md with a missing certificate. The
# HTTP/1.1 run has no build/test_tls folder, so tls_main cannot start.
cd "$EXAMPLE"
gleam run -m tls_main 2>&1 | grep "InitFailed"

# The body limit of docs/guides/operating.md: main sets max_body_size to
# 1_000_000 bytes, and this body has one byte more.
head -c 1000001 /dev/zero | tr '\0' 'a' |
  curl -i -X POST --data-binary @- http://localhost:3000/signups
echo

# The same body sent in chunks, with no content-length: the server stops
# reading when the body grows over the limit, and refuses it.
head -c 1000001 /dev/zero | tr '\0' 'a' |
  curl -i -X POST -H "transfer-encoding: chunked" --data-binary @- \
    http://localhost:3000/signups
echo

# The files of the project structure in README.md
cd "$EXAMPLE"
find src -type f | sort
find test/integration mix.exs Makefile -type f | sort

# The folders of Dream's source, as docs/contributing/contributing.md lists
# them
cd "$EXAMPLE/../.."
find src/dream -type d | sort
