# Security Policy

sutra is the pill family's shared runtime backbone, vendored byte-identical
into every pill's root daemon — a vulnerability here reaches every pill that
has vendored it, not just one. Security is taken seriously accordingly.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead use
GitHub's private reporting:

1. Go to the repo's **Security** tab → **Report a vulnerability**.
2. Describe the issue, affected version, and a reproduction if possible.

You'll get a response as soon as reasonably possible. Because a fix here
ships to every pill, please also note which vendored versions you can see
are affected if you're able to check (each pill's `bin/sutra.version`).

## Threat model

The relevant attacker is an **unprivileged local process** abusing a root
daemon over `ControlServer`'s `AF_UNIX` socket. Every field of every request
is hostile until proven otherwise; a bad request answers `{"error": ...}`
and the connection dies — never the daemon (`tests/attack_socket.py` fuzzes
this on every `make attack`).

Hardening `sutra.py` provides to every pill that vendors it:

- **SO_PEERCRED authorization**, pluggable (`allow_uids` for the uid model,
  `allow_group` for the group model) — checked per-connection, on top of
  the socket's own file mode.
- **Bounded reads** (4 KB line cap), JSON objects only; `ping`/`status` are
  answered centrally, anything else is handed to the pill's own `dispatch`,
  which can error or raise without ever crashing the process.
- **Config is the seed, never the master** (`load_config`) — every key is
  typed and clamped; unknown keys are ignored; a tampered config can tune
  numbers within clamps, never grant new behaviour or exceed a bound.
- **Atomic status writes** (`write_status`, tmp + rename), least-disclosure
  mode and ownership — readers never see a torn write.
- **Vendoring integrity** — every vendored copy carries a sha256 drift
  anchor (`<name>.version`) that catches a hand-edited or corrupted copy,
  plus (0.7.0+) a `<name>.commit` anchor distinguishing an honestly-lagging
  vendor from real drift. See `vendor.sh`'s header for the full scheme.

## Update path

`sutra_update.py` is the shared update spine every pill's own `<pill>-update`
wraps. Trust chain: `SHA256SUMS` (or `<artifact>.sha256`) verified per asset
with `hashlib`, then `ssh-keygen -Y verify` of the manifest signature against
a pinned anchor. An **armed** anchor fails closed — no signature, no key, no
install. An **empty** anchor degrades to hash-only, loudly (the pre-arming
era only). Three consent tiers (`--check`/`--json` notify-only by default, a
bare run for explicit manual install, `--auto` honored only when armed) —
an unattended-unsigned install is impossible by construction.

Adversarial tests live in `tests/attack_socket.py`; offline trust-chain
proofs (real throwaway keys, no network) live in `tests/unit_update.py`.
Please keep both passing in any security-relevant PR.
