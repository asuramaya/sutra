#!/usr/bin/env bash
# vendor.sh — copy the canonical sutra.py into a pill, byte-identical, and
# record the version+hash it came from so a CI drift-check can prove the copy
# was never hand-edited.
#
#   ./vendor.sh /home/asuramaya/code/REPOS/ByeByte/share/byebyte/lib \
#               /home/asuramaya/code/REPOS/ByeByte/extension/byebyte@asuramaya \
#               --bootstrap=byebyte
#
# DEST is each pill's own PRIVATE lib dir, never a shared bin/ — six pills
# vendoring identically-named sutra.py/sutra_update.py/sutra_xen.py into the
# SAME shared /usr/bin (deb) or /usr/local/bin (install.sh) makes any two
# pills uninstallable together (dpkg refuses the second outright; install.sh
# silently overwrites, anchors included). See BOOTSTRAP.md for the collision
# and the fix in full (ruling 3e44bd95): each pill's copies move to
# <prefix>/share/<pill>/lib/, and every binary that imports sutra needs a
# small sys.path bootstrap preamble to find them there — pass
# --bootstrap=<pill-name> to print that preamble ready to paste.
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
# './pill.js'` — pill.js is EXEMPT from the collision fix, it already installs
# per-pill under <prefix>/share/<pill>/extension/<uuid>/ and cannot collide).
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

BOOTSTRAP_PILL=""
args=()
for a in "$@"; do
    case "$a" in
        --bootstrap=*) BOOTSTRAP_PILL="${a#--bootstrap=}" ;;
        *) args+=("$a") ;;
    esac
done
set -- "${args[@]+"${args[@]}"}"

DEST="${1:?usage: vendor.sh <dest-lib-dir> [ext-dir] [--bootstrap=<pill-name>]}"

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

# --bootstrap=<pill-name>: print the canonical sys.path preamble ready to
# paste. Sutra authors this ONCE so no pill hand-derives its own (and gets
# the relative-path math, or the idempotency check, subtly wrong) — the
# pill name is the only line that ever changes, and only between pills,
# never within one. Instructions go to stderr so the code block on stdout
# stays clean to redirect: vendor.sh DEST --bootstrap=NAME > preamble.py.txt
if [ -n "$BOOTSTRAP_PILL" ]; then
    echo "" >&2
    echo "paste this at the top of every binary in $BOOTSTRAP_PILL that" \
         "imports sutra, right before the 'import sutra' line (see" \
         "BOOTSTRAP.md):" >&2
    cat <<EOF
# --- sutra bootstrap (sutra $ver; see BOOTSTRAP.md -- do not hand-edit) ----
import os as _os
import sys as _sys
_PILL = "$BOOTSTRAP_PILL"
_libdir = _os.path.join(
    _os.path.dirname(_os.path.dirname(_os.path.realpath(__file__))),
    "share", _PILL, "lib")
if _libdir not in _sys.path:
    _sys.path.insert(0, _libdir)
del _os, _sys, _libdir, _PILL
# --- end sutra bootstrap ----------------------------------------------------
EOF
fi
