#!/usr/bin/env python3
"""toy_daemon — a minimal pill built entirely on sutra.

Two jobs: it is sutra's own end-to-end test fixture, and it is the reference
example of how a real pill consumes the backbone — `import sutra` as a sibling
(exactly the vendored layout: sutra.py sits next to the daemon), a DEFAULTS/
CLAMPS pair, a dispatch callable, and the tiny main loop. Copy this shape.
"""

import argparse
import os
import time

import sutra

VERSION = "0.0.0-toy"

DEFAULTS = {
    "poll_interval": 1,
    "burn_tau": 60,
    "owner_uid": 1000,
    "step": 1000,          # fake "used" bytes added per tick, for ewma_rate
    "label": "toy",        # a validated string
    "verbose": False,      # a bool
    "tags": [],            # a list-of-str
}
CLAMPS = {
    "poll_interval": (1, 3600),
    "burn_tau": (5, 86400),
    "owner_uid": (0, 2 ** 31),
    "step": (0, 10 ** 9),
}


def main():
    ap = argparse.ArgumentParser(prog="toy_daemon")
    ap.add_argument("--config", default="/nonexistent")
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()

    cfg = sutra.load_config(args.config, DEFAULTS, CLAMPS,
                            str_patterns={"label": r"^[a-z]+$"})
    runtime_dir, status_path, sock_path = sutra.runtime_paths(
        "TOY_RUNTIME_DIR", "/run/toy")
    os.makedirs(runtime_dir, exist_ok=True)
    uid = cfg["owner_uid"] if os.getuid() == 0 else os.getuid()

    stop = sutra.stop_event()
    latest = {"doc": {"error": "no status yet"}}

    def get_status():
        return latest["doc"]

    def dispatch(cmd, req):
        if cmd == "echo":
            msg = req.get("msg")
            if not isinstance(msg, str):
                raise ValueError("msg must be a string")
            return {"echo": msg}
        if cmd == "burn":
            return {"burn_bps": latest["doc"].get("burn_bps")}
        return None  # unknown -> the server frames {"error": "unknown command"}

    ctl = sutra.ControlServer(sock_path, sutra.allow_uids({0, uid}), VERSION,
                              dispatch, get_status, socket_owner=(uid, -1))
    ctl.start()

    used = 0
    st = None
    while not stop.is_set():
        now = time.time()
        used += cfg["step"]
        st, burn = sutra.ewma_rate(st, used, now, cfg["burn_tau"])
        doc = {
            "v": 1, "ts": now,
            "daemon": {"version": VERSION, "pid": os.getpid(),
                       "poll_interval": cfg["poll_interval"]},
            "label": cfg["label"], "used": used, "burn_bps": round(burn, 1),
        }
        latest["doc"] = doc
        sutra.write_status(status_path, doc, owner=(cfg["owner_uid"], -1))
        if args.once:
            break
        stop.wait(cfg["poll_interval"])


if __name__ == "__main__":
    main()
