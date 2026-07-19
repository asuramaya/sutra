#!/usr/bin/env python3
"""Adversarial fuzz of sutra.ControlServer, once, at the source — so no pill
has to re-derive that its socket survives abuse. Boots a sandboxed toy_daemon
in a staged vendored layout, throws hostile input at it in phases, and after
every phase asserts a normal command still answers. Prints PASS. Unprivileged.

The 2 real bugs aegis's coldspot fuzzer found (a wrong-type crash on the next
publish, a half-open-connection stall on the accept loop) are the reason this
lives in the backbone: fix the class once, here, and every pill inherits it.
"""

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def boot(rd):
    os.makedirs(os.path.join(rd, "bin"))
    os.makedirs(os.path.join(rd, "run"))
    shutil.copy(os.path.join(ROOT, "sutra.py"), os.path.join(rd, "bin"))
    shutil.copy(os.path.join(ROOT, "tests", "toy_daemon.py"),
                os.path.join(rd, "bin"))
    cfg = os.path.join(rd, "config.json")
    with open(cfg, "w") as f:
        json.dump({"poll_interval": 1, "owner_uid": os.getuid()}, f)
    env = dict(os.environ, TOY_RUNTIME_DIR=os.path.join(rd, "run"))
    proc = subprocess.Popen(
        [sys.executable, os.path.join(rd, "bin", "toy_daemon.py"),
         "--config", cfg], env=env)
    sock = os.path.join(rd, "run", "control.sock")
    for _ in range(80):
        if os.path.exists(sock):
            return proc, sock
        time.sleep(0.25)
    proc.kill()
    raise SystemExit("ATTACK FAIL: daemon never bound its socket")


def _connect(sock):
    # a unix socket whose accept-backlog is momentarily full answers connect
    # with EAGAIN, not a refusal — that is backpressure, not a dead daemon.
    # Retry briefly so the fuzzer measures liveness, not first-packet luck.
    last = None
    for _ in range(50):
        c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        c.settimeout(8)
        try:
            c.connect(sock)
            return c
        except BlockingIOError as exc:
            last = exc
            c.close()
            time.sleep(0.02)
    raise last


def ask(sock, payload, raw=False, half_open=False):
    c = _connect(sock)
    if half_open:
        c.sendall(b'{"cmd":')  # partial line, then just leave
        return c  # caller closes later; server must not wedge on us
    c.sendall(payload if raw else (json.dumps(payload).encode() + b"\n"))
    buf = b""
    while b"\n" not in buf:
        d = c.recv(65536)
        if not d:
            break
        buf += d
    c.close()
    return json.loads(buf.decode()) if buf else None


def alive(sock):
    return ask(sock, {"cmd": "ping"}).get("ok") is True


def main():
    rd = tempfile.mkdtemp()
    proc, sock = boot(rd)
    try:
        phases = []

        def phase(name, fn):
            fn()
            assert alive(sock), f"daemon dead after: {name}"
            phases.append(name)

        phase("oversized line (>64KiB)",
              lambda: ask(sock, b'{"cmd":"' + b"A" * 70000 + b'"}\n', raw=True))
        phase("raw garbage bytes",
              lambda: ask(sock, b"\x00\xff\xfe not json\n", raw=True))
        phase("invalid utf-8",
              lambda: ask(sock, b'{"cmd":"\xc3\x28"}\n', raw=True))
        phase("json array (non-object)", lambda: ask(sock, b"[1,2,3]\n", raw=True))
        phase("json string (non-object)", lambda: ask(sock, b'"hi"\n', raw=True))
        phase("json number (non-object)", lambda: ask(sock, b"42\n", raw=True))
        phase("deeply nested json",
              lambda: ask(sock, ("[" * 500 + "]" * 500 + "\n").encode(), raw=True))
        phase("unknown command", lambda: ask(sock, {"cmd": "nope"}))
        phase("non-string cmd", lambda: ask(sock, {"cmd": 123}))
        phase("empty object", lambda: ask(sock, {}))

        def storm():
            for _ in range(60):
                c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                try:
                    c.connect(sock)
                except BlockingIOError:
                    pass  # backlog momentarily full — that's the point
                finally:
                    c.close()
        phase("rapid connect/disconnect storm (60x)", storm)

        def half_open():
            # open several half-open connections that send a partial line and
            # never finish — a single-threaded accept loop would wedge here
            held = [ask(sock, None, half_open=True) for _ in range(5)]
            # while they hang, a normal client must still get served promptly
            assert alive(sock), "half-open stalled the accept loop"
            for c in held:
                c.close()
        phase("half-open / slow-drip clients", half_open)

        print(f"  phases passed: {len(phases)}")
        for p in phases:
            print(f"    ✔ {p}")
        print("PASS")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(rd, ignore_errors=True)


if __name__ == "__main__":
    main()
