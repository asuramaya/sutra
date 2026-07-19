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
