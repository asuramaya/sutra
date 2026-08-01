# Architecture

sutra is the pill family's shared runtime backbone. It has no daemon, no CLI,
and no GNOME extension of its own — it is the source five files are vendored
byte-identical *out of*, into each pill's private lib dir, so a fix (especially
a security fix to the control socket) lands once instead of six times. See the
README for what each of those five files does; this document is about how the
repo itself is laid out and why.

## Repo map

```
sutra.py           the backbone: ControlServer, config, status, health, notify
sutra_update.py    the family's update spine (trust chain, consent tiers)
sutra_xen.py       the Xen guest-surface reader (virt detection, balloon, host telemetry)
pill.js            the GNOME extension commons, vendored into each pill's extension dir
vendor.sh          copies the five product files above into a pill's private lib dir,
                    with drift anchors
docs/              this file, USAGE.md, RELEASING.md, BOOTSTRAP.md (the install-path
                    bootstrap and the canonical check-sutra recipe), CHANGELOG.md
packaging/         VERSION -- the repo's own release counter
tests/             unit.py, unit_update.py, unit_xen.py, attack_socket.py (adversarial
                    fuzz), check_version.sh, smoke.sh, toy_daemon.py (a whole tiny pill
                    built on sutra, the reference example for consumers)
.github/           ci.yml, and the three community files (CODE_OF_CONDUCT.md,
                    CONTRIBUTING.md, SECURITY.md)
```

## Conventions worth knowing before you edit

* **Stdlib-only, always.** Pills vendor sutra byte-identical rather than
  `pip install`ing it; a dependency sutra doesn't already have is a dependency
  no pill can bring in through here.
* **`vendor.sh` writes into a pill's *private* lib dir, never a shared
  `bin/`.** Two pills vendoring identically-named `sutra.py` into the same
  shared directory make each other uninstallable (`dpkg` refuses the second
  outright; `install.sh` silently overwrites). Ruling `3e44bd95`; the fix and
  the small `sys.path` bootstrap preamble every consumer needs are in
  `docs/BOOTSTRAP.md`.
* **Per-file version constants are a second, deliberate version axis**,
  independent of `packaging/VERSION` — see the exemptions table below, this
  isn't the family's usual single-version-constant shape.
* **The check-sutra recipe every pill runs against this repo is published
  canonically in `docs/BOOTSTRAP.md`**, same pattern as the bootstrap
  preamble: sutra authors it once, correctly, so five pills copy one thing
  instead of independently re-deriving it (and getting it wrong five
  different ways — the row-count arithmetic and the vendor path both already
  went through that once). It compares each vendored file against *that
  file's own* last-modifying commit in canonical history, never sutra's repo
  HEAD, which advances on every commit including ones that never touch the
  file (decision `325b1969`, correcting `d51e090f`'s original recipe, which
  false-positived a LAG warning across the whole family the first time a
  docs-only commit landed).
* Free software, GPLv3-or-later, no telemetry.

## Commit signing

The family signs **release tags and released packages**, never individual
commits — dev commits across every pill, sutra included, go unsigned. sutra's
founding commit (`ecfb4ca`) is hardware-signed and verifies, but that's a
historical artifact — a founding act for the commons' first commit — not a
policy that every commit since should have followed. A repo-local git config
requiring per-commit signing briefly existed here and never actually produced
a second signed commit in this repo's history; it's gone now, not sitting
unenforced.

This isn't a gap in vendoring integrity. `.version`'s sha256 is the integrity
hard gate ("this copy was not hand-edited"); `.commit` is the freshness
marker for the LAG-vs-DRIFT read ("is this copy at or after the file's own
last commit"). Neither one was ever an authenticity claim, and neither needs
a signed commit to do its job — authenticity, when it matters, belongs at the
tag/release boundary, which is also where the operator's sealing ritual
already lives (see `docs/RELEASING.md`).

## Standard exemptions

sutra's declared departures from the family repo standard. Anything the
standard asks for and sutra doesn't have is listed here. A gap that isn't in
this table is a bug, not a choice.

| Item | Why |
|---|---|
| `sutra.py`, `sutra_update.py`, `sutra_xen.py`, `pill.js`, `vendor.sh` stay at repo root, not under `src/` | sutra is a vendoring commons, not an application — for every other pill, `src/` answers "what IS this thing" and the answer is a program; for sutra the answer *is* those five files, and burying them under `src/` to buy two root rows inverts what the row count exists to communicate. Four sibling pills' `check-sutra` also read them by their literal root-relative path (e.g. `git -C "$canon" log -1 --format=%H -- sutra.py`), so moving the path is a five-repo coordinated change, not a cosmetic one inside this repo alone. |
| no `install.sh` / `uninstall.sh` | sutra has no standalone install — it ships no daemon, CLI, or extension of its own to put on a machine. It is consumed only by copying (`make vendor`, i.e. `vendor.sh`) into another pill's tree; there is no "front door" here to write one for. |
| no `src/`, no man page | follows from the row above — there is no CLI surface here to organize under `src/bin`/`src/data`/`src/extension` or to document with a man page. |
| per-file version constants (`SUTRA_VERSION`, `SUTRA_UPDATE_VERSION`, `SUTRA_XEN_VERSION`, `PILL_JS_VERSION`) exist alongside `packaging/VERSION` | deliberate, ruled, and mechanically enforced (`make check-version`, `tests/check_version.sh`) — not the drift the family's single-version-constant rule exists to catch. `packaging/VERSION` is the repo's own release counter; each vendored file's constant tracks that file's own content history independently, because pills vendor and freshness-check each file on its own timeline, not the whole repo's at once. See `.github/CONTRIBUTING.md` and `docs/BOOTSTRAP.md`. |
| no `.github/workflows/release.yml` yet | sutra has never cut a tagged release. Under the operator's ruling, sealing is blocked until sutra and mudra converge on this same repo-structure pass — writing release machinery ahead of that would be a ceremony with nothing yet licensed to run it. |
