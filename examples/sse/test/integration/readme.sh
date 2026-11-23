# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
curl -N http://localhost:8081/events | head -n 6
