# The Docker commands of docs/guides/deployment.md. scripts/test-docker.sh
# runs them in a copy of this folder, with the dream of the repository next
# to it.
set -eu
docker build -t your-app .
docker compose up -d --wait app
curl -f http://localhost:3000/health
started=$(date +%s)
docker compose stop app
stopped=$(date +%s)
# The VM got SIGTERM and stopped by itself: Docker gives it 10 seconds, then
# kills it with exit status 137
docker compose logs app | grep "SIGTERM received"
test "$(docker compose ps -a --format '{{.ExitCode}}' app)" = 0
test $((stopped - started)) -lt 5
echo "The app stopped in $((stopped - started)) seconds, with exit status 0."
docker compose down -v
