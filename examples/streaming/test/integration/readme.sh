# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# Info page
curl http://localhost:3003/

# Non-streaming request (waits for full response)
curl http://localhost:3003/fetch

# Streaming request (processes chunks as they arrive)
curl http://localhost:3003/stream
