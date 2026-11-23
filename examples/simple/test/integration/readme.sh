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
