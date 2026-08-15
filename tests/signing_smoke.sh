#!/usr/bin/env bash
# tests/signing_smoke.sh -- fixture-only, no network, no real keys (same
# doctrine as mudra's tests/smoke.sh: throwaway ed25519 keys stand in for
# the operator's hardware key). Proves vendor.sh's signed-canonical guard
# and check-sutra's provenance line actually DISTINGUISH signed from
# unsigned canonical state -- not just that the code runs without crashing.
#
# NEGATIVE CONTROL FIRST, on purpose: a guard that only ever sees the good
# case can't tell you it detects the bad one. Runs vendor.sh and check-sutra
# for real, against a real fixture git repo with a real (fixture) SSH-signed
# tag -- never mocked.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
say() { echo "$@"; }
die() { echo "SMOKE FAIL: $*" >&2; FAIL=1; }

command -v ssh-keygen >/dev/null || { echo "signing_smoke: no ssh-keygen, skipping"; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/keys" "$T/canon/packaging/release-signing" "$T/pill/lib"
ssh-keygen -q -t ed25519 -N '' -C "fake-master-1" -f "$T/keys/id_fake_1"
ssh-keygen -q -t ed25519 -N '' -C "attacker" -f "$T/keys/id_attacker"

# Fixture canonical carries the REAL vendor.sh and sutra.mk under test;
# the four vendored product files are content-free stand-ins -- this test
# is about the guard and the anchor chain, not about sutra.py's own logic.
( cd "$T/canon" && git init -q . \
  && git config user.email s@s && git config user.name s \
  && echo 0.0.1 > packaging/VERSION \
  && for f in sutra.py sutra_update.py sutra_xen.py pill.js; do echo "# $f fixture" > "$f"; done \
  && cp "$HERE/sutra.mk" sutra.mk \
  && cp "$HERE/vendor.sh" vendor.sh \
  && touch packaging/release-signing/allowed_signers \
  && git add -A && git commit -qm init )

cat > "$T/pill/Makefile" <<'EOF'
PILL := fakepill
include lib/sutra.mk
EOF

run_check_sutra() {
    ( cd "$T/pill" && make check-sutra "_SUTRA_CANON=$T/canon" 2>&1 )
}

# --- 1. UNARMED canonical (empty allowed_signers): vendoring is INERT, not
# refused -- there is no key to check against yet, same doctrine as
# sutra_update.py's own armed(). This is today's real state for every pill
# until the anchor is armed, so it must keep working unchanged. ------------
rm -rf "$T/dest1"; mkdir -p "$T/dest1"
if ( cd "$T/canon" && bash vendor.sh "$T/dest1" ) >"$T/log1" 2>&1; then
    say "vendor.sh: unarmed canonical vendors normally (pre-arming, inert)"
else
    die "unarmed canonical refused to vendor -- should be inert, not blocking"
fi

# --- 2. ARM the anchor with the fixture key -------------------------------
( cd "$T/canon" && printf 'sutra namespaces="sutra-release,git" %s %s fake\n' \
      "$(awk '{print $1}' "$T/keys/id_fake_1.pub")" "$(awk '{print $2}' "$T/keys/id_fake_1.pub")" \
      > packaging/release-signing/allowed_signers \
  && git add -A && git commit -qm "arm signing anchor" )

# --- 3. NEGATIVE CONTROL: armed anchor, HEAD has no signed tag -- MUST
# refuse. Proved before the positive case, on purpose (Alfred's standing
# instruction, msg 3744): a check that only ever sees the good case cannot
# tell you it detects the bad one. --------------------------------------
rm -rf "$T/dest2"; mkdir -p "$T/dest2"
if ( cd "$T/canon" && bash vendor.sh "$T/dest2" ) >"$T/log2" 2>&1; then
    die "vendor.sh vendored an UNSIGNED commit against an ARMED anchor -- the guard did not fire"
else
    if [ -z "$(ls -A "$T/dest2" 2>/dev/null)" ]; then
        say "vendor.sh: NEGATIVE CONTROL ok -- refuses an unsigned commit against an armed anchor, nothing written"
    else
        die "vendor.sh refused but left partial files in dest2: $(ls "$T/dest2")"
    fi
fi

# --- 4. BYPASS: SUTRA_VENDOR_ALLOW_UNSIGNED=1 vendors anyway, WARNS, and
# records "unsigned" as a second line in every .commit anchor. -------------
rm -rf "$T/dest3"; mkdir -p "$T/dest3"
if out=$( cd "$T/canon" && SUTRA_VENDOR_ALLOW_UNSIGNED=1 bash vendor.sh "$T/dest3" 2>&1 ); then
    if echo "$out" | grep -q "WARNING"; then
        say "vendor.sh: bypass warns to stderr"
    else
        die "bypass vendored silently -- no WARNING printed"
    fi
    if [ "$(sed -n '2p' "$T/dest3/sutra.commit")" = "unsigned" ]; then
        say "vendor.sh: bypass records 'unsigned' as .commit's second line"
    else
        die "bypass did not record the unsigned marker in sutra.commit"
    fi
else
    die "SUTRA_VENDOR_ALLOW_UNSIGNED=1 still refused to vendor"
fi

cp "$T/dest3"/* "$T/pill/lib/"
out="$(run_check_sutra)"
if echo "$out" | grep -q "provenance WARN.*SUTRA_VENDOR_ALLOW_UNSIGNED=1"; then
    say "check-sutra: reports the bypass marker (static, no canonical checkout needed)"
else
    die "check-sutra did not report the bypass marker:"$'\n'"$out"
fi
if echo "$out" | grep -q "provenance WARN.*not reachable from any signed tag"; then
    say "check-sutra: live check independently confirms unreachable-from-any-tag"
else
    die "check-sutra's live provenance check did not warn on an unsigned commit:"$'\n'"$out"
fi
if echo "$out" | grep -qE "provenance FAIL|^check-sutra FAIL.*provenance"; then
    die "provenance produced a FAIL -- it must never be more than a warning (Alfred's instruction)"
fi

# --- 5. POSITIVE CONTROL: tag+sign the SAME HEAD dest3 was vendored from,
# with the fixture key already in the armed anchor -- must now read ok. ---
( cd "$T/canon" && git -c gpg.format=ssh -c user.signingkey="$T/keys/id_fake_1" \
      tag -s v0.0.2 -m "checkpoint" )
out="$(run_check_sutra)"
if echo "$out" | grep -q "provenance ok.*signed tag v0.0.2"; then
    say "check-sutra: POSITIVE CONTROL ok -- retroactive signed tag flips the live check to ok"
else
    die "signed tag present but check-sutra did not report provenance ok:"$'\n'"$out"
fi
# The static per-vendor marker is a fact about vendor TIME and must NOT
# change retroactively -- only the live check should move.
if [ "$(sed -n '2p' "$T/pill/lib/sutra.commit")" = "unsigned" ]; then
    say "check-sutra: static bypass marker stays 'unsigned' even after retroactive signing (correct -- it's a vendor-time fact)"
else
    die "the static unsigned marker changed after tagging -- it must record vendor-time fact only"
fi

# --- 6. Vendoring straight onto the now-signed HEAD needs no bypass. ------
rm -rf "$T/dest4"; mkdir -p "$T/dest4"
if ( cd "$T/canon" && bash vendor.sh "$T/dest4" ) >"$T/log4" 2>&1; then
    if [ "$(sed -n '2p' "$T/dest4/sutra.commit" 2>/dev/null)" = "unsigned" ]; then
        die "a clean vendor off a signed HEAD still carries the unsigned marker"
    else
        say "vendor.sh: vendoring a signed HEAD needs no bypass, no marker written"
    fi
else
    die "vendor.sh refused to vendor a properly signed HEAD"
fi

# --- 7. ADVERSARIAL: a tag signed by a key NOT in the allowed_signers file
# must not satisfy the guard -- proves this isn't "any signature passes". -
( cd "$T/canon" && echo "# another dev fix" >> sutra.py && git add -A \
  && git commit -qm "unsigned again" \
  && git -c gpg.format=ssh -c user.signingkey="$T/keys/id_attacker" \
       tag -s vbad -m "attacker tag" )
rm -rf "$T/dest5"; mkdir -p "$T/dest5"
if ( cd "$T/canon" && bash vendor.sh "$T/dest5" ) >"$T/log5" 2>&1; then
    die "vendor.sh accepted a tag signed by a key NOT in allowed_signers"
else
    say "vendor.sh: ADVERSARIAL ok -- a tag from an unlisted key does not satisfy the guard"
fi

# --- 8. SUTRA_VENDOR_KEY_HOME: an off-repo key directory, independent of
# the in-repo anchor (msg 3775 via Alfred) -- trust-on-first-use in the
# in-repo anchor means an attacker who owns the repo can replace the
# anchor AND sign with their own key; a key living entirely outside the
# repo cannot be touched that way. Uses its OWN keys (never the ones
# already armed above) to prove this is a genuinely separate root, not
# just re-checking the same anchor under a different name. ---------------
mkdir -p "$T/keyhome" "$T/inrepo2"
ssh-keygen -q -t ed25519 -N '' -C "keyhome-key" -f "$T/keyhome/id_kh"
ssh-keygen -q -t ed25519 -N '' -C "inrepo2-key" -f "$T/inrepo2/id_ir"
( cd "$T/canon" && printf 'sutra namespaces="sutra-release,git" %s %s inrepo2\n' \
      "$(awk '{print $1}' "$T/inrepo2/id_ir.pub")" "$(awk '{print $2}' "$T/inrepo2/id_ir.pub")" \
      > packaging/release-signing/allowed_signers \
  && git add -A && git commit -qm "re-arm with a fresh in-repo key" )

# 8a. Tag signed by the KEY-HOME key (not in the in-repo anchor at all) --
# must verify via the key home, labeled as the stronger root.
( cd "$T/canon" && git -c gpg.format=ssh -c user.signingkey="$T/keyhome/id_kh" \
      tag -s v0.0.3 -m "key-home signed" )
rm -rf "$T/dest6"; mkdir -p "$T/dest6"
out=$( cd "$T/canon" && SUTRA_VENDOR_KEY_HOME="$T/keyhome" bash vendor.sh "$T/dest6" 2>&1 )
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "strong root"; then
    say "vendor.sh: SUTRA_VENDOR_KEY_HOME ok -- verifies against an off-repo key the in-repo anchor never had, labeled 'strong root'"
else
    die "SUTRA_VENDOR_KEY_HOME did not verify a tag signed by its own key:"$'\n'"$out"
fi

# 8b. Same HEAD, key home unset -- falls back to the in-repo anchor's OWN
# key (v0.0.3 wasn't signed by it, but a fresh commit+tag with it should
# still pass through the fallback path, labeled as the weaker check).
( cd "$T/canon" && echo "# fallback probe" >> sutra.py && git add -A \
  && git commit -qm "fallback probe" \
  && git -c gpg.format=ssh -c user.signingkey="$T/inrepo2/id_ir" tag -s v0.0.4 -m "in-repo signed" )
rm -rf "$T/dest7"; mkdir -p "$T/dest7"
out=$( cd "$T/canon" && bash vendor.sh "$T/dest7" 2>&1 )
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "weaker, trust-on-first-use"; then
    say "vendor.sh: SUTRA_VENDOR_KEY_HOME unset -- falls back to the in-repo anchor, labeled 'weaker'"
else
    die "unset SUTRA_VENDOR_KEY_HOME did not fall back correctly:"$'\n'"$out"
fi

# 8c. Key home SET but pointing at a directory with an UNRELATED key, and
# HEAD genuinely unsigned by anything in either root -- must still refuse
# (negative control for the new code path specifically, not just reusing
# case 3's fixture).
mkdir -p "$T/wrong_kh"
ssh-keygen -q -t ed25519 -N '' -C "wrong-key" -f "$T/wrong_key"
cp "$T/wrong_key.pub" "$T/wrong_kh/"
( cd "$T/canon" && echo "# unsigned again" >> sutra.py && git add -A && git commit -qm "unsigned once more" )
rm -rf "$T/dest8"; mkdir -p "$T/dest8"
if ( cd "$T/canon" && SUTRA_VENDOR_KEY_HOME="$T/wrong_kh" bash vendor.sh "$T/dest8" ) >"$T/log8" 2>&1; then
    die "vendor.sh vendored an unsigned commit with SUTRA_VENDOR_KEY_HOME pointed at an unrelated key"
else
    say "vendor.sh: SUTRA_VENDOR_KEY_HOME negative control ok -- an unrelated off-repo key does not satisfy the guard either"
fi

# --- 9. HONESTY CHECK: ssh-keygen missing must report CANNOT-VERIFY /
# UNKNOWN, never a confident "not signed"/"not reachable" (msg 4573 via
# Alfred: a monitor must not report a confident NO when the truth is
# COULDN'T-TELL). git verify-tag with gpg.format=ssh shells out to
# ssh-keygen internally -- without it, a genuinely, validly signed tag
# fails identically to an actually-unsigned one. Reproduced BEFORE fixing
# (bash -x against the pre-fix vendor.sh, by hand, off this suite): the
# same fixture below read "canonical HEAD has no signed tag covering it.
# Tag and sign it first" for a tag that was, in fact, already correctly
# signed -- proving this isn't a strawman before the fix landed. -----------
mkdir -p "$T/noskg"
for b in bash sh git awk sed cat grep sha256sum tr cut mktemp printf true false \
         dirname pwd basename ls rm mkdir head make; do
    p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$T/noskg/$b"
done
( cd "$T/canon" && echo "# ssh-keygen honesty probe" >> sutra.py && git add -A \
  && git commit -qm "probe commit" \
  && git -c gpg.format=ssh -c user.signingkey="$T/inrepo2/id_ir" tag -s v0.0.5 -m "genuinely signed" )
# Ground truth, checked WITH ssh-keygen present -- the fixture must be
# real before it's used to prove anything about its absence.
if ! ( cd "$T/canon" && git -c gpg.format=ssh \
       -c gpg.ssh.allowedSignersFile=packaging/release-signing/allowed_signers \
       verify-tag v0.0.5 ) >/dev/null 2>&1; then
    die "ssh-keygen honesty fixture is broken -- v0.0.5 should verify cleanly with ssh-keygen present"
fi
rm -rf "$T/dest9"; mkdir -p "$T/dest9"
out=$( cd "$T/canon" && env -i PATH="$T/noskg" HOME="$HOME" bash vendor.sh "$T/dest9" 2>&1 )
rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q "CANNOT VERIFY"; then
    say "vendor.sh: ssh-keygen-missing ok -- reports CANNOT VERIFY (unknown), not a false 'no signed tag'"
else
    die "vendor.sh did not distinguish ssh-keygen-missing from unsigned:"$'\n'"$out"
fi
if echo "$out" | grep -qi "no signed tag covering"; then
    die "vendor.sh's ssh-keygen-missing message still claims 'no signed tag covering it' -- the honesty bug is back"
fi

# Same check for check-sutra's live provenance line: vendor a fresh,
# genuinely-signed copy (ssh-keygen present), then re-run check-sutra with
# ssh-keygen unavailable and confirm it reads "provenance unknown", not
# "provenance WARN ... not reachable".
rm -rf "$T/dest9b"; mkdir -p "$T/dest9b"
( cd "$T/canon" && bash vendor.sh "$T/dest9b" ) >/dev/null 2>&1
cp "$T/dest9b"/* "$T/pill/lib/"
out=$( cd "$T/pill" && env -i PATH="$T/noskg" HOME="$HOME" make check-sutra "_SUTRA_CANON=$T/canon" 2>&1 )
if echo "$out" | grep -q "provenance unknown.*ssh-keygen not available"; then
    say "check-sutra: ssh-keygen-missing ok -- reports provenance unknown, not a false 'not reachable'"
else
    die "check-sutra did not distinguish ssh-keygen-missing from unreachable:"$'\n'"$out"
fi
if echo "$out" | grep -q "not reachable from any signed tag"; then
    die "check-sutra's ssh-keygen-missing case still claims 'not reachable from any signed tag'"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "SIGNING SMOKE OK"
else
    exit 1
fi
