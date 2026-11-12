#!/bin/bash
# Generates the vendored mist and glisten copies from the git submodules under
# vendor/, or checks that the copies in the tree match them.
#
#   scripts/vendor.sh sync    rewrite the copies from vendor/mist and vendor/glisten
#   scripts/vendor.sh check   fail if any copy differs from what sync would write
#
# This script is the only definition of how the copies are made:
# - src/<lib>.gleam, src/<lib>/ and src/<lib>_*.erl are vendor/<lib>/src/
#   byte for byte, and src/<lib>/LICENSE is vendor/<lib>/LICENSE.
# - test/vendored_<lib>/ is vendor/<lib>/test/ with mechanical edits only:
#   imports of the test helper module get the vendored_<lib>/ prefix, and
#   `import gleeunit` and the `main` function that starts gleeunit are removed.
# - Some upstream test files are not copied (see SKIP_TESTS below).
# - test/vendored_mist/suite.gleam is hand-written. check also fails when a
#   `*_test` function in the copied tests is not registered in it.
#
# Never pass the copied source to `gleam format`. See docs/contributing/vendored-mist.md.

set -e

# Same byte order for sort and comm everywhere.
export LC_ALL=C

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

LIBS="mist glisten"
SUITE=test/vendored_mist/suite.gleam

# The upstream test helper module that the copied tests import.
test_helper() {
  case "$1" in
    mist) echo scaffold ;;
    glisten) echo tcp_client ;;
  esac
}

# Upstream test files (relative to vendor/<lib>/test/) that are not copied.
# mist_test.gleam only starts gleeunit; websocket_test.gleam needs gramps,
# which Dream does not depend on; glisten's test_utils.gleam is not used.
SKIP_TESTS="mist:mist_test.gleam mist:websocket_test.gleam glisten:test_utils.gleam"

usage() {
  echo "Usage: $0 sync|check" >&2
  exit 2
}

# Fails when a submodule is not checked out.
require_submodules() {
  local lib
  for lib in $LIBS; do
    if [ ! -f "vendor/$lib/gleam.toml" ]; then
      echo -e "${RED}❌ vendor/$lib is not initialised.${NC}" >&2
      echo "   Run: git submodule update --init --recursive" >&2
      exit 1
    fi
  done
}

is_skipped_test() {
  local entry
  for entry in $SKIP_TESTS; do
    [ "$entry" = "$1:$2" ] && return 0
  done
  return 1
}

# Applies the mechanical test edits to stdin.
adapt_test() {
  local lib=$1
  local helper
  helper=$(test_helper "$lib")
  sed -e "s#^import $helper\$#import vendored_$lib/$helper#" \
    -e "s#^import $helper\([. ]\)#import vendored_$lib/$helper\1#" \
    -e '/^import gleeunit$/d' \
    | awk '
      skip && $0 == "}" { skip = 0; drop_blank = 1; next }
      skip { next }
      $0 == "pub fn main() {" { skip = 1; next }
      drop_blank && $0 == "" { drop_blank = 0; next }
      { drop_blank = 0; print }
    '
}

# Writes every generated file into the directory $1, at its tree path.
generate() {
  local out=$1
  local lib rel
  for lib in $LIBS; do
    (cd "vendor/$lib/src" && find . -type f) | sed 's#^\./##' | while IFS= read -r rel; do
      mkdir -p "$(dirname "$out/src/$rel")"
      cp "vendor/$lib/src/$rel" "$out/src/$rel"
    done
    cp "vendor/$lib/LICENSE" "$out/src/$lib/LICENSE"

    (cd "vendor/$lib/test" && find . -type f) | sed 's#^\./##' | while IFS= read -r rel; do
      is_skipped_test "$lib" "$rel" && continue
      mkdir -p "$(dirname "$out/test/vendored_$lib/$rel")"
      case "$rel" in
        *.gleam) adapt_test "$lib" < "vendor/$lib/test/$rel" > "$out/test/vendored_$lib/$rel" ;;
        *) cp "vendor/$lib/test/$rel" "$out/test/vendored_$lib/$rel" ;;
      esac
    done
  done
  if [ -e "$out/$SUITE" ]; then
    echo -e "${RED}❌ Upstream now has a file at $SUITE, which is hand-written here.${NC}" >&2
    exit 1
  fi
}

# Lists the copied files in the tree (tracked or not ignored), sorted.
tree_files() {
  local lib
  for lib in $LIBS; do
    git ls-files --cached --others --exclude-standard -- \
      "src/$lib.*" "src/${lib}_*" "src/$lib/" "test/vendored_$lib/"
  done | grep -vx "$SUITE" | while IFS= read -r f; do
    [ -f "$f" ] && echo "$f"
  done | sort -u
}

generated_files() {
  (cd "$1" && find . -type f) | sed 's#^\./##' | sort
}

# Fails when a `*_test` function in the copied tests is not in suite.gleam.
check_registrations() {
  local missing=0
  local file module fn
  while IFS= read -r file; do
    module=$(basename "$file" .gleam)
    for fn in $(grep -Eo '^pub fn [a-z0-9_]+_test\(' "$file" | sed -e 's/^pub fn //' -e 's/($//'); do
      if ! grep -Eq "(^|[^a-z0-9_])$module\.$fn([^a-z0-9_]|\$)" "$SUITE"; then
        echo "  $file: $fn" >&2
        missing=1
      fi
    done
  done < <(find test/vendored_mist test/vendored_glisten -name '*.gleam' ! -path "$SUITE" | sort)
  if [ "$missing" -eq 1 ]; then
    echo -e "${RED}❌ The test functions above are not registered in $SUITE.${NC}" >&2
    return 1
  fi
}

[ $# -eq 1 ] || usage
mode=$1
case "$mode" in
  sync | check) ;;
  *) usage ;;
esac

require_submodules

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gen=$tmp/gen
mkdir "$gen"
generate "$gen"

generated_files "$gen" > "$tmp/generated"
tree_files > "$tmp/tree"

failed=0
while IFS= read -r f; do
  if [ ! -f "$f" ]; then
    status=missing
  elif ! cmp -s "$gen/$f" "$f"; then
    status=differs
  else
    continue
  fi
  if [ "$mode" = sync ]; then
    mkdir -p "$(dirname "$f")"
    cp "$gen/$f" "$f"
    echo "updated: $f"
  else
    echo "  $status: $f" >&2
    failed=1
  fi
done < "$tmp/generated"

while IFS= read -r f; do
  if [ "$mode" = sync ]; then
    rm "$f"
    echo "removed: $f"
  else
    echo "  not in vendor/: $f" >&2
    failed=1
  fi
done < <(comm -13 "$tmp/generated" "$tmp/tree")

if [ "$mode" = sync ]; then
  echo -e "${GREEN}✅ Vendored copies synced from vendor/${NC}"
  exit 0
fi

if [ "$failed" -eq 1 ]; then
  echo -e "${RED}❌ The vendored copies above do not match vendor/. Run 'make vendor-sync'.${NC}" >&2
fi
check_registrations || failed=1
[ "$failed" -eq 0 ] || exit 1
echo -e "${GREEN}✅ Vendored copies match vendor/ and all vendored tests are registered${NC}"
