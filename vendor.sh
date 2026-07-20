#!/usr/bin/env bash
# vendor.sh — copy the canonical sutra.py into a pill, byte-identical, and
# record the version+hash it came from so a CI drift-check can prove the copy
# was never hand-edited. The pill imports it as a sibling of its daemon.
#
#   ./vendor.sh /home/asuramaya/code/REPOS/ByeByte/bin \
#               /home/asuramaya/code/REPOS/ByeByte/extension/byebyte@asuramaya
#
# Writes:  <dest>/sutra.py           the byte-identical module
#          <dest>/sutra.version      "<version>  <sha256>"  (the drift anchor)
# and, when an extension dir is given, pill.js + pill.version there the same
# way (the extension imports it as a sibling: `import * as Pill from './pill.js'`).
#
# The pill's CI runs:  sha256sum -c against sutra.version  (integrity), and
# `make check-sutra` diffs against ../sutra/sutra.py when present (freshness).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?usage: vendor.sh <dest-bin-dir>}"

[ -d "$DEST" ] || { echo "vendor: $DEST is not a directory" >&2; exit 1; }
ver="$(tr -d '[:space:]' < "$SRC/VERSION")"
cp "$SRC/sutra.py" "$DEST/sutra.py"
sha="$(sha256sum "$SRC/sutra.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$sha" > "$DEST/sutra.version"
echo "vendored sutra $ver -> $DEST/sutra.py"
echo "  $sha"
# The update spine vendors the same way, its own drift anchor beside it.
# A pill that hasn't adopted the spine yet simply doesn't import it.
cp "$SRC/sutra_update.py" "$DEST/sutra_update.py"
usha="$(sha256sum "$SRC/sutra_update.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$usha" > "$DEST/sutra_update.version"
echo "vendored sutra_update -> $DEST/sutra_update.py"
echo "  $usha"

# Extension commons: pill.js lands in the EXTENSION dir (second arg), not
# bin/ — GJS imports siblings only, and the extension dir is what `make
# pill` ships to ~/.local/share/gnome-shell/extensions.
if [ $# -ge 2 ]; then
    EXTDIR="$2"
    [ -d "$EXTDIR" ] || { echo "vendor: $EXTDIR is not a directory" >&2; exit 1; }
    cp "$SRC/pill.js" "$EXTDIR/pill.js"
    psha="$(sha256sum "$SRC/pill.js" | cut -d' ' -f1)"
    printf '%s  %s\n' "$ver" "$psha" > "$EXTDIR/pill.version"
    echo "vendored pill.js -> $EXTDIR/pill.js"
    echo "  $psha"
fi
echo "commit the vendored files and .version pairs; do not edit the copies — re-vendor."
