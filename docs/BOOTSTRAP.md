# The install-path bootstrap

Every pill vendors `sutra.py`, `sutra_update.py` and `sutra_xen.py`
byte-identical into a shared system directory — `/usr/bin` via `.deb`,
`/usr/local/bin` (or `$PREFIX/bin`) via `install.sh` — under the same
filenames. That makes any two pills installed on the same machine collide:
`dpkg` refuses the second package outright (it already owns
`/usr/bin/sutra.py`); `install.sh`'s plain `install` has no ownership
tracking and silently overwrites, anchors included. Measured, not
theorised: on the operator's own machine `/usr/bin/sutra.py` and
`/usr/local/bin/sutra.py` were already two different canonical commits,
and `/usr/bin` carried no `.version`/`.commit` anchors at all, so nothing
on the machine could detect the mix. Ruling: decision `3e44bd95`.

## The fix

1. **Vendored copies move to a private, per-pill directory**:
   `<prefix>/share/<pill>/lib/` — `/usr/share/<pill>/lib/` for `.deb`,
   `$PREFIX/share/<pill>/lib/` for `install.sh`, off the *same* `$PREFIX`
   the binaries already use. `.version`/`.commit` land there too, always
   — a directory with no anchors is exactly how the mix on the operator's
   machine went undetected.
2. **Every binary that imports sutra gets a small bootstrap preamble**
   instead of relying on being co-located with `sutra.py` (Python
   auto-adds a running script's own directory to `sys.path`; that's the
   only reason co-location ever worked, and it stops working the moment
   `sutra.py` moves out from beside the binary).
3. **The bootstrap is itself canonical.** sutra publishes the exact text
   below; every pill pastes it verbatim. Six hand-derived versions would
   trade one re-derivation surface for another — get the relative-path
   arithmetic slightly wrong, or forget the idempotency check, in only
   one of six repos, and you have a silent, repo-specific ImportError
   waiting for whoever touches that pill next.
4. **`pill.js` is exempt.** It already installs per-pill under
   `<prefix>/share/<pill>/extension/<uuid>/` and cannot collide — nothing
   to change there.

## The canonical preamble

Generate it (the pill name is the only thing that varies):

```sh
bash vendor.sh <dest-lib-dir> --bootstrap=<pill-name>
```

which prints a preamble of this shape (not reproduced here as a fixed
transcript — `<ver>` is filled in from `packaging/VERSION` at generation
time, so it moves on every release; a hand-copied number in this doc
would go stale at the very next bump and stay stale forever after, the
same class of defect this document exists to stop recreating. Run the
command above and paste what it actually prints):

```python
# --- sutra bootstrap (sutra <ver>; see docs/BOOTSTRAP.md -- do not hand-edit) ---
import os as _os
import sys as _sys
_PILL = "<pill-name>"
_libdir = _os.path.join(
    _os.path.dirname(_os.path.dirname(_os.path.realpath(__file__))),
    "share", _PILL, "lib")
if _libdir not in _sys.path:
    _sys.path.insert(0, _libdir)
del _os, _sys, _libdir, _PILL
# --- end sutra bootstrap ----------------------------------------------------
```

`<ver>` is not a drift signal — it records which sutra a binary's
preamble came FROM. Pills legitimately show different, older numbers
(0.11.1, 0.10.1, 0.8.0, ...) here forever; that's each pill's own vendor
moment, not lag.

Paste it at the top of **every** binary in the pill that does `import
sutra` (the main daemon, `<pill>-update`, `<pill>-healthcheck`, ...),
immediately before the `import sutra` line. Same text in every binary
within one pill — `_PILL` is the only line that ever changes, and only
between pills, never within one.

Why it works from any prefix without being told what the prefix is: it
locates the lib dir *relative to wherever this binary itself actually
is* (`dirname(dirname(realpath(__file__)))` is `$PREFIX`, whether that's
`/usr` from a `.deb` or `/usr/local` — or anything else — from
`install.sh`), then joins `share/<pill>/lib`. It never needs `$PREFIX`
handed to it and never hardcodes one. Verified against a simulated
co-install of two pills under one prefix, and separately under two
different prefixes, before publishing — not just reasoned through.

## The recipe layer: sutra.mk

