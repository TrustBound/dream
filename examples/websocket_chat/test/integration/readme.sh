# The requests of docs/guides/websockets.md. integration/run-scenarios.sh
# runs them against the server and compares the output with
# readme_output.txt.
# A plain GET to the WebSocket route, with no Upgrade headers
curl -i "http://localhost:8080/chat?user=Ann"
echo
