# Contributing to sutra

Thanks for your interest! sutra is the pill family's shared runtime backbone —
vendored byte-identical into six (and counting) daemons — so a change here
fans out everywhere at once. Keep changes small, conservative, and justified
by a real consumer; see the README's "What sutra does not own" section
before proposing new surface.

## Project layout

```
sutra.py          the backbone: ControlServer, config, status, health, notify
sutra_update.py    the family's update spine (trust chain, consent tiers)
sutra_xen.py       the Xen guest-surface reader (virt detection, balloon, host telemetry)
pill.js            the GNOME extension commons (JS, vendored into each pill's extension dir)
vendor.sh          copies the above into a pill's private lib dir, with drift anchors
BOOTSTRAP.md        the sys.path preamble every pill binary needs to find its vendored copies
tests/             unit suites + attack_socket.py (adversarial fuzz)
```

## Dev setup

No build step, stdlib-only. Run the test suites directly:

```bash
make smoke          # unit tests + a staged vendored-layout daemon boot
make attack         # adversarial socket fuzz
make check-version  # a changed file's own version constant moved too
make check          # all three
```

## Before opening a PR

- `make check` passes (`smoke` + `attack` + `check-version`).
- Stay **stdlib-only** — sutra is vendored, not `pip install`ed; a pill can't
  bring in a dependency sutra doesn't already have.
- A new function belongs here only if **multiple pills need it verbatim**.
  sutra's value is a *low* rate of change — API growth is ruling-gated, not
  a PR-by-PR decision. Non-Linux platform support is ruled out entirely
  (the portable artifact is the protocol, never the runtime); any
  kernel-shaped code stays confined to its own module (`sutra_xen.py` is the
  precedent), never mixed into the middle of a shared rule.
- Any new socket/config surface is hostile-input tested (see
  `tests/attack_socket.py`'s fuzz phases) — `ControlServer` runs inside root
  daemons on a local socket; untrusted input must never crash it.
- Bump the touched file's own version constant. Each file's constant
  (`SUTRA_VERSION`, `SUTRA_UPDATE_VERSION`, ...) tracks that file's own
  content history, independent of the repo's release counter in `VERSION` —
  see CHANGELOG.md for the full convention.

## License

By contributing you agree your contributions are licensed under
**GPL-3.0-or-later**, matching the project.