The bootstrap preamble above gets a binary importing the right file.
Verifying it *stays* right — integrity, freshness, and that a running
binary actually resolved to the vendored copy, not a stale sibling — is
the other half, and it has the same re-derivation problem the preamble
had: left to each pill, five pills wrote five variants of the same
~100 lines, and every real divergence the family has hit since has been
in this recipe layer, never in the vendored code itself (which has a
hash anchor and cannot silently drift — see docs/ARCHITECTURE.md).
`sutra.mk` is that recipe layer published once and vendored like code,
under its own `.version`/`.commit` anchor pair — see the file's own
header for the include mechanics and every pilot correction it has
absorbed since.

**This is the adopted route.** A pill's root `Makefile`:

```makefile
PILL := <pill-name>
SUTRA_EXT_DIR := src/extension/<pill-name>@asuramaya   # only if the pill vendors pill.js
SUTRA_CHECK_BINS := <bin> <bin> <bin>:sutra_update      # every binary that imports sutra
include src/share/<pill-name>/lib/sutra.mk
```

`PILL` must be set before the `include` line; everything sutra.mk needs
after that resolves relative to its *own* vendored location
(`$(lastword $(MAKEFILE_LIST))` at include-time), never to the including
Makefile's. The fully-adopted reference, nothing hand-rolled left, is
`ramstein/Makefile:10-36`:

```makefile
PILL := ramstein
SUTRA_EXT_DIR := src/extension/ramstein@asuramaya
SUTRA_CHECK_BINS := src/bin/ramsteind src/bin/ramstein src/bin/ramstein-healthcheck src/bin/ramstein-update:sutra_update
include src/share/ramstein/lib/sutra.mk
```

