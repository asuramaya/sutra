#!/usr/bin/env bash
# vendor.sh — copy the canonical sutra.py into a pill, byte-identical, and
# record the version+hash it came from so a CI drift-check can prove the copy
# was never hand-edited. The pill imports it as a sibling of its daemon.
#
#   ./vendor.sh /home/asuramaya/code/REPOS/ByeByte/bin
#
# Writes:  <dest>/sutra.py           the byte-identical module
#          <dest>/sutra.version      "<version>  <sha256>"  (the drift anchor)
#
# The pill's CI runs:  sha256sum -c against sutra.version  (integrity), and
# `make check-sutra` diffs against ../sutra/sutra.py when present (freshness).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?usage: vendor.sh <dest-bin-dir>}"

[ -d "$DEST" ] || { echo "vendor: $DEST is not a directory" >&2; exit 1; }
cp "$SRC/sutra.py" "$DEST/sutra.py"
ver="$(tr -d '[:space:]' < "$SRC/VERSION")"
sha="$(sha256sum "$SRC/sutra.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$sha" > "$DEST/sutra.version"
echo "vendored sutra $ver -> $DEST/sutra.py"
echo "  $sha"
echo "commit both sutra.py and sutra.version; do not edit the copy — re-vendor."
