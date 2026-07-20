# Changelog

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