The include brings in `check-sutra` (integrity + freshness for the
vendored `.py` files, and `pill.js` when `SUTRA_EXT_DIR` is set) and
`check-vendored-path` / `check-vendored-path-all` (proves a real binary's
import actually *resolved* to the vendored copy — a file-exists check at
the expected path is a weaker claim, and the gap between the two is a
real regression sutra.mk's own header documents). None of these take a
pill-supplied guess for the thing that genuinely varies per pill — three
real adoptions have already hit why, below.

### Three things sutra.mk deliberately has no default for

1. **`SUTRA_CHECK_BIN` / `SUTRA_CHECK_BINS` — which binary actually
   imports sutra.** Not `src/bin/$(PILL)`: measured across five pills,
   that guess is wrong for two of them — kast's `src/bin/kast` is the
   bash CLI (only `kast-update` imports sutra); phanspeed's
   `src/bin/phanspeed` has the same shape. A default wrong 40% of the
   time is a trap, not a default — the failure it produces reads as "the
   vendor is broken" when the real problem is "named the wrong binary"
   (defect 5, msg 2787). Name every sutra-importing binary explicitly;
   reach for `SUTRA_CHECK_BINS` (space-separated, each entry `path` or
   `path:module`) the moment there's more than one.
2. **`SUTRA_CHECK_ARGS` — no flag is safe by assumption.** The first cut
   defaulted to `--help` as universally safe. It is not: three of
   ramstein's four binaries hand-roll their own argument parsing instead
   of using `argparse`, so an unrecognized `--help` falls through to
   their *default verb* — for `ramstein`/`ramstein-healthcheck` that
   means `make check` makes a REAL socket call to the LIVE daemon, every
   run. Harmless under ramstein's own security model; a pill whose
   default verb has a non-idempotent side effect would have this guard
   perform it silently, forever. Left empty (the default), the
   real-subprocess sanity call is skipped entirely and the guard relies
   only on the resolution check, which never calls the binary's `main()`
   and is safe regardless of how it parses arguments. Set it only to a
   flag *that binary's own author* has verified is safe and idempotent —
   phanspeed's `--selftest`/`--check` is the model, not a generic flag
   picked from habit.
3. **`pill.js` needs `SUTRA_EXT_DIR` set, not a hand-extended loop.** The
   fallback recipe below predates sutra.mk and says to extend its own
   `for mod in ...` line if you vendor `pill.js` — correct only if you
   are actually using that raw shell fallback. Under `sutra.mk`, setting
   `SUTRA_EXT_DIR` to the pill's extension directory opts `check-sutra`
   into covering `pill.js` natively; leaving it unset (the default)
   skips it, exactly as a pill with no extension should. Hand-extending
   a loop *underneath* sutra.mk instead of setting this variable
   reintroduces the exact gap defect 1 closed, invisibly.

## The hand-written fallback recipe (no Makefile)

Everything above assumes a pill can `include` a Makefile. A pill that
cannot still needs the same integrity + freshness verification
`sutra.mk`'s `check-sutra` provides — this is that logic in raw shell,
kept for that case only. **Prefer `sutra.mk` above whenever a Makefile is
available**: this form has none of `sutra.mk`'s conventions
(`SUTRA_EXT_DIR`, `SUTRA_CHECK_BIN`/`SUTRA_CHECK_BINS`, the three
no-default traps above, `check-vendored-path`) built in — you carry that
plumbing yourself, by hand, which is exactly the re-derivation problem
`sutra.mk` exists to close.

```makefile
check-sutra:
	@canon="$$HOME/code/REPOS/sutra"; \
	fail=0; \
	for mod in sutra sutra_update sutra_xen; do \
	    py="<dest-lib-dir>/$$mod.py"; ver="<dest-lib-dir>/$$mod.version"; cmt="<dest-lib-dir>/$$mod.commit"; \
	    v=$$(cut -d' ' -f1 "$$ver"); \
	    sha=$$(awk '{print $$NF}' "$$ver"); \
	    actual=$$(sha256sum "$$py" | cut -d' ' -f1); \
	    if [ "$$sha" != "$$actual" ]; then \
	        echo "check-sutra FAIL: $$py doesn't match $$ver" \
	             "(hand-edited? re-vendor: bash ~/code/REPOS/sutra/vendor.sh <dest-lib-dir> <ext-dir> --bootstrap=<pill>)"; \
	        fail=1; continue; \
	    fi; \
	    echo "check-sutra: integrity ok ($$mod $$v, sha256 $$sha)"; \
	    if [ -d "$$canon/.git" ]; then \
	        if [ ! -f "$$cmt" ]; then \
	            echo "check-sutra: freshness unknown for $$mod (no $$cmt anchor, an older vendor)"; \
	        else \
	            recorded=$$(cat "$$cmt"); \
	            filehead=$$(git -C "$$canon" log -1 --format=%H -- "$$mod.py"); \
	            if git -C "$$canon" merge-base --is-ancestor "$$filehead" "$$recorded" 2>/dev/null; then \
	                echo "check-sutra: freshness ok ($$mod vendored from $$recorded, at or after its own head $$filehead)"; \
	            elif git -C "$$canon" merge-base --is-ancestor "$$recorded" "$$filehead" 2>/dev/null; then \
	                echo "check-sutra: LAG ($$mod vendored from $$recorded, canonical has since moved to $$filehead) -- warn, not a failure"; \
	            else \
	                echo "check-sutra FAIL: DRIFT ($$mod's vendored commit $$recorded is not in canonical's history at $$canon) -- re-vendor"; \
	                fail=1; \
	            fi; \
	        fi; \
	    fi; \
	done; \
	if [ ! -d "$$canon/.git" ]; then \
	    echo "check-sutra: canonical sutra checkout not present, freshness skipped"; \
	fi; \
	exit $$fail
```

`<dest-lib-dir>` is the same private per-pill lib dir the preamble resolves to
(`src/share/<pill>/lib/` in a repo checkout — see below); `<ext-dir>` and
`<pill>` are only used inside the re-vendor hint. Extend the `for mod in ...`
line with `pill.js` (and point `py`/`ver`/`cmt` at the extension dir instead)
if the pill also vendors it there **and is using this raw fallback, not
sutra.mk** — under sutra.mk, set `SUTRA_EXT_DIR` before the `include`
instead (above); hand-extending this loop underneath sutra.mk does nothing
(sutra.mk's own `check-sutra` target shadows this one in the Makefile) and
signals the wrong mental model to the next reader.

**Integrity** is the hard gate: a mismatched sha256 means the copy was
hand-edited or corrupted, full stop, `fail=1`, no LAG/DRIFT nuance applies.

**Freshness** is the half that had a real, shipped bug. The correct
comparison is `recorded` (the `.commit` anchor) against
`git -C "$canon" log -1 --format=%H -- "$mod.py"` — that file's *own* last
commit in canonical history. Recorded at-or-after that commit → fresh.
Recorded a strict ancestor of it → LAG, the vendored copy has genuinely
fallen behind, warn only, exit 0. Recorded not in canonical's history at all
→ DRIFT, hard fail. **The bug this replaces**: comparing `recorded` against
`git -C "$canon" rev-parse HEAD` instead — canonical's whole-repo HEAD, which
moves on *every* commit, including ones that never touch `$mod.py` at all.
That false-positives a LAG warning (sometimes worse) on a docs-only commit
that changed nothing the vendored copy actually depends on. Decision
`325b1969` corrected it; as of this writing it has reached one pill
(coldspot, at its commit `d32f802`) out of five that carry a `check-sutra`
target at all. The other four still compare against `rev-parse HEAD` and
should switch to the form above at their own next touch — same non-big-bang
pace as the preamble adoption, thread `0627dac7`.

## What a pill's own migration touches

sutra publishes the preamble and the path convention; each pill applies
both at its own next touch (a **new version**, never a re-cut of a sealed
release — same non-big-bang pace as every other Wave B adoption).
Obligation thread `20819d5a` tracks the coordinated pass. Per repo:

- **`vendor.sh`'s `DEST`, in a repo checkout, is `src/share/<pill>/lib/`
  — not a free choice.** The preamble *derives* its lib dir from the
  binary's own location (`dirname(dirname(realpath(__file__)))/share/
  <pill>/lib`); it is never told a prefix. From `src/bin/<pill>` that
  arithmetic only ever resolves to `src/share/<pill>/lib` — nowhere
  else, regardless of what other per-pill convention the repo already
  has (e.g. a `src/data/` dir for man pages/config is not a substitute:
  measured — coldspot vendored to `src/data/lib` following exactly that
  local convention, landed on `main`, CI green, and every binary
  ModuleNotFoundError'd on `import sutra` in the checkout, because
  `src/bin/coldspot` derives `src/share/coldspot/lib`, full stop). Only
  the *packaging* step (the `.deb`'s Makefile target, `install.sh`) has
  real latitude, because it stages into `$DEBROOT`/`$PREFIX` paths the
  preamble also derives correctly at install time — the repo tree itself
  does not.
- **`.deb`'s Makefile target and `install.sh`** both currently do
  `install ... sutra.py $BINDIR/sutra.py` (or equivalent) — change the
  destination to `$SHAREDIR/lib/sutra.py` (most pills already have a
  `$SHAREDIR`/`usr/share/<pill>/` concept for other per-pill files; add a
  `lib/` subdirectory to it).
- **Every binary** gets the preamble pasted in, per above.
- **`uninstall.sh`/the `.deb`'s removal path** must clean up the *old*
  `$PREFIX/bin/sutra*.{py,version,commit}` files. A `.deb` upgrade drops
  package-owned files automatically; `install.sh`'s old copies are owned
  by nothing and would linger forever otherwise.
- **The installed copy should be checkable**, not just the source-tree
  one: `check-sutra` (whether via `sutra.mk` or the hand-written
  fallback) verifies `src/share/<pill>/lib/sutra.py` against
  `src/share/<pill>/lib/sutra.version` — the *dev-tree* copy in a repo
  checkout. The same sha256/anchor logic applies unchanged to the
  *installed* copy, just pointed at `$SHAREDIR/lib/sutra.py` /
  `$SHAREDIR/lib/sutra.version` instead — sutra.mk's `check-sutra` has no
  built-in way to point at an installed prefix today, so this is on the
  pill to wire up if it wants the installed copy covered too. A guard
  that only ever reads the dev-tree copy while the machine runs a
  different installed copy is the same blind spot the collision itself
  exploited, one layer out.
- **`make smoke` should run a binary straight from the checkout**, not
  only from a staged/synthetic prefix tree — `python3 src/bin/<pill>
  --help`, expect `rc 0`. A synthetic prefix built by the test proves
  the preamble resolves in a *correctly laid out* tree by construction;
  it says nothing about whether the actual repo on disk is that tree.
  That's exactly the gap the coldspot break above passed through: its
  restructured tests proved the staged case and never ran the binary
  where it actually lives.
