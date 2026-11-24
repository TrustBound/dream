#!/bin/sh
# Builds the Docker image of examples/deployment, starts it with Docker
# Compose (PostgreSQL, the migrations and the app), asks the app for /health
# and stops everything: the commands of examples/deployment/test/docker.sh.
# At the end it removes the containers, the volume and the images that the
# run built (your-app, and the app and migrate images of Compose). It keeps
# the images that it pulled (the Gleam image and postgres:16-alpine).
# "make test-docker" runs this script. Needs Docker with Compose v2, and the
# port 3000 free.
#
# The example depends on the dream of this repository (path = "../.."), and
# a Docker build sees only its context folder. So the script runs the
# commands in a copy of the example, with the repository's dream in it at
# dream/, and points the path dependency there.
set -eu
CONTEXT=$(mktemp -d)
trap 'cd "$CONTEXT" && docker compose down -v --rmi local > /dev/null 2>&1; docker image rm your-app > /dev/null 2>&1; rm -r "$CONTEXT"' EXIT

cp -R examples/deployment/. "$CONTEXT/"
mkdir "$CONTEXT/dream"
cp -R gleam.toml manifest.toml src "$CONTEXT/dream/"
sed 's#path = "../.."#path = "dream"#' examples/deployment/gleam.toml > "$CONTEXT/gleam.toml"
sed 's#source = "local", path = "../.."#source = "local", path = "dream"#' examples/deployment/manifest.toml > "$CONTEXT/manifest.toml"

cd "$CONTEXT"
sh test/docker.sh
echo ""
echo "The image builds, and the app answers /health in Docker Compose."
