# The request of the README. integration/run-scenarios.sh runs it against
# the server and compares the output with readme_output.txt.
curl http://localhost:3000

# The requests of docs/guides/getting-started.md. "echo" ends the response
# above, which has no line break at its end.
echo
curl -i http://localhost:3000/
echo
curl -i http://localhost:3000/missing
echo
curl -i -X POST http://localhost:3000/
echo

# The second start of docs/guides/operating.md: the server of the run
# already listens on port 3000.
cd "$EXAMPLE"
gleam run -m main 2>&1 | grep "InitFailed"
