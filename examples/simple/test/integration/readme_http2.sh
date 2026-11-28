# The request of docs/guides/http2.md, over HTTPS. integration/run-scenarios.sh
# runs it against the HTTPS server of the HTTP/2 run, and compares the
# output with readme_http2_output.txt.
curl -k --http2 -s -o /dev/null -w "%{http_version}\n" https://localhost:3000/
