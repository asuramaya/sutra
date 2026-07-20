#!/usr/bin/env python3
"""Offline unit tests for sutra_update: version logic, anchor state,
manifest discovery, and the full verify_dir trust chain with real
throwaway keys (kast's fixture pattern). No network, no hardware."""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import sutra_update as su

fails = 0


def check(name, cond):
    global fails
    print(("ok: " if cond else "FAIL: ") + name)
    if not cond:
        fails += 1


# version logic
check("newer basic", su.newer("0.8.0", "0.7.1"))
check("newer multi-digit", su.newer("0.30.1", "0.9.9"))
check("not newer equal", not su.newer("1.2.3", "1.2.3"))
check("not newer older", not su.newer("0.5.0", "0.5.1"))
check("v-prefix tolerated", su.newer("v2.0.0", "1.9.9"))

# manifest discovery
check("SHA256SUMS wins", su.find_manifest(["a.tar.gz", "SHA256SUMS"]) == "SHA256SUMS")
check("dialect .sha256", su.find_manifest(["x.tar.gz.sha256", "x.tar.gz"]) == "x.tar.gz.sha256")
check("sig not manifest", su.find_manifest(["x.tar.gz.sha256.sig"]) is None)

with tempfile.TemporaryDirectory() as td:
    # anchor state
    empty = os.path.join(td, "empty")
    open(empty, "w").close()
    check("empty anchor inert", not su.armed(empty))
    check("missing anchor inert", not su.armed(os.path.join(td, "nope")))

    # trust chain with a real throwaway key
    key = os.path.join(td, "k")
    subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C",
                    "fake-master", "-f", key], check=True)
    anchor = os.path.join(td, "anchor")
    with open(key + ".pub") as f, open(anchor, "w") as a:
        kt, blob, _ = f.read().split(None, 2)
        a.write(f'testpill namespaces="testpill-release,pills-tag" {kt} {blob} fake\n')
    check("armed anchor armed", su.armed(anchor))

    work = os.path.join(td, "work")
    os.makedirs(work)
    art = os.path.join(work, "testpill.tar.gz")
    with open(art, "wb") as f:
        f.write(b"artifact bytes")
    digest = subprocess.run(["sha256sum", art], capture_output=True,
                            text=True).stdout.split()[0]
    man = os.path.join(work, "SHA256SUMS")
    with open(man, "w") as f:
        f.write(f"{digest}  testpill.tar.gz\n")
    subprocess.run(["ssh-keygen", "-Y", "sign", "-n", "testpill-release",
                    "-f", key, man], check=True, capture_output=True)

    ok, why = su.verify_dir(work, "SHA256SUMS", "SHA256SUMS.sig", anchor,
                            "testpill", True)
    check("armed verify passes", ok and "signature" in why)

    with open(art, "ab") as f:
        f.write(b"tamper")
    ok, why = su.verify_dir(work, "SHA256SUMS", "SHA256SUMS.sig", anchor,
                            "testpill", True)
    check("tampered artifact rejected", not ok and "mismatch" in why)

    with open(art, "wb") as f:
        f.write(b"artifact bytes")
    os.remove(man + ".sig")
    ok, why = su.verify_dir(work, "SHA256SUMS", None, anchor, "testpill", True)
    check("armed + unsigned fails closed", not ok and "unsigned" in why)
    ok, why = su.verify_dir(work, "SHA256SUMS", None, empty, "testpill", False)
    check("inert degrades hash-only", ok and "unarmed" in why)

print("UPDATE-UNIT " + ("OK" if fails == 0 else f"FAILED ({fails})"))
sys.exit(1 if fails else 0)
