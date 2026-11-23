# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# HTML - Full page with Pico CSS styling
curl http://localhost:3000/products/1

# JSON - API response
curl http://localhost:3000/products/1.json

# HTMX partial - Card component
curl http://localhost:3000/products/1.htmx

# CSV - Single row
curl http://localhost:3000/products/1.csv

# JSON list
curl http://localhost:3000/products.json

# Streaming CSV export
curl http://localhost:3000/products.csv
