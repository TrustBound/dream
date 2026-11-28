#!/usr/bin/env bash
# Release preflight checks. The publish workflow runs this script before it
# publishes anything. You can run it on your machine too:
#
#   git fetch origin main
#   git checkout 3.0.0
#   bash .github/scripts/release-preflight.sh 3.0.0
#
# The script reads only the files in the work tree and the local git clone.
# It does not use the network, so origin/main is only as new as your last
# fetch. It stops at the first failure with an "Error:" and a "Fix:" line.
set -euo pipefail

fail() {
  echo "Error: $1"
  echo "Fix: $2"
  exit 1
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  fail "give the version tag as the only argument." \
    "run the script like this: bash .github/scripts/release-preflight.sh 3.0.0"
fi
TAG="$1"

# Run from the repository root, so that the file paths below are correct.
cd "$(dirname "$0")/../.."

# a. The tag is a bare version, for example 3.0.0. Not v3.0.0.
if ! [[ "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "the tag \"$TAG\" is not a bare version X.Y.Z (digits only)." \
    "use the version itself as the tag, for example 3.0.0 (not v3.0.0)."
fi
echo "✓ Tag $TAG is a bare version"

# b. The tag is equal to the version in gleam.toml.
if [ ! -f gleam.toml ]; then
  fail "gleam.toml is missing." "run the script in a clone of the package repository."
fi
VERSION=$(grep '^version = ' gleam.toml | sed 's/version = "\(.*\)"/\1/')
if [ "$VERSION" != "$TAG" ]; then
  fail "the tag $TAG is not equal to the version in gleam.toml (\"$VERSION\")." \
    "set version = \"$TAG\" in gleam.toml on main, or tag the version that gleam.toml has."
fi
echo "✓ gleam.toml has version $TAG"

# c. The tagged commit is checked out and is on main.
if ! TAG_COMMIT=$(git rev-parse --verify --quiet "refs/tags/$TAG^{commit}"); then
  fail "the git tag $TAG does not exist in this clone." \
    "create the tag on main with: git tag $TAG && git push origin $TAG"
fi
HEAD_COMMIT=$(git rev-parse HEAD)
if [ "$HEAD_COMMIT" != "$TAG_COMMIT" ]; then
  fail "the checked-out commit is not the commit of tag $TAG, so these checks would read the wrong files." \
    "run: git checkout $TAG, then run this script again."
fi
if ! git rev-parse --verify --quiet "refs/remotes/origin/main^{commit}" >/dev/null; then
  fail "this clone has no origin/main." "run: git fetch origin main"
fi
if ! git merge-base --is-ancestor "$TAG_COMMIT" origin/main; then
  fail "the commit of tag $TAG is not on main (not in origin/main)." \
    "merge the release to main first. Then delete the tag and push it again on the merged commit."
fi
echo "✓ Tag $TAG points to a commit on main"

# d. Every dependency comes from Hex. Hex rejects a package with a path or
# git dependency.
if grep -nE '^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*\{[^}]*(path|git)[[:space:]]*=' gleam.toml; then
  fail "gleam.toml has a path or git dependency (listed above)." \
    "change each one to a Hex version range on main, then tag again."
fi
echo "✓ gleam.toml has only Hex dependencies"

# e. The release notes file exists.
NOTES="releases/release-$TAG.md"
if [ ! -f "$NOTES" ]; then
  fail "$NOTES does not exist." \
    "add the release notes for $TAG in $NOTES on main. The GitHub release uses this file."
fi
echo "✓ $NOTES exists"

# f. The release notes have a real release date.
DATE_LINE=$(grep -m 1 '\*\*Release Date:\*\*' "$NOTES" || true)
if [ -z "$DATE_LINE" ]; then
  fail "$NOTES has no **Release Date:** line." \
    "add a line like **Release Date:** 2026-11-23 to $NOTES."
fi
RELEASE_DATE=$(printf '%s\n' "$DATE_LINE" | sed 's/.*\*\*Release Date:\*\*[[:space:]]*//')
if [ -z "$RELEASE_DATE" ] || printf '%s\n' "$RELEASE_DATE" | grep -qiE 'draft|unreleased|not released'; then
  fail "the release date in $NOTES is not a real date: \"$RELEASE_DATE\"." \
    "set the release date in $NOTES, for example **Release Date:** 2026-11-23."
fi
echo "✓ $NOTES has the release date $RELEASE_DATE"

# g. CHANGELOG.md has a section for the version, and it is not "Unreleased".
if [ ! -f CHANGELOG.md ]; then
  fail "CHANGELOG.md is missing." "add CHANGELOG.md with a section ## [$TAG] - <date>."
fi
HEADING=$(awk -v h="## [$TAG]" 'index($0, h) == 1 { print; exit }' CHANGELOG.md)
if [ -z "$HEADING" ]; then
  fail "CHANGELOG.md has no section heading ## [$TAG]." \
    "add the section ## [$TAG] - <date> to CHANGELOG.md."
fi
if printf '%s\n' "$HEADING" | grep -qi 'unreleased'; then
  fail "the CHANGELOG.md heading for $TAG says Unreleased: \"$HEADING\"." \
    "replace Unreleased with the release date, for example ## [$TAG] - 2026-11-23."
fi
echo "✓ CHANGELOG.md has the section \"$HEADING\""

echo "✓ All preflight checks passed for $TAG"
