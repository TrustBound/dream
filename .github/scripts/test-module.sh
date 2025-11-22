#!/bin/bash
# Test a Gleam module, optionally patching Dream dependencies

set -e

MODULE_DIR="$1"
PATCH_DEPS="${2:-false}"

if [ -z "$MODULE_DIR" ]; then
  echo "Error: Module directory required"
  exit 1
fi

cd "$MODULE_DIR"

# Patch dependencies if requested and if module has Dream dependencies
if [ "$PATCH_DEPS" = "true" ] && grep -q "^dream_" gleam.toml; then
  echo "Patching gleam.toml to use local path dependencies for Dream modules"
  cp gleam.toml gleam.toml.bak
  sed -i.tmp 's/^\(dream_http_client\) = ".*"/\1 = { path = "..\/..\/modules\/http_client" }/' gleam.toml
  sed -i.tmp2 's/^\(dream_postgres\) = ".*"/\1 = { path = "..\/..\/modules\/postgres" }/' gleam.toml
  sed -i.tmp3 's/^\(dream_config\) = ".*"/\1 = { path = "..\/..\/modules\/config" }/' gleam.toml
  sed -i.tmp4 's/^\(dream_ets\) = ".*"/\1 = { path = "..\/..\/modules\/ets" }/' gleam.toml
  sed -i.tmp5 's/^\(dream_json\) = ".*"/\1 = { path = "..\/..\/modules\/json" }/' gleam.toml
  sed -i.tmp6 's/^\(dream_opensearch\) = ".*"/\1 = { path = "..\/..\/modules\/opensearch" }/' gleam.toml
  rm -f gleam.toml.tmp* 2>/dev/null || true
fi

# Download, build, and test
gleam deps download
gleam build
gleam test

# Restore original gleam.toml if we modified it
if [ -f gleam.toml.bak ]; then
  mv gleam.toml.bak gleam.toml
fi

