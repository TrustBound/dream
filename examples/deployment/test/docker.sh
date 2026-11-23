# The Docker commands of docs/guides/deployment.md. scripts/test-docker.sh
# runs them in a copy of this folder, with the dream of the repository next
# to it.
set -eu
docker build -t your-app .
docker compose up -d --wait app
curl -f http://localhost:3000/health
docker compose down -v
