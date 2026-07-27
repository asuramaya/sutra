#!/usr/bin/env bash
# vendor.sh — copy the canonical sutra.py into a pill, byte-identical, and
# record the version+hash it came from so a CI drift-check can prove the copy
# was never hand-edited. The pill imports it as a sibling of its daemon.
#
#   ./vendor.sh /home/asuramaya/code/REPOS/ByeByte/bin \
#               /home/asuramaya/code/REPOS/ByeByte/extension/byebyte@asuramaya
#
# Writes:  <dest>/sutra.py           the byte-identical module
#          <dest>/sutra.version      "<version>  <sha256>"  (the integrity anchor,
#                                    UNCHANGED format — existing pills' check-sutra
#                                    parses $NF for the sha; do not add fields here)
#          <dest>/sutra.commit       the canonical commit this copy came from (the
#                                    LAG-vs-DRIFT anchor — a separate file, additive,
#                                    so an unadopted pill's check-sutra is untouched)
# and the same pair for sutra_update.py and sutra_xen.py (vendored
# unconditionally beside it — a pill imports only what it needs), and, when
# an extension dir is given, pill.js + pill.version + pill.commit there the
# same way (the extension imports it as a sibling: `import * as Pill from
# './pill.js'`).
#
# The pill's CI runs:  sha256sum -c against sutra.version  (integrity, the
# hard gate — hand-edited or corrupted, always a hard fail); `make
# check-sutra`'s freshness half, when ../sutra/ is present, reads .commit
# and asks canonical git which of two things this is, compared against
# the FILE'S OWN last-modifying commit — never canonical repo HEAD, which
# advances on every commit including ones that never touch this file
# (decision d51e090f's original recipe compared against repo HEAD and
# false-positived LAG across the whole family the first time a docs-only
# commit landed; fixed by decision 325b1969). recorded ==
# the file's last-modifying commit, or a descendant of it → fresh (an
# honest vendor, nothing has changed since); recorded is a strict
# ancestor of it → LAG (the file has genuinely moved on, warn and exit
# 0); recorded isn't in canonical's history at all → DRIFT (corrupted
# anchor or a rewritten canonical history, hard fail).
# Custodian ruling (supersedes decision 4a2c4c2b's plain HEAD-compare with
# the LAG/DRIFT split, itself corrected by the per-file-head fix above;
# thread 0627dac7 carries the reference check-sutra recipe every pill's
# Wave B adopts at its own next touch).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?usage: vendor.sh <dest-bin-dir>}"

# Refuse a dirty canonical tree: vendoring WIP would ship an uncommitted,
# undecided edit into a pill under a version number nobody reviewed or
# released (custodian lesson #1 — a dirty canonical checkout already leaks
# into every pill's dev-box `check-sutra` freshness diff; it must not also
# leak into an actual vendored copy).
if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
   [ -n "$(git -C "$SRC" status --porcelain -- sutra.py sutra_update.py \
       sutra_xen.py pill.js)" ]; then
    echo "vendor: canonical sutra has uncommitted changes to a vendored" \
         "file — commit or stash before vendoring" >&2
    exit 1
fi

[ -d "$DEST" ] || { echo "vendor: $DEST is not a directory" >&2; exit 1; }
ver="$(tr -d '[:space:]' < "$SRC/VERSION")"
# The LAG-vs-DRIFT anchor: which canonical commit this vendor came from.
# Empty (never written) when canonical isn't a git checkout at all — a
# pill's check-sutra treats a missing .commit as "freshness unknown", not
# a failure.
commit="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)"

cp "$SRC/sutra.py" "$DEST/sutra.py"
sha="$(sha256sum "$SRC/sutra.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$sha" > "$DEST/sutra.version"
[ -n "$commit" ] && printf '%s\n' "$commit" > "$DEST/sutra.commit"
echo "vendored sutra $ver -> $DEST/sutra.py"
echo "  $sha"
# The update spine vendors the same way, its own drift anchor beside it.
# A pill that hasn't adopted the spine yet simply doesn't import it.
cp "$SRC/sutra_update.py" "$DEST/sutra_update.py"
usha="$(sha256sum "$SRC/sutra_update.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$usha" > "$DEST/sutra_update.version"
[ -n "$commit" ] && printf '%s\n' "$commit" > "$DEST/sutra_update.commit"
echo "vendored sutra_update -> $DEST/sutra_update.py"
echo "  $usha"
# Same for the Xen guest-surface reader — vendored unconditionally like the
# update spine; a pill with no Xen concerns simply doesn't import it.
cp "$SRC/sutra_xen.py" "$DEST/sutra_xen.py"
xsha="$(sha256sum "$SRC/sutra_xen.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$xsha" > "$DEST/sutra_xen.version"
[ -n "$commit" ] && printf '%s\n' "$commit" > "$DEST/sutra_xen.commit"
echo "vendored sutra_xen -> $DEST/sutra_xen.py"
echo "  $xsha"

# Extension commons: pill.js lands in the EXTENSION dir (second arg), not
# bin/ — GJS imports siblings only, and the extension dir is what `make
# pill` ships to ~/.local/share/gnome-shell/extensions.
if [ $# -ge 2 ]; then
    EXTDIR="$2"
    [ -d "$EXTDIR" ] || { echo "vendor: $EXTDIR is not a directory" >&2; exit 1; }
    cp "$SRC/pill.js" "$EXTDIR/pill.js"
    psha="$(sha256sum "$SRC/pill.js" | cut -d' ' -f1)"
    printf '%s  %s\n' "$ver" "$psha" > "$EXTDIR/pill.version"
    [ -n "$commit" ] && printf '%s\n' "$commit" > "$EXTDIR/pill.commit"
    echo "vendored pill.js -> $EXTDIR/pill.js"
    echo "  $psha"
fi
echo "commit the vendored files and .version/.commit pairs; do not edit the copies — re-vendor."
