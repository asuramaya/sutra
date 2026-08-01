# Using sutra

sutra isn't run on its own — there's no daemon or CLI here to invoke. "Using"
it means vendoring it into a pill and keeping that copy honest over time. See
the README for what each product file (`sutra.py`, `sutra_update.py`,
`sutra_xen.py`, `pill.js`) actually does.

## Vendoring into a pill

```sh
make vendor DEST=/home/asuramaya/code/REPOS/ByeByte/share/byebyte/lib \
            EXT=/home/asuramaya/code/REPOS/ByeByte/extension/byebyte@asuramaya \
            BOOTSTRAP=byebyte
```

`DEST` is the pill's own **private** lib dir, never a shared `bin/` — see
[BOOTSTRAP.md](BOOTSTRAP.md) for why (six pills vendoring identically-named
files into one shared bin dir make each other uninstallable) and for the
small `sys.path` preamble `BOOTSTRAP=<pill-name>` prints. `EXT` is optional —
pass it when the pill also vendors `pill.js` into its GNOME extension dir.

This writes, for each of `sutra`/`sutra_update`/`sutra_xen` (and `pill.js`
when `EXT` is given): the byte-identical file, a `.version` anchor
(`<version>  <sha256>`), and a `.commit` anchor (the canonical commit the
copy came from). `vendor.sh` refuses to run against a dirty canonical
checkout — vendoring WIP would ship an unreviewed edit into a pill under a
version number nobody released.

## The bootstrap preamble

Every binary in a pill that does `import sutra` needs a small preamble pasted
in immediately before that line, so it can find the vendored copy in the
pill's private lib dir rather than relying on being co-located with it.
`vendor.sh --bootstrap=<pill-name>` prints it ready to paste. Full rationale
and the canonical text: [BOOTSTRAP.md](BOOTSTRAP.md).

## Keeping a vendored copy honest: check-sutra

Every pill runs a `check-sutra` target (in its own Makefile) against its
vendored copies. Two things it proves:

- **Integrity** (hard fail): the vendored file's sha256 still matches its
  `.version` anchor — nobody hand-edited the copy instead of re-vendoring.
- **Freshness** (LAG warns, DRIFT fails): the `.commit` anchor is compared
  against canonical sutra's history for *that file specifically*, not the
  whole repo's HEAD. Recorded at-or-after the file's own last-modifying
  commit → fresh. A strict ancestor of it → LAG, a real but survivable gap,
  warn only. Not in canonical's history at all → DRIFT, hard fail.

The canonical recipe every pill should copy verbatim is published in
[BOOTSTRAP.md](BOOTSTRAP.md) — sutra authors it once so five pills run the
same correct check instead of five independently-derived variants.

## Updating a vendored copy

Re-run `vendor.sh` (or `make vendor`) with the same `DEST`/`EXT`; never
hand-edit a vendored file in place — `check-sutra`'s integrity check exists
specifically to catch that. Commit the refreshed files together with their
`.version`/`.commit` anchors.

## The reference example

`tests/toy_daemon.py` is a whole (tiny) pill built on sutra — `import sutra`,
a `DEFAULTS`/`CLAMPS` pair, a `dispatch` callable, the loop. Copy its shape
when wiring a new pill's daemon to `sutra.ControlServer`.

## Troubleshooting

**`ImportError: No module named 'sutra'` right after vendoring** — the
consuming binary is missing its bootstrap preamble, or the preamble's `_PILL`
doesn't match the directory `vendor.sh` actually wrote into. Re-run
`vendor.sh --bootstrap=<pill-name>` and confirm the printed `_libdir`
resolves to where the vendored copy actually landed.

**`check-sutra FAIL: DRIFT`** — the vendored `.commit` anchor isn't in
canonical sutra's history at all. Either the anchor was corrupted/hand-edited,
or canonical's history was rewritten since. Re-vendor from a clean canonical
checkout.
