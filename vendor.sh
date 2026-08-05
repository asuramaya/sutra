#!/usr/bin/env bash
# vendor.sh — copy the canonical sutra.py into a pill, byte-identical, and
# record the version+hash it came from so a CI drift-check can prove the copy
# was never hand-edited.
#
#   ./vendor.sh /home/asuramaya/code/REPOS/byebyte/src/share/byebyte/lib \
#               /home/asuramaya/code/REPOS/byebyte/src/extension/byebyte@asuramaya \
#               --bootstrap=byebyte
#
# DEST is each pill's own PRIVATE lib dir, never a shared bin/ — six pills
# vendoring identically-named sutra.py/sutra_update.py/sutra_xen.py into the
# SAME shared /usr/bin (deb) or /usr/local/bin (install.sh) makes any two
# pills uninstallable together (dpkg refuses the second outright; install.sh
# silently overwrites, anchors included). See docs/BOOTSTRAP.md for the collision
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
# and the same pair for sutra_update.py, sutra_xen.py, and sutra.mk (the
# recipe layer -- check-sutra/row-count/checkout-guard, vendored under the
# same anchor pair so a pill runs the current correct recipe rather than a
# hand-copied snapshot; see sutra.mk's own header) vendored unconditionally
# beside sutra.py, and, when an extension dir is given, pill.js +
# pill.version + pill.commit there the same way (the extension imports it
# as a sibling: `import * as Pill from './pill.js'` — pill.js is EXEMPT
# from the collision fix, it already installs per-pill under
# <prefix>/share/<pill>/extension/<uuid>/ and cannot collide).
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

# --- signed-canonical guard: refuse to vendor an unattested commit --------
# The supply-chain gap this closes (found designing the update service,
# dispatched via Alfred msg 3744): sutra is vendored BYTE-IDENTICAL into six
# pills and, before this guard, nothing ever asked whether the canonical
# state being copied was actually approved by a human holding a key. This
# script recorded whatever sha256 sat in the checkout AT VENDOR TIME as
# authoritative; a compromised canonical checkout would poison that hash
# permanently, every later check-sutra would pass forever after (integrity
# only proves the copy MATCHES what was recorded, never that what was
# recorded was GOOD), and six pills would sign and ship the poison with
# VALID signatures — not forged, correctly attesting "the operator released
# this." The operator would just have released poison unknowingly.
#
# Same fail-closed shape as the dirty-tree guard above, one layer up: a tag
# containing HEAD, verified with `git verify-tag` against this repo's own
# packaging/release-signing/allowed_signers, is the human-approval
# checkpoint. NOT MADE ABSOLUTE, on purpose (Alfred's explicit instruction):
# vendoring an untagged dev fix is legitimate work, and a guard that blocks
# it outright just gets worked around by whoever hits it next.
# SUTRA_VENDOR_ALLOW_UNSIGNED=1 is the escape hatch — same doctrine as
# SUTRA_EXT_DIR/SUTRA_CHECK_BIN elsewhere in this family, no default that's
# sometimes wrong — and when it's used, that fact is written into the
# vendored .commit anchor itself (a second line, "unsigned"), not just
# printed to scrollback nobody rereads, so a consuming pill's check-sutra
# reports it forever after, offline, with no canonical checkout required.
# Visible, never silent: a guard that can be bypassed invisibly is worse
# than no guard, because it manufactures false confidence (same doctrine as
# the LAG warning and byebyte's PENDING contract).
#
# Pre-arming state (packaging/release-signing/allowed_signers empty or
# absent) is INERT, not a refusal — the same armed/unarmed doctrine
# sutra_update.py's own armed() already applies to this exact anchor file
# shape: there is no key to check against yet, so nothing here can refuse
# anything until the anchor is actually armed. This is what lets ordinary
# vendoring keep working, unchanged, while the anchor gets armed and tags
# start getting signed elsewhere in the family, in parallel — neither side
# blocks the other.
#
# A signed tag here is a VENDORING-PROVENANCE CHECKPOINT, not a release —
# sutra still cuts no release of its own (docs/RELEASING.md, RELEASE.md:201
# unchanged by this). It attests only "a human holding the key approved
# this canonical state for vendoring", nothing about a packaged artifact.
#
# NOTHING asuramaya-SPECIFIC: no hardcoded org, no hardcoded pill list, no
# assumed tag-naming scheme — any tag containing HEAD that verifies against
# this repo's OWN allowed_signers satisfies the guard, on any fork.
VENDOR_UNSIGNED_MARK=""
if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _sutra_anchor="$SRC/packaging/release-signing/allowed_signers"
    if [ -s "$_sutra_anchor" ]; then
        _sutra_head="$(git -C "$SRC" rev-parse HEAD)"
        _sutra_signed_tag=""
        for _t in $(git -C "$SRC" tag --contains "$_sutra_head" 2>/dev/null); do
            if git -C "$SRC" -c gpg.format=ssh \
                   -c gpg.ssh.allowedSignersFile="$_sutra_anchor" \
                   verify-tag "$_t" >/dev/null 2>&1; then
                _sutra_signed_tag="$_t"
                break
            fi
        done
        if [ -n "$_sutra_signed_tag" ]; then
            echo "vendor: canonical HEAD ($_sutra_head) covered by signed tag $_sutra_signed_tag"
        elif [ "${SUTRA_VENDOR_ALLOW_UNSIGNED:-}" = "1" ]; then
            echo "vendor: WARNING -- canonical HEAD ($_sutra_head) has no signed" \
                 "tag covering it (SUTRA_VENDOR_ALLOW_UNSIGNED=1, vendoring anyway" \
                 "-- recorded in the vendored .commit anchor)" >&2
            VENDOR_UNSIGNED_MARK="unsigned"
        else
            echo "vendor: refusing -- canonical HEAD ($_sutra_head) has no signed" \
                 "tag covering it. Tag and sign it first (git tag -s), or set" \
                 "SUTRA_VENDOR_ALLOW_UNSIGNED=1 to vendor an untagged dev fix" \
                 "anyway (the consuming pill's check-sutra will then report the" \
                 "anchor as unsigned)." >&2
            exit 1
        fi
    fi
