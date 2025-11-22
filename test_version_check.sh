#!/bin/bash
# Test script for version detection logic

MODULE_DIR="modules/opensearch"
GLEAM_TOML="$MODULE_DIR/gleam.toml"

if [ ! -f "$GLEAM_TOML" ]; then
  echo "Error: $GLEAM_TOML not found"
  exit 1
fi

# Get current version and package name
CURRENT_VERSION=$(grep '^version = ' "$GLEAM_TOML" | sed 's/version = "\(.*\)"/\1/')
PACKAGE_NAME=$(grep '^name = ' "$GLEAM_TOML" | sed 's/name = "\(.*\)"/\1/')

if [ -z "$CURRENT_VERSION" ]; then
  echo "Error: Could not extract version from $GLEAM_TOML"
  exit 1
fi

if [ -z "$PACKAGE_NAME" ]; then
  echo "Error: Could not extract package name from $GLEAM_TOML"
  exit 1
fi

echo "Testing version check for: $PACKAGE_NAME version $CURRENT_VERSION"
echo "Checking if version exists on Hex..."

# Check if version exists on Hex
HEX_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://hex.pm/api/packages/$PACKAGE_NAME/releases/$CURRENT_VERSION")

echo "Hex API response: HTTP $HEX_RESPONSE"

if [ "$HEX_RESPONSE" = "200" ]; then
  echo "✓ Version $CURRENT_VERSION already exists on Hex, would skip publish"
  exit 0
elif [ "$HEX_RESPONSE" = "404" ]; then
  echo "✓ Version $CURRENT_VERSION does not exist on Hex, would publish"
  exit 0
else
  echo "⚠ Warning: Unexpected response from Hex API (HTTP $HEX_RESPONSE), would attempt to publish"
  exit 0
fi

