#!/bin/sh
# Compiles the Matcha templates of the docs (test/snippets) and of the
# examples in a copy of each folder, and fails when a generated module is not
# the module in the repository. Needs the matcha binary on the PATH.
# "make check-templates" runs this script.
set -eu
WORK=$(mktemp -d)
trap 'rm -r "$WORK"' EXIT

mkdir "$WORK/snippets"
cp test/snippets/*.matcha "$WORK/snippets/"
(cd "$WORK/snippets" && matcha > /dev/null)
gleam format "$WORK/snippets"
for generated in "$WORK"/snippets/*.gleam; do
  diff -u "test/snippets/$(basename "$generated")" "$generated"
done

for example in websocket_chat multi_format tasks; do
  mkdir -p "$WORK/$example/test"
  cp -R "examples/$example/src" "examples/$example/Makefile" "$WORK/$example/"
  cp "examples/$example/test/templates.sh" "$WORK/$example/test/"
  (cd "$WORK/$example" && sh test/templates.sh > /dev/null)
  diff -ru "examples/$example/src" "$WORK/$example/src"
done

echo "The generated template modules are up to date."
