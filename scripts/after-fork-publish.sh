#!/bin/bash
# Regenerates manifest.toml in the root project, every example and the
# integration bridge, after dream_socket_server and dream_http_server are on Hex.
#
#   scripts/after-fork-publish.sh
#
# dream depends on dream_http_server (a fork of mist), which depends on
# dream_socket_server (a fork of glisten). The committed manifests were made
# before those packages existed on Hex, so they do not list them yet.
#
# Each resolution asks the Hex API about every package of the project, and Hex
# allows roughly 100 API calls a minute. The script therefore resolves ONE
# project at a time and waits PAUSE_SECONDS after each project that resolved
# versions. It stops at the first error and names the project that failed.
# It never retries: if Hex reports a rate limit, wait and run the script again.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

# Each package with the version that dream's gleam.toml needs.
FORK_RELEASES="dream_socket_server:1.0.0 dream_http_server:1.3.1"
PAUSE_SECONDS=70

# Step 1: Refuse to run before both packages are on Hex. One request each.
echo "🔍 Checking that the forked packages are on Hex..."
for release in $FORK_RELEASES; do
  package=${release%%:*}
  FORK_VERSION=${release##*:}
  url="https://hex.pm/api/packages/$package/releases/$FORK_VERSION"
  status=$(curl --silent --output /dev/null --write-out '%{http_code}' "$url" || true)
  if [ "$status" != "200" ]; then
    echo -e "${RED}❌ $package $FORK_VERSION is not on Hex (HTTP $status from $url).${NC}"
    echo "Publish dream_socket_server, then dream_http_server, and run this script again."
    exit 1
  fi
  echo -e "${GREEN}✅ $package $FORK_VERSION is on Hex${NC}"
done
echo ""

# Step 2: Resolve each project, one at a time.
projects="."
for dir in examples/*/ integration/bridge/; do
  if [ -f "$dir/gleam.toml" ]; then
    projects="$projects ${dir%/}"
  fi
done

pause_before_next=0
for project in $projects; do
  if [ "$pause_before_next" -eq 1 ]; then
    echo -e "${YELLOW}⏳ Waiting ${PAUSE_SECONDS}s so the Hex API limit is not hit...${NC}"
    sleep "$PAUSE_SECONDS"
  fi

  echo "📦 Resolving $project..."
  # A project must unlock the local packages it uses (dream and the modules)
  # and dream_http_server, or an old locked version conflicts with a new
  # version in a gleam.toml.
  unlock=$(grep -o 'name = "[a-z_]*", version = "[^"]*", build_tools = \["gleam"\], requirements = \[[^]]*\], source = "local"' "$project/manifest.toml" 2>/dev/null | sed 's/name = "\([a-z_]*\)".*/\1/' | tr '\n' ' ')
  if grep -q 'name = "dream_http_server"' "$project/manifest.toml" 2>/dev/null; then
    unlock="$unlock dream_http_server"
  fi
  if [ -n "$(echo $unlock)" ]; then
    command="gleam update $unlock"
  else
    command="gleam deps download"
  fi
  if ! output=$(cd "$project" && $command 2>&1); then
    echo "$output"
    echo ""
    echo -e "${RED}❌ Failed in $project. Fix it, then run this script again.${NC}"
    echo "Projects before $project are already done; running them again costs Hex API calls only if they resolve again."
    exit 1
  fi
  echo "$output"

  if echo "$output" | grep -q "Resolving versions"; then
    pause_before_next=1
  else
    pause_before_next=0
  fi
  echo -e "${GREEN}✅ $project${NC}"
  echo ""
done

# Step 3: Tell the owner what to run next.
echo -e "${GREEN}✅ All manifests regenerated.${NC}"
echo ""
echo "Check the result:"
echo "  git diff --stat -- '*manifest.toml'"
echo "  grep -l dream_http_server manifest.toml examples/*/manifest.toml integration/bridge/manifest.toml"
echo ""
echo "Then run the checks and tests:"
echo "  gleam format --check"
echo "  gleam build"
echo "  make test-unit"
echo "  make test-integration    # stops processes on ports 3000 and 3001"
