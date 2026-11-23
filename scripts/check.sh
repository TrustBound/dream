#!/bin/sh
# What the unit job of CI runs: the format check, the build, the unit tests
# with line coverage, and the check of the code blocks of the docs.
# "make check" runs this script.
set -eu

gleam format --check src test
gleam build
make test-unit
make check-snippets
