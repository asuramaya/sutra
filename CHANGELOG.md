# Changelog

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