fi

[ -d "$DEST" ] || { echo "vendor: $DEST is not a directory" >&2; exit 1; }
ver="$(tr -d '[:space:]' < "$SRC/packaging/VERSION")"
# The LAG-vs-DRIFT anchor: which canonical commit this vendor came from.
# Empty (never written) when canonical isn't a git checkout at all — a
# pill's check-sutra treats a missing .commit as "freshness unknown", not
# a failure.
commit="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)"
# Writes a .commit anchor, plus a second "unsigned" line when the guard
# above was bypassed with SUTRA_VENDOR_ALLOW_UNSIGNED=1 -- one place for
# both, so every anchor pair below carries the mark consistently instead of
# five call sites each remembering it separately.
_sutra_write_commit_anchor() {
    [ -n "$commit" ] || return 0
    printf '%s\n' "$commit" > "$1"
    if [ -n "$VENDOR_UNSIGNED_MARK" ]; then
        printf '%s\n' "$VENDOR_UNSIGNED_MARK" >> "$1"
    fi
}

cp "$SRC/sutra.py" "$DEST/sutra.py"
sha="$(sha256sum "$SRC/sutra.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$sha" > "$DEST/sutra.version"
_sutra_write_commit_anchor "$DEST/sutra.commit"
echo "vendored sutra $ver -> $DEST/sutra.py"
echo "  $sha"
# The update spine vendors the same way, its own drift anchor beside it.
# A pill that hasn't adopted the spine yet simply doesn't import it.
cp "$SRC/sutra_update.py" "$DEST/sutra_update.py"
usha="$(sha256sum "$SRC/sutra_update.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$usha" > "$DEST/sutra_update.version"
_sutra_write_commit_anchor "$DEST/sutra_update.commit"
echo "vendored sutra_update -> $DEST/sutra_update.py"
echo "  $usha"
# Same for the Xen guest-surface reader — vendored unconditionally like the
# update spine; a pill with no Xen concerns simply doesn't import it.
cp "$SRC/sutra_xen.py" "$DEST/sutra_xen.py"
xsha="$(sha256sum "$SRC/sutra_xen.py" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$xsha" > "$DEST/sutra_xen.version"
_sutra_write_commit_anchor "$DEST/sutra_xen.commit"
echo "vendored sutra_xen -> $DEST/sutra_xen.py"
echo "  $xsha"
# The recipe layer -- vendored under the same integrity chain as code, not
# copied by hand into a pill's own Makefile. check-sutra itself checks only
# sutra.py/sutra_update.py/sutra_xen.py above; sutra.mk gets its own
# integrity+freshness anchor pair here for the same reason they do, but
# nothing currently re-verifies IT against drift the way it verifies them
# (a pill runs `include .../sutra.mk` and gets whatever's on disk) --
# `make vendor` re-running is what keeps it current, same as the others.
cp "$SRC/sutra.mk" "$DEST/sutra.mk"
msha="$(sha256sum "$SRC/sutra.mk" | cut -d' ' -f1)"
printf '%s  %s\n' "$ver" "$msha" > "$DEST/sutra.mk.version"
_sutra_write_commit_anchor "$DEST/sutra.mk.commit"
echo "vendored sutra.mk -> $DEST/sutra.mk"
echo "  $msha"

# Extension commons: pill.js lands in the EXTENSION dir (second arg), not
# bin/ — GJS imports siblings only, and the extension dir is what `make
# pill` ships to ~/.local/share/gnome-shell/extensions.
if [ $# -ge 2 ]; then
    EXTDIR="$2"
    [ -d "$EXTDIR" ] || { echo "vendor: $EXTDIR is not a directory" >&2; exit 1; }
    cp "$SRC/pill.js" "$EXTDIR/pill.js"
    psha="$(sha256sum "$SRC/pill.js" | cut -d' ' -f1)"
    printf '%s  %s\n' "$ver" "$psha" > "$EXTDIR/pill.version"
    _sutra_write_commit_anchor "$EXTDIR/pill.commit"
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
         "docs/BOOTSTRAP.md):" >&2
    cat <<EOF
# --- sutra bootstrap (sutra $ver; see docs/BOOTSTRAP.md -- do not hand-edit) ----
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
