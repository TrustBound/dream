#!/bin/sh
# Installs the matcha binary of the Matcha template compiler, version 0.19.0,
# for Linux on x86-64, into the folder given as the first argument. The
# download must match the SHA-256 checksum of the release. CI runs this
# script before "make check-templates" and "make test-tasks".
#
#   sh scripts/install-matcha.sh FOLDER
set -eu
FOLDER=$1
VERSION=0.19.0
ARCHIVE=matcha-$VERSION-linux-amd64.tar.gz
SHA256=fc168fcc0a4a61fa223cb0524837de506a7f02070e4d62937601ffd145dc688e

mkdir -p "$FOLDER"
curl -fsSL -o "$FOLDER/$ARCHIVE" "https://github.com/michaeljones/matcha/releases/download/$VERSION/$ARCHIVE"
echo "$SHA256  $FOLDER/$ARCHIVE" | sha256sum -c -
tar -xzf "$FOLDER/$ARCHIVE" -C "$FOLDER" matcha
rm "$FOLDER/$ARCHIVE"
"$FOLDER/matcha" --version
