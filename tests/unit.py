#!/usr/bin/env python3
"""Unit tests for sutra's pure helpers — load_config, write_status,
ewma_rate, runtime_paths, read_status. Run by smoke.sh with sutra on the
path. Assertion failures are the test result; a clean exit prints OK."""

import json
import os
import stat
import sys
import tempfile

import sutra


def test_load_config():
    d = {"n": 30, "f": 1.5, "b": False, "lst": [], "s": "toy"}
    c = {"n": (2, 100), "f": (0.1, 10.0)}
    pats = {"s": r"^[a-z]+$"}

    # missing file -> pure defaults
    got = sutra.load_config("/nonexistent", d, c, pats)
    assert got == d, got

    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, "cfg.json")

        def load(obj):
            with open(p, "w") as f:
                json.dump(obj, f)
            return sutra.load_config(p, d, c, pats)

        # clamping: over-hi and under-lo pinned to the bounds
        assert load({"n": 9999})["n"] == 100
        assert load({"n": 1})["n"] == 2
        assert load({"n": 50})["n"] == 50
        # type is preserved (int stays int, float stays float)
        assert isinstance(load({"n": 50})["n"], int)
        assert load({"f": 2})["f"] == 2.0 and isinstance(load({"f": 2})["f"], float)
        # bool default takes a bool, rejects a number
        assert load({"b": True})["b"] is True
        assert load({"b": 1})["b"] is False  # rejected -> default
        # a bool is NOT accepted for a numeric key (True is an int subclass)
        assert load({"n": True})["n"] == 30  # rejected -> default
        # list-of-str only
        assert load({"lst": ["a", "b"]})["lst"] == ["a", "b"]
        assert load({"lst": [1, 2]})["lst"] == []  # rejected -> default
        # string pattern gate
        assert load({"s": "abc"})["s"] == "abc"
        assert load({"s": "NOPE9"})["s"] == "toy"  # fails pattern -> default
        # unknown keys ignored, no crash
        assert "evil" not in load({"evil": "rm -rf /"})
        # a non-object top level -> pure defaults
        with open(p, "w") as f:
            f.write("[1,2,3]")
        assert sutra.load_config(p, d, c, pats) == d
        # malformed json -> pure defaults
        with open(p, "w") as f:
            f.write("{not json")
        assert sutra.load_config(p, d, c, pats) == d
    print("  load_config ok")


def test_write_status():
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, "status.json")
        sutra.write_status(p, {"v": 1, "hello": "world"}, owner=(os.getuid(), -1))
        assert not os.path.exists(p + ".tmp"), "tmp left behind"
        mode = stat.S_IMODE(os.stat(p).st_mode)
        assert mode == 0o640, oct(mode)
        with open(p) as f:
            doc = json.load(f)
        assert doc["hello"] == "world"
        # a chosen mode is honored (the no-owner 0644 fallback path)
        sutra.write_status(p, {"v": 2}, owner=None, mode=0o644)
        assert stat.S_IMODE(os.stat(p).st_mode) == 0o644
        assert sutra.read_status(p)["v"] == 2
    print("  write_status ok")


def test_authz():
    import grp
    # allow_uids: exact membership, gid ignored
    a = sutra.allow_uids({0, 1000})
    assert a(0, 999) and a(1000, 12345) and not a(1001, 1000)
    # allow_group: root always; a real existing group (the tester's own primary
    # group) admits the tester's uid; a non-existent group denies everyone but
    # root (getgrnam raises -> default deny)
    mygid = os.getgid()
    myname = grp.getgrgid(mygid).gr_name
    g = sutra.allow_group(myname)
    assert g(0, 0), "root must always pass"
    assert g(os.getuid(), 0), "own primary group should admit own uid"
    ghost = sutra.allow_group("sutra-no-such-group-xyz")
    assert ghost(0, 0) and not ghost(os.getuid(), 0), "missing group -> deny"
    print("  authz (allow_uids / allow_group) ok")


def test_ewma_rate():
    # seed: prev=None -> burn 0
    st, burn = sutra.ewma_rate(None, 1000, 100.0, 60.0)
    assert burn == 0.0 and st["v"] == 1000
    # a steady +1000/s climb: burn rises toward 1000 but is smoothed below it
    # on the first non-seed step
    st, burn = sutra.ewma_rate(st, 2000, 101.0, 60.0)
    assert 0 < burn < 1000, burn
    # many steady steps converge upward toward the true rate
    v, t = 2000, 101.0
    for _ in range(400):
        v += 1000
        t += 1.0
        st, burn = sutra.ewma_rate(st, v, t, 60.0)
    assert 950 < burn < 1000, burn
    # a decline reads as negative burn
    st, burn = sutra.ewma_rate(st, v - 5000, t + 1.0, 60.0)
    assert burn < 900, burn
    print("  ewma_rate ok")


def test_runtime_paths():
    rd, sp, sk = sutra.runtime_paths("SUTRA_TEST_NOPE_ENV", "/run/xyz")
    assert rd == "/run/xyz"
    assert sp == "/run/xyz/status.json"
    assert sk == "/run/xyz/control.sock"
    os.environ["SUTRA_TEST_ENV"] = "/tmp/over"
    rd, sp, sk = sutra.runtime_paths("SUTRA_TEST_ENV", "/run/xyz")
    assert rd == "/tmp/over" and sp == "/tmp/over/status.json"
    print("  runtime_paths ok")


if __name__ == "__main__":
    test_load_config()
    test_write_status()
    test_authz()
    test_ewma_rate()
    test_runtime_paths()
    print("UNIT OK")
    sys.exit(0)
