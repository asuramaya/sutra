# Changelog

## 0.9.0 — REPO-STANDARD catch-up: fourteen rows, check-repo, recipes stop being copied by hand (2026-08-01)

- sutra converges on the family's REPO-STANDARD.md: root goes from
  seventeen tracked rows to fourteen. `CODE_OF_CONDUCT.md`/`CONTRIBUTING.md`/
  `SECURITY.md` move to `.github/`, `CHANGELOG.md`/`BOOTSTRAP.md` move to
  `docs/`, `VERSION` moves to `packaging/`, `.gitattributes` is added. The
  five product files (`sutra.py`, `sutra_update.py`, `sutra_xen.py`,
  `pill.js`, `vendor.sh`) stay at root under a recorded exemption — see
  `docs/ARCHITECTURE.md` — moving them under `src/` would break four
  sibling pills' `check-sutra`, which read them by literal root-relative
  path.
- New `docs/ARCHITECTURE.md`, `docs/USAGE.md`, `docs/RELEASING.md`, a
  `## Map` nav block in `README.md`.
- New `make check-repo` gate, wired first in `ci.yml`, adapted (not
  copied) from coldspot's reference implementation: required-file
  presence honors the exemptions table for every entry, not just the
  man-page case coldspot itself needed, and the stray-version-string
  check excludes sutra's own ruled per-file version constants.
- The corrected `check-sutra` freshness recipe — compare each vendored
  file against its own last-modifying commit in canonical history, never
  sutra's repo HEAD (decision `325b1969`) — is now published as canonical
  copy-paste text in `docs/BOOTSTRAP.md`, same pattern as the bootstrap
  preamble. It had reached one of five pills; this publishes it so the
  rest can copy one correct thing instead of independently re-deriving it.
- Per operator ruling, sutra still cuts no tagged release: sealing stays
  blocked until sutra and mudra converge on this same pass.

## 0.8.1 — BOOTSTRAP.md's repo-tree latitude was a live bug (2026-07-28)

- 0.8.0's BOOTSTRAP.md said `vendor.sh`'s `DEST` in a repo checkout is
  `src/share/<pill>/lib/` "or wherever the pill's build stages it before
  packaging" — true of the packaging step, false of the tree, and read
  as permission. Coldspot's adoption vendored to `src/data/lib`
  (following coldspot's own existing per-pill data-dir convention),
  landed on main, CI green, and every binary ModuleNotFoundError'd on
  `import sutra` in the checkout: the preamble *derives* its lib dir
  from the binary's own location (`src/bin/<pill>` only ever resolves to
  `src/share/<pill>/lib`, by the same arithmetic that makes it
  prefix-agnostic at install time), so the repo-tree location isn't a
  choice the way the packaging destination is. RAMstein and ByeByte
  landed on the correct shape independently; coldspot followed the
  doc's stated latitude and broke. Caught by Alfred within the hour
  (third instance this week of a doc naming a goal and leaving the
  mechanism to each seat — REPO-STANDARD's row count and the
  release-notes recipe were the first two).
  Fix: BOOTSTRAP.md now states `src/share/<pill>/lib/` as the repo-tree
  location plainly, explains why in one line (derived, not told), and
  the packaging-step latitude is scoped to actual packaging only. Also
  adds a `make smoke` recommendation every adopter should carry: run a
  binary straight from the checkout (`python3 src/bin/<pill> --help`,
  expect rc 0), not only from a staged synthetic prefix tree — a
  synthetic tree built correct by construction proves the preamble
  resolves in a correctly-laid-out tree and says nothing about whether
  the actual repo on disk is one. Doc-only; the preamble itself is
  unchanged and was independently verified by Alfred before the Wave B
  dispatch that surfaced this.

## 0.8.0 — the install-path bootstrap (2026-07-28)

