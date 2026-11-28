#!/bin/sh
# Runs the tests from the recordings: no network and no database.
# "make test" runs this script, and so does the integration job of CI.
set -eu

gleam format --check src test
gleam test
