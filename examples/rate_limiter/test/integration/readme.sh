# The requests of the README. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# Make multiple requests to trigger rate limiting
for i in {1..15}; do 
  echo "Request $i:"
  curl -i http://localhost:3000/api | head -5
  echo ""
done

# Public endpoint (no rate limit)
curl http://localhost:3000/

# Rate-limited endpoint
curl -i http://localhost:3000/api

# Check rate limit status
curl -i http://localhost:3000/api/status
