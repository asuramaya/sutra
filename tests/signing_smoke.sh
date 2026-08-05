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

if [ "$FAIL" -eq 0 ]; then
    echo "SIGNING SMOKE OK"
else
    exit 1
fi
