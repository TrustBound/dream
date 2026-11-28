#!/bin/sh
# Builds the Docker image of examples/deployment, starts it with Docker
# Compose (PostgreSQL, the migrations and the app), asks the app for /health,
# stops the app and checks that it stopped on SIGTERM, and stops everything:
# the commands of examples/deployment/test/docker.sh.
# At the end it removes the containers, the volume and the images that the
# run built (your-app, and the app and migrate images of Compose). It keeps
# the images that it pulled (the Gleam image, erlang:29.1.1-alpine and
# postgres:16-alpine).
# "make test-docker" runs this script. Needs Gleam, Docker with Compose v2,
# and the port 3000 free.
#
# The example depends on the dream of this repository (path = "../.."), and
# a Docker build sees only its context folder. So the script runs the
# commands in a copy of the example, with the repository's dream in it at
# dream/, and points the path dependency there.
#
# The image build asks Hex for nothing. The script downloads the packages
# into the copy first, with the gleam of this machine (in CI with the Hex key
# of the workflow), and the .dockerignore of the example lets build/packages
# into the image. The first build has no network, so it fails if gleam tries
# to resolve versions or download a package.
set -eu
CONTEXT=$(mktemp -d)
trap 'cd "$CONTEXT" && docker compose down -v --rmi local > /dev/null 2>&1; docker image rm your-app > /dev/null 2>&1; rm -r "$CONTEXT"' EXIT

cp -R examples/deployment/. "$CONTEXT/"
mkdir "$CONTEXT/dream"
cp -R gleam.toml manifest.toml src "$CONTEXT/dream/"
sed 's#path = "../.."#path = "dream"#' examples/deployment/gleam.toml > "$CONTEXT/gleam.toml"
sed 's#path = "../.."#path = "dream"#' examples/deployment/manifest.toml > "$CONTEXT/manifest.toml"

cd "$CONTEXT"
gleam deps download
docker build --network none -t your-app .
sh test/docker.sh
echo ""
echo "The image builds with no network, the app answers /health in Docker"
echo "Compose, and it stops on SIGTERM."
