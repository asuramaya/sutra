#!/usr/bin/env bash
# sutra smoke: unit-test the pure helpers, then stand up toy_daemon in a
# STAGED VENDORED LAYOUT (sutra.py copied next to the daemon, imported as a
# sibling — exactly how a pill ships it) and abuse its socket. House
# tradition: make smoke.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)

# 1. pure-helper unit tests, with sutra importable from the repo root
PYTHONPATH="$ROOT" python3 tests/unit.py
PYTHONPATH="$ROOT" python3 tests/unit_update.py
PYTHONPATH="$ROOT" python3 tests/unit_xen.py

# 1b. pill.js syntax gate: a parse error in the commons bricks every pill's
# extension at load, so catch it here. node parses the module without
# resolving its gi://gnome-shell imports (which only exist in-shell —
# the extension itself is the runtime test, verified live per adoption).
if command -v node >/dev/null 2>&1; then
    node --input-type=module --check < pill.js
    echo "pill.js: syntax ok (node --check)"
else
    echo "pill.js: node not installed, syntax gate skipped"
fi

# 2. stage the vendored layout: sutra.py + toy_daemon.py side by side, run the
#    daemon from there with NO path tricks — proves `import sutra` as a sibling
RD=$(mktemp -d)
trap 'kill "${DPID:-0}" 2>/dev/null || true; rm -rf "$RD"' EXIT
mkdir -p "$RD/bin" "$RD/run"
cp "$ROOT/sutra.py" "$RD/bin/sutra.py"
cp "$ROOT/tests/toy_daemon.py" "$RD/bin/toy_daemon.py"

cat > "$RD/config.json" <<EOF
{"poll_interval": 1, "owner_uid": $(id -u), "label": "smoke", "step": 4096}
EOF

TOY_RUNTIME_DIR="$RD/run" python3 "$RD/bin/toy_daemon.py" \
    --config "$RD/config.json" &
DPID=$!

for _ in $(seq 1 40); do
    [ -s "$RD/run/status.json" ] && break
    sleep 0.25
done
[ -s "$RD/run/status.json" ] || { echo "SMOKE FAIL: no status.json"; exit 1; }

# the vendored sutra.py must be byte-identical to canonical (drift invariant)
cmp -s "$ROOT/sutra.py" "$RD/bin/sutra.py" \
    || { echo "SMOKE FAIL: vendored sutra.py drifted from canonical"; exit 1; }

python3 - "$RD/run/status.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["v"] == 1 and doc["label"] == "smoke", doc
assert doc["daemon"]["version"] == "0.0.0-toy", doc
assert isinstance(doc["used"], int) and doc["used"] >= 4096, doc
print("shape ok: toy daemon publishing via sutra.write_status")
PY

# 3. abuse the sutra ControlServer through the client (sutra.request)
PYTHONPATH="$ROOT" python3 - "$RD/run/control.sock" <<'PY'
import sutra, sys
s = sys.argv[1]
assert sutra.request(s, {"cmd": "ping"})["ok"] is True, "ping"
st = sutra.request(s, {"cmd": "status"})
assert st["label"] == "smoke", "status"
assert sutra.request(s, {"cmd": "echo", "msg": "hi"})["echo"] == "hi", "echo"
# dispatch-level hostile input: wrong type -> error, not crash
assert "error" in sutra.request(s, {"cmd": "echo", "msg": 5}), "bad echo"
# unknown command framed by the server
assert sutra.request(s, {"cmd": "rm -rf /"})["error"] == "unknown command"
# a burn read reflects the climbing 'used'
assert "burn_bps" in sutra.request(s, {"cmd": "burn"}), "burn"
print("socket ok: ping/status/dispatch/unknown via sutra.ControlServer")
PY

# 4. raw hostile bytes straight at the socket — must survive, ping still ok
PYTHONPATH="$ROOT" python3 - "$RD/run/control.sock" <<'PY'
import socket, json, sys
p = sys.argv[1]

def raw(payload):
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); c.settimeout(5)
    c.connect(p); c.sendall(payload)
    buf = b""
    while b"\n" not in buf:
        d = c.recv(65536)
        if not d:
            break
        buf += d
    c.close()
    return json.loads(buf.decode())

assert "error" in raw(b"not json at all\n"), "garbage"
assert "error" in raw(b"[1,2,3]\n"), "non-object"
assert "error" in raw(b'{"cmd":123}\n'), "non-str cmd tolerated?"  # unknown
import sutra
assert sutra.request(p, {"cmd": "ping"})["ok"] is True, "daemon died after abuse"
print("hostile ok: garbage/non-object survived, daemon alive")
PY

# 5. vendor.sh sanity: writes both the integrity (.version) and LAG/DRIFT
# (.commit) anchors, and the commit anchor matches canonical HEAD exactly.
# Only meaningful when canonical itself is clean and committed (vendor.sh
# refuses to run otherwise); skipped rather than failed when it isn't, since
# a dirty dev tree mid-edit is a normal state for this repo, not a bug.
# SUTRA_VENDOR_ALLOW_UNSIGNED=1: canonical HEAD is armed but not yet
# tag-signed (arm-before-tag — the tag is the operator's own act, never
# CI's), so vendor.sh's unsigned-tag guard would otherwise abort this
# self-check every commit until the first real signed tag lands. Same
# escape hatch vendor.sh documents for an untagged dev fix; this call
# still asserts the anchors get written and match HEAD, it just doesn't
# require a signature that can't exist yet.
VD="$RD/vendor-test"
mkdir -p "$VD"
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
   [ -z "$(git -C "$ROOT" status --porcelain -- sutra.py sutra_update.py \
       sutra_xen.py pill.js)" ]; then
    SUTRA_VENDOR_ALLOW_UNSIGNED=1 bash "$ROOT/vendor.sh" "$VD" >/dev/null
    head_commit=$(git -C "$ROOT" rev-parse HEAD)
    for f in sutra sutra_update sutra_xen; do
        [ -s "$VD/$f.version" ] || { echo "SMOKE FAIL: vendor.sh didn't write $f.version"; exit 1; }
        [ -s "$VD/$f.commit" ] || { echo "SMOKE FAIL: vendor.sh didn't write $f.commit"; exit 1; }
        # First line only: a second "unsigned" line is expected whenever
        # HEAD outruns the latest signed tag (the normal dev state, and
        # unconditionally true right after arming, before any tag exists
        # yet) -- this check is about LAG/DRIFT commit identity, not about
        # whether HEAD happens to be tag-covered at test time.
        got="$(head -n1 "$VD/$f.commit")"
        [ "$got" = "$head_commit" ] || {
            echo "SMOKE FAIL: $f.commit ($got) != canonical HEAD ($head_commit)"; exit 1; }
    done
    echo "vendor.sh ok: .version + .commit anchors match canonical HEAD ($head_commit)"
else
    echo "vendor.sh: canonical tree dirty or not a git checkout, sanity check skipped"
fi

echo "SMOKE OK"
