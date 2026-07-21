# sutra

The shared runtime backbone of the pill family —
[ByeByte](https://github.com/asuramaya/ByeByte),
[RAMstein](https://github.com/asuramaya/RAMstein),
[coldspot](https://github.com/asuramaya/coldspot),
[phanspeed](https://github.com/asuramaya/phanspeed),
[kast](https://github.com/asuramaya/kast),
[gestalt](https://github.com/asuramaya/gestalt).

A pill is *a daemon that owns the truth, a verb CLI over it, and a GNOME pill
on top.* Six of them repeat the same skeleton — the control socket, the config
loader, the atomic status writer, the burn-rate math. sutra is that skeleton,
factored to **one canonical source** so a fix (especially a security fix to the
socket) lands once instead of six times.

## Cake, and eat it: vendored, not depended-on

Every file here is **stdlib-only**. Pills don't `pip install` sutra and don't
`Depends:` on it — they **vendor** it: `sutra.py` (the backbone), plus
`sutra_update.py` (the update spine) and `sutra_xen.py` (the Xen guest-surface
reader) alongside it, copied byte-identical into the pill's `bin/`, imported as
siblings of the daemon, and shipped inside the pill's own `.deb`. A pill
imports only the ones it needs — the update spine and the Xen reader are
vendored unconditionally but are dead weight until a pill actually `import`s
them. Each pill stays completely self-contained and independently installable
— the property the family's "merged up to the OS one day" constitution rests
on — while the code still has one home. A CI hash check keeps the copies from
drifting; when every pill sits at the same sutra version, they share **one
hash** per file — that shared hash is the family's proof they agree on the
substrate. (If a Debian maintainer ever prefers de-vendoring, the same files
package cleanly as `python3-sutra` — but vendored is the default and needs no
coordination.)

## What's in it

`sutra.py` — the backbone every pill daemon imports:

| API | what it is |
|---|---|
| `ControlServer` | the SO_PEERCRED-gated newline-JSON control socket — peer check, bounded reads, hostile-input framing. `ping`/`status` answered here; every other command is handed to the pill's `dispatch(cmd, req)`. Authorization is pluggable: `allow_uids({...})` for the uid model (ByeByte/RAMstein/phanspeed) or `allow_group("coldspot")` for the group model. |
| `load_config` | the seed-never-master loader: typed, clamped, unknown keys ignored, a tampered config can't push a value past its clamp. |
| `write_status` | atomic (tmp + rename) status.json write, mode 0640, chowned to the owner only as root. |
| `ewma_rate` | one EWMA step over a value whose growth is the burn — smoothed bytes/sec for the ETA. |
| `request` / `read_status` | the client side: one JSON line to the socket, or read status.json when the daemon's gone. For CLIs and healthchecks. |
| `check_health` | the vitals verdict every healthcheck bin repeated by hand: status.json fresh against the daemon's own `poll_interval` (3x+5s slack, same rule as pill.js's `isStale`), then a socket `ping` confirms it's alive-and-answering. Passive — reports, never restarts. |
| `notify_owner` | best-effort `notify-send` into the owner's desktop session (`runuser` + that session's bus, for a root daemon) or directly (a user daemon already running as its owner). A toast is a pointer to truth, never the truth itself — the caller must already have written the ledger/status entry it names. |
| `runtime_paths` / `stop_event` | the small `main()` scaffolding. |

What sutra does **not** own, on purpose: domain polling, the sqlite index, the
verbs, the pill UI. Those are each pill's organs. sutra is the skeleton.

`sutra_update.py` — the family's update spine (one grammar, one trust chain,
three consent tiers); a pill collapses its own `<pill>-update` to a thin
wrapper over `sutra_update.main(...)`. See the module's own docstring for the
full contract.

`sutra_xen.py` — the Xen guest-surface reader, guest-side pre-stage of the
Xen adaptation program:

| API | what it is |
|---|---|
| `virt_type()` / `is_guest()` | systemd-detect-virt when present (honest report — kvm/docker/etc.), `/proc/xen` + DMI vendor as the xen-or-none fallback. |
| `balloon_target_kb()` / `balloon_headroom_kb()` | the xen_memory sysfs surface — the hypervisor's granted `target_kb` vs `/proc/meminfo`'s MemTotal; the gap is real (memory not yet onlined), and the ceiling a balloon-aware pill should use. |
| `refresh_host_telemetry()` | caches an injected `fetch()`'s result to a local status.json via `write_status`. The actual transport (orchestratord's `host.telemetry`, node-signed over the guest↔dom0 bridge) is XEN.md-gated — not built here. |

`pill.js` — the GNOME extension commons (palette, status read + staleness
rule, socket writer, row helpers, update surface, indicator boilerplate);
see its own header comment for the full export list.

## Using it

`tests/toy_daemon.py` is the reference example — a whole (tiny) pill built on
sutra: `import sutra`, a `DEFAULTS`/`CLAMPS` pair, a `dispatch` callable, the
loop. Copy that shape. To vendor into a pill:

```sh
make vendor DEST=/home/asuramaya/code/REPOS/ByeByte/bin
```

## Test

```sh
make smoke     # unit-test the helpers + boot toy_daemon in the vendored layout
make attack    # adversarial socket fuzz (the hostile-input phases, once, here)
```

Free software, GPLv3, stdlib-only. No telemetry. The backbone of the pills;
the whole hall of illusions is *Mayasabha*, for later.