- **The collision.** Every pill vendors sutra.py/sutra_update.py/
  sutra_xen.py byte-identical into a SHARED system directory (/usr/bin
  via .deb, /usr/local/bin via install.sh) under the same filenames.
  Six of six. Any two pills installed together collide: dpkg refuses
  the second outright (Till's finding — RAMstein's .deb refused because
  phanspeed's already owned /usr/bin/sutra.py); install.sh's plain
  `install` has no ownership tracking and silently overwrites, anchors
  included. Measured on the operator's own machine: /usr/bin/sutra.py
  and /usr/local/bin/sutra.py were already two different canonical
  commits, and /usr/bin carried no .version/.commit anchors at all, so
  nothing could detect the mix. Same shape as the CI-drift class (0.7.5)
  one layer out: a guard that reads the wrong copy reads green while the
  machine runs different bytes. Ruling: decision 3e44bd95 (operator
  handed Alfred the call); obligation thread 20819d5a tracks the
  coordinated pass across all six pills.
  Fix: vendored copies move to `<prefix>/share/<pill>/lib/` — a private,
  per-pill directory, off the same $PREFIX the binaries already use —
  with .version/.commit landing there too, always. Every binary that
  imports sutra needs a small sys.path preamble to find them there,
  since co-location (Python auto-adds a running script's own directory
  to sys.path) is what silently made this collision inevitable in the
  first place. New **BOOTSTRAP.md** documents the fix and publishes the
  exact preamble text, so no pill hand-derives its own and gets the
  relative-path arithmetic or the idempotency check subtly wrong in only
  one of six repos. `vendor.sh` gains `--bootstrap=<pill-name>` (also
  reachable as `make vendor ... BOOTSTRAP=<pill-name>`), printing that
  preamble ready to paste, with the pill name as the only thing that
  ever varies. `vendor.sh`'s usage/header comment and README's vendor
  example updated for the new DEST convention (a private lib dir, never
  a shared bin/); pill.js is unaffected (already installs per-pill under
  `<prefix>/share/<pill>/extension/<uuid>/`, stated explicitly so nobody
  "fixes" it).
  Verified before publishing, not just reasoned through: two pills
  vendored and "installed" under one shared prefix with zero file
  collisions, each binary correctly resolving to its own pill's sutra.py
  from a bin/ directory containing no sutra*.py at all; the same
  mechanism verified again across two different prefixes (/usr,
  /usr/local) to confirm it needs no prefix told to it; and a
  double-paste of the preamble in one file confirmed idempotent (no
  duplicate sys.path entry).
  This is sutra's half only: each pill still needs its own Makefile/
  `.deb`/`install.sh`/`uninstall.sh` updated to point at the new path,
  paste the preamble into every relevant binary, and clean up the old
  shared-dir files on upgrade — tracked per-repo under obligation thread
  20819d5a, landing as a new version in each pill, never a re-cut.

## 0.7.5 — CI has been red since 0.2.0, and the check was wrong (2026-07-28)

- The operator noticed CI failing across the family; Alfred traced sutra's
  case to `ci.yml`'s last step, `version matches`, asserting `VERSION ==
  SUTRA_VERSION` — a rule from before the per-file version convention
  (0.4.0), never updated after that convention decoupled the two on
  purpose. Result: **every commit since 0.2.0 failed CI** (only the very
  first, 0.1.0, was ever green) — eleven consecutive false failures,
  `smoke`/`attack`/the vendor.sh anchor check all genuinely green the
  whole time underneath. sutra sits under every pill's integrity chain,
  so this meant no CI signal has ever actually protected a sutra release.
  Same shape as three other cases the family hit this week (phanspeed,
  kast, coldspot): CI holding a stale copy of a rule the project moved
  past.
  Fix: `tests/check_version.sh` (new) asserts the invariant the
  convention actually needs — a file's own version constant must move
  whenever the file's own bytes do (`git diff --quiet HEAD~1 HEAD --
  <file>`, then compare the constant before/after); `VERSION` is free to
  move independently, exactly as CONTRIBUTING.md already says. One
  generic pattern covers all four constants (`SUTRA_VERSION`,
  `SUTRA_UPDATE_VERSION`, `SUTRA_XEN_VERSION`, `PILL_JS_VERSION`) —
  Python double-quoted or JS single-quoted, doesn't matter. New `make
  check-version` target (folded into `make check`); `ci.yml`'s inline
  assertion replaced with `run: make check-version`, per the family
  ruling that CI invokes Makefile targets and never carries its own copy
  of a rule. Checkout gains `fetch-depth: 0` so `HEAD~1` actually
  resolves (the previous shallow checkout would have made this new check
  silently skip on every run otherwise). Verified against five scripted
  cases in scratch repos before publishing (unchanged file, real
  change + correct bump, real change + forgotten bump in both a Python
  and a JS file, `VERSION`-alone-moves — the exact false-positive shape
  this replaces) — same discipline as the LAG/DRIFT freshness fix
  (0.7.3): test the implementation, not the description of it.

## 0.7.4 — a roadmap section (2026-07-27)

- README gains "Roadmap", below the status-emitter recipe: Xfce and
  Hyprland marked **already served** (the 0.7.2 recipe, not pending
  work); Cinnamon **planned** (its applet API forks GNOME Shell's, so
  `pill.js` is expected to port rather than get rewritten); KDE
  **planned, no date** (a native `pill.qml`, QML sharing no runtime
  with GJS); anything beyond Linux **out of scope** by standing ruling.
  Operator resolved the scope question 0.7.2/0.7.3 raised ("what if
  sutra reached KDE/Xfce/Cinnamon/Hyprland"): on the roadmap, no
  timeline, no KDE machine or harness in this fleet to build or verify
  one against. Alfred's module-adding hold stands unchanged; the recipe
  half was already shipped and needed no further work. Doc-only.
  Alfred also registered a fleet-wide blind spot (`surface: kde-plasma`)
  noting no KDE execution environment exists anywhere in this project —
  a `pill.qml` written without one would pass every check this rig can
  run and still never have been executed once — and explicitly scoped
  Xfce/Hyprland as unaffected, since they consume the existing protocol
  rather than needing new surface.

## 0.7.3 — LAG/DRIFT's freshness half anchors on the wrong HEAD (2026-07-27)

- Bug found by Alfred within minutes of 0.7.2 shipping: that release
  touched only `.gitignore`/`CHANGELOG.md`/`README.md`/`VERSION` — zero
  code — and every pill carrying the LAG/DRIFT check-sutra recipe
  (ByeByte, RAMstein, kast) immediately reported LAG, including kast,
  which had re-vendored the day before and whose `sutra.py` bytes were
  still byte-identical to canonical. The recipe (decision d51e090f)
  compared the vendored `.commit` anchor against canonical **repo**
  HEAD — which every commit advances, including ones that never touch
  a vendored file. A README typo fix reads identically to a real
  `sutra.py` change under that comparison, so the check couldn't tell
  "the file moved on" from "something else in the repo moved on,"
  and alarmed on the harmless case every time sutra ships anything at
  all — the exact false-positive LAG/DRIFT was built to kill, just
  moved one layer over.
  Fix (decision 325b1969, supersedes d51e090f): compare the
  recorded commit against the **vendored file's own** last-modifying
  commit (`git log -1 --format=%H -- <file>`), not repo HEAD. Recorded
  equal to, or a descendant of, the file's own head → fresh (the file
  hasn't changed since vendoring, regardless of what else shipped).
  Recorded a strict ancestor of it → LAG, unchanged (warn, exit 0).
  Not in canonical's history at all → DRIFT, unchanged (hard fail).
  `vendor.sh`'s anchor-writing is untouched — it already wrote repo
  HEAD at vendor time, which is always equal to or a descendant of the
  file's own last-modifying commit, so every existing `.commit` anchor
  in the wild is still valid input to the corrected check. Only the
  comparison target in each pill's `check-sutra` Makefile target
  changes; `vendor.sh`'s header comment updated to describe it
  correctly. Recipe recorded in osiris (thread 0627dac7); ByeByte,
  RAMstein and kast each pick up the corrected version at their own
  next touch, same non-big-bang Wave B pace as the original rollout —
  the false LAG is cosmetic (integrity's sha256 gate never depended on
  it) so nothing is urgently broken in the meantime.

## 0.7.2 — the generic status-emitter recipe (2026-07-27)

- README gains a new section documenting the Xfce (`genmon`) / Hyprland
  (waybar, eww, ironbar) path: both consume a script polled on an
  interval, which is exactly `sutra.py`'s existing client surface
  (`read_status`/`request`) aimed at one more consumer. Doc-only —
  no new API, no new module, no vendoring change. Raised by the operator
  as "what if sutra reached KDE/Xfce/Cinnamon/Hyprland"; ruled on by
  Alfred (msg 1434): the recipe half is unblocked and costs nothing
  because it documents what already exists, while anything that adds a
  module (a KDE `pill.qml`, a Cinnamon port of `pill.js`) stays held —
  API growth for a new consumer class, and a scope question ("does
  every pill now ship non-GNOME variants forever?") that belongs to the
  operator, not to sutra alone.

## 0.1.0 — the backbone extracted
- sutra.py: the shared pill runtime, factored from ByeByte (the reference)
  and confirmed identical in RAMstein: ControlServer (SO_PEERCRED-gated
  newline-JSON socket), load_config (seed-never-master, typed+clamped),
  write_status (atomic 0640), ewma_rate (smoothed burn), request/read_status
  (client side), runtime_paths/stop_event.
- Vendoring model: single stdlib-only module, copied byte-identical into each
  pill's bin/ and imported as a sibling; make vendor + a hash drift-check.
- tests/toy_daemon.py: a whole tiny pill on sutra — fixture and reference.
- make smoke (unit + vendored-layout daemon), make attack (socket fuzz).
- Two hardening deltas vs the originals, factored once for every pill:
  load_config now rejects a JSON bool for a numeric key (True is an int
  subclass) instead of coercing it to 1; and the control socket listens with
  a backlog of 64 (was 4) so a burst of rapid connects is absorbed by the
  kernel queue instead of bouncing clients with EAGAIN — surfaced by the
  attack suite's connect-storm phase.
- Grown to the whole family after surveying all six. The pills are three
  deployment models, not one — sutra now covers all three:
  * ControlServer authz is pluggable: `allow_uids({...})` (the uid model —
    ByeByte, RAMstein, phanspeed) or `allow_group("coldspot")` (the
    group-membership model — coldspot's `_peer_allowed`, absorbed verbatim:
    root, else primary group or listed member, default deny).
  * `socket_owner=(uid, gid)` and `write_status(..., owner=(uid, gid),
    mode=...)` generalize ownership: (owner_uid, -1) for uid pills, (0,
    group_gid) for coldspot, None for a user daemon (gestalt). Folds in
    phanspeed's chmod-before-chown ordering and its 0644 no-owner fallback.
  kast (no daemon — a glue layer) consumes only write_status/read_status for
  its seam; gestalt keeps its XDG+sanitize config (a refactor-pass question).

## 0.2.0 — the update spine (2026-07-20)

- sutra_update.py: the family update spine (UNIFY.md Wave A #1) — one
  grammar (--check/--json / bare / --auto), one trust chain (SHA256SUMS +
  SSHSIG vs pinned anchor, fail-closed when armed, loud degrade when inert),
  dpkg-vs-source install-path detection (no split-brain writes ever),
  three consent tiers with auto honored only when armed. Vendored beside
  sutra.py with its own drift anchor (vendor.sh carries both).
- tests/unit_update.py: offline trust-chain proof with throwaway keys.

## 0.3.0 — pill.js, the extension commons (2026-07-20)

- pill.js: the shape every GNOME pill repeats (UNIFY.md Wave A #2), factored
  from all five extensions — the ByeByte/RAMstein verbatim twins were the
  seed; coldspot contributed the flush-right list idiom, phanspeed the
  update surface, gestalt the socket writer. Exports: the family palette +
  chip/dot styles · isObj/num/esc/fmtBytes · readStatusFile + the 3×poll+5
  staleness rule · sendCmd (cancellable-aware async socket line) ·
  row/wrapRow/iconRow/dataRow + the NBSP wrap discipline · notify ·
  UpdateSurface (version footer + hidden-until-available update row wired to
  `<pill> update --check --json` and pkexec install — the update spine's
  pill face) · StatusWatcher (GFileMonitor + fallback tick, or plain
  polling) · SystemIndicator add/remove boilerplate. Domain stays out by
  design: ETA horizons, hero ranking, missions and stances are each pill
  being itself.
- vendor.sh: optional second arg (the extension dir) lands pill.js +
  pill.version there — GJS imports siblings only, and the extension dir is
  what `make pill` ships.
- smoke: node --input-type=module --check syntax gate on pill.js (a parse
  error in a shared module bricks every pill's extension at load);
  soft-skipped when node is absent.

## 0.4.0 — the health helper (2026-07-20)

- `check_health(status_path, socket_path)`: the two-check vitals verdict
  every healthcheck bin repeated by hand (UNIFY.md Wave A #3) — factored
  from ByeByte's and RAMstein's near-identical originals. Freshness judged
  against the daemon's OWN declared `poll_interval` (never a magic number),
  same 3x+5s slack as pill.js's `isStale` so a stale status reads
  identically from a CLI healthcheck and a GNOME pill; then a `ping` over
  the control socket confirms the daemon is alive-and-answering, not just
  alive-on-disk. Returns `(healthy, reason, info)` — passive by design, it
  renders a verdict and never restarts anything (that stays each pill's
  call, e.g. systemd's `Restart=`). phanspeed's active-restart script and
  kast's domain-specific systemd-drift check are correctly out of scope —
  each pill's own healthcheck bin becomes a thin wrapper over this at its
  own next release (Wave B), same adoption shape as sutra_update.py/pill.js.
- Version convention, ruled (Alfred's review of this release): the top-level
  `VERSION` file is the REPO's release counter (this file, 0.1.0→0.4.0 across
  four Wave A/B releases) — vendor.sh's `.version` drift anchors always use
  it. Each module's own in-file constant (`SUTRA_VERSION`, `PILL_JS_VERSION`,
  `SUTRA_UPDATE_VERSION`) tracks that FILE's own content history instead,
  independent of the repo counter — it bumps only when that specific file's
  bytes change, not on every release. sutra.py's content was untouched
  through 0.2.0/0.3.0 (those releases added sibling files, not lines here),
  so `SUTRA_VERSION` stayed "0.1.0" until this release's check_health —
  its first real edit — moved it to "0.2.0". `sutra_update.py` and
  `pill.js` are unchanged this release, so their constants stay put.

## 0.5.0 — sutra_xen, the guest-surface reader (2026-07-21)

- `sutra_xen.py`: the guest-side pre-stage of the Xen adaptation program
  (Ra's dom0-seam doctrine, decision 32b88ff24f87) — vendored beside
  sutra.py/sutra_update.py, same drift-anchor discipline, always vendored
  (a pill with no Xen concerns simply doesn't import it). Exactly three
  things, none of which move when XEN.md lands:
  * `virt_type()` / `is_guest()` — systemd-detect-virt when present
    (reported honestly — kvm/docker/etc., not just xen-or-nothing);
    `/proc/xen` + the DMI vendor string as the fallback when the binary is
    missing, both guest-only signals, xen-or-none only (the one hypervisor
    this family's guest seam cares about).
  * `balloon_target_kb()` / `balloon_headroom_kb()` — the xen_memory sysfs
    surface (`target_kb` vs `/proc/meminfo`'s MemTotal); the gap is real
    machinery (memory the balloon driver hasn't onlined yet), not noise —
    RAMstein's balloon-aware totals need `target_kb` as the ceiling, never
    MemTotal. Pure guest-local reads, zero contract dependency.
  * `refresh_host_telemetry()` — the guest-side cache half of the dom0
    seam: an injected `fetch` callable's return value gets cached to a
    local status.json via `sutra.write_status`. The actual transport
    (orchestratord's `host.telemetry` method, over the guest<->dom0
    bridge) is Ra's contract to define — XEN.md-GATED, not built here; a
    raising or malformed `fetch()` never crashes the caller and never
    clobbers the existing cache.
  * `tests/unit_xen.py`: offline, fake sysfs trees + an injected
    systemd-detect-virt callable, no hardware, no network — plus one live
    check (`is_guest()` on the dev box itself, which really is a Xen
    guest).
- `vendor.sh`'s dirty-tree guard (0.4.0) widened to catch untracked new
  files, not just modified tracked ones — `git status --porcelain`
  instead of `git diff --quiet`; sutra_xen.py's own introduction was the
  case that exposed the gap (a brand-new file has nothing to diff against,
  but everything to refuse).

## 0.5.1 — sutra_xen doc correction (2026-07-21)

- Comment-only fix: 0.5.0's docs described the host-telemetry transport
  as "node-signed" throughout. Per Ra's preliminary lean (his 904,
  addendum to the pre-stage order, landed after 0.5.0's build started):
  read-only telemetry actually rides UNAUTHENTICATED on trusted-local
  under the connection-trust split — no node key for reads, signing is
  actuation-only (phanspeed's pin/unpin) and entirely outside this
  module. `refresh_host_telemetry()`'s stubbed `fetch` models an
  unauthenticated read, not a signed one. Also noted as a second,
  separate XEN.md-gated detail: the eventual node key itself is
  dom0-minted at guest-create, TPM-sealed, dropped at a path the
  contract will spec — not invented here either. No behavior changed.

## 0.6.0 — notify_owner, the shared notification helper (2026-07-21)

- `notify_owner(uid, app_name, summary, body, urgency="normal")`: best-
  effort notify-send into the owner's desktop session, absorbed into
  sutra.py per UNIFY.md's notification spec (row 13). Root-daemon path
  (uid is someone else's — crosses via `runuser` + that session's bus at
  `/run/user/<uid>/bus`) is ByeByte's original verbatim; the direct-
  session path (uid is `None` or already the caller's own) is new, for a
  user daemon (gestalt) that's already running as its owner. `app_name`
  is notify-send's `-a` (each pill passes its own name — this is a
  shared helper serving all of them, not a single pill's constant);
  `urgency` is `'normal'`/`'critical'` per the spec (update-available and
  completed auto-actions vs. failsafe events), passed straight through.
  Silently does nothing if there's no active login session or anything
  about reaching it fails — a verb's success never depends on whether a
  toast could be shown, and the caller must already have written the
  ledger/status entry the toast points at (a toast is a pointer to
  truth, never the truth itself). `bus_path`/`run` are test-injection
  seams (default to the real bus path and `subprocess.run`); no pill
  needs either.
- `SUTRA_VERSION` 0.2.0 → 0.3.0 (its own content changed: the import of
  `subprocess` plus this function).

## 0.7.0 — LAG vs. DRIFT (2026-07-21)

- Custodian ruling, superseding 4a2c4c2b's plain HEAD-compare: 0.6.0's
  release turned check-sutra red in three already-adopted pills within
  hours — every one of them pure LAG (an honest vendor from an earlier
  canonical commit, canonical has since moved on), zero DRIFT (a
  hand-edited or corrupted copy). A single "differs from canonical"
  verdict couldn't tell the two apart, so it over-alarmed on the common,
  harmless case every time sutra ships. `vendor.sh` now writes a second,
  additive anchor — `<name>.commit`, the canonical commit this copy came
  from — beside the unchanged `<name>.version` (existing pills' `$NF`
  sha-parsing stays untouched; nothing new is inserted into that file).
  The reference `check-sutra` freshness half becomes a three-way read:
  no `.commit` anchor → freshness unknown (an older vendor, harmless);
  recorded commit equals canonical HEAD → freshness ok; recorded commit
  is an ancestor of HEAD (`git merge-base --is-ancestor`) → **LAG**, warn
  and exit 0; recorded commit isn't in canonical's history at all →
  **DRIFT**, hard fail. Integrity (the sha256-vs-`.version` check) is
  unchanged and stays the hard gate regardless. Recipe recorded in
  osiris (thread 2ac0a67f) for each pill's Wave B adoption at its own
  next touch — not a big-bang edit across live repos.
- `tests/smoke.sh` gains a vendor.sh sanity check: runs a real vendor
  into a scratch dir and asserts every `.version`/`.commit` pair exists
  and the commit anchor matches canonical HEAD exactly (skipped, not
  failed, when the canonical tree itself is dirty or not a git
  checkout).

## 0.7.1 — community files (2026-07-25)

- `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md` added — sutra was
  0/3 on the family's standard community-file set (every pill is 4/4;
  sutra had README + CHANGELOG but not these three), flagged in a
  family-wide remote-presentation sweep. `CODE_OF_CONDUCT.md` matches the
  family's own short-form template verbatim (ByeByte/phanspeed/RAMstein
  already agree on it; kast's longer Contributor Covenant text is the
  outlier). `CONTRIBUTING.md`/`SECURITY.md` are sutra-specific, not
  copied: sutra isn't a daemon like the pills, so both describe what
  actually applies here — the vendoring model, the low-rate-of-change /
  Linux-only / no-kernel-code-outside-its-module doctrine, the
  `ControlServer`/`load_config`/`write_status` hardening every pill
  inherits, and `sutra_update.py`'s trust chain. No behavior changed.
- Unrelated fix found while re-running `make smoke` before this commit:
  `tests/unit_xen.py`'s live `is_guest()` check hard-asserted this dev box
  is a Xen guest (true when 0.5.0 was written; the box has since moved
  off Xen, and the assertion started failing — a flaky test by
  construction, asserting transient environment state as if it were a
  fixture). Now asserts internal consistency instead
  (`is_guest() == (virt_type() not in (None, "none"))`), which holds
  regardless of what the box actually is at test time.
