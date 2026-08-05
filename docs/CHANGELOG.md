# Changelog

## 0.13.0 — vendor.sh refuses an unattested commit; check-sutra reports provenance (2026-08-05)

The supply-chain gap found while designing the update service (msg 3744
via Alfred): sutra is vendored BYTE-IDENTICAL into six pills and, until
now, nothing ever asked whether the canonical state being copied was
approved by a human holding a key. `vendor.sh` recorded whatever sha256
sat in the checkout AT VENDOR TIME as authoritative; a compromised
canonical checkout would poison that hash permanently, every later
`check-sutra` would pass forever after (integrity only proves the copy
MATCHES what was recorded, never that what was recorded was GOOD), and six
pills would sign and ship the poison with VALID signatures — not forged,
correctly attesting "the operator released this." The operator would just
have released poison unknowingly. Vajra is arming sutra's real anchor and
teaching mudra `git tag -s` in parallel; this is the consuming half.

- **`vendor.sh` refuses to vendor an unattested HEAD.** Resolves the tag
  containing HEAD (`git tag --contains`), verifies it with `git verify-tag`
  against `packaging/release-signing/allowed_signers`. No tag verifies →
  refuse (exit 1), nothing written. NOT MADE ABSOLUTE, per Alfred's
  explicit instruction: `SUTRA_VENDOR_ALLOW_UNSIGNED=1` vendors an
  untagged dev fix anyway, WARNS to stderr, and writes `unsigned` as a
  second line in every `.commit` anchor it produces — visible forever
  after, never silent, same doctrine as the LAG warning and byebyte's
  PENDING contract.
- **Pre-arming state is INERT, not a refusal.** An empty or absent
  `packaging/release-signing/allowed_signers` skips the guard entirely —
  same armed/unarmed doctrine `sutra_update.py`'s own `armed()` already
  applies to this exact anchor shape. Ordinary vendoring keeps working,
  unchanged, while the anchor gets armed elsewhere in the family.
- **`check-sutra` gained a provenance line, two independent signals,
  neither ever fails the build** (UNKNOWN/warn/ok, graduated like
  LAG/DRIFT, per Alfred's explicit instruction — a missing signature is a
  fact worth surfacing, not grounds to block `make check`):
  1. The static `unsigned` marker, read unconditionally — no canonical
     checkout needed, works on a CI runner or contributor machine that
     never has one.
  2. A LIVE check, gated exactly like freshness (`$canon/.git` present):
     is the recorded commit reachable from a tag that verifies against
     canonical's OWN anchor, right now? Can report "ok" even for a commit
     vendored unsigned at the time, if canonical was tagged and signed
     LATER covering it — a retroactive human endorsement is real signal,
     not staleness. Confirmed by test: the static marker stays `unsigned`
     (a vendor-time fact) while the live check flips to `ok` once a
     covering tag lands.
- **A signed tag here is a VENDORING-PROVENANCE checkpoint, not a
  release** — sutra still cuts no release of its own (`docs/RELEASING.md`,
  `RELEASE.md:201` unchanged). Said explicitly, in both
  `docs/RELEASING.md` and `docs/ARCHITECTURE.md`'s "Commit signing"
  section, because this exact ambiguity nearly produced release machinery
  once already (0.12.4's near-miss). Also said explicitly what this does
  NOT do: it protects the VENDORING ACT, gated on a canonical checkout
  existing beside the pill — never the end user installing a `.deb`, which
  relies entirely on the pill's own release signature, the actual
  user-facing control, one layer downstream of this one.
- **Nothing asuramaya-specific**: no hardcoded org, no hardcoded pill
  list, no assumed tag-naming scheme — any tag containing HEAD that
  verifies against the repo's OWN `allowed_signers` satisfies the guard,
  on any fork.
- **`tests/signing_smoke.sh`** (new, wired into `make check` as
  `check-signing`): fixture-only, throwaway ed25519 keys (mudra's own
  `ssh-keygen -t ed25519` pattern, never a real or hardware key), real
  `git init`/`tag -s`/`verify-tag`, never mocked. NEGATIVE CONTROL FIRST,
  per Alfred's explicit instruction — proves the guard actually refuses an
  unsigned commit against an armed anchor (asserts nothing was written)
  before proving it passes a signed one. Also covers the bypass path (WARN
  + marker), the live-check ladder (ok/warn/unknown), the retroactive-tag
  case, and an adversarial case (a tag signed by a key NOT in
  `allowed_signers` must not satisfy the guard). Verified the test has
  teeth, not just "runs without crashing": temporarily disabled the
  refuse branch, confirmed the suite goes red on exactly the negative
  control and the adversarial case, restored, confirmed green again.
- **A real `set -e` bug caught by running the test, not by reading the
  diff**: `_sutra_write_commit_anchor`'s last line was
  `[ -n "$VENDOR_UNSIGNED_MARK" ] && printf ...` — under `set -e`, a
  false `[ -n ... ]` (the common case, mark unset) makes the `&&` list's
  exit status nonzero, and being the function's last statement, aborted
  the entire script the moment `_sutra_write_commit_anchor` ran for the
  first time. Every unarmed/pre-arming vendor would have failed outright.
  Fixed with a plain `if`, whose exit status is always 0 on a false
  condition. Caught by actually vendoring into a fixture directory before
  writing the test script, not by re-reading the diff.

No vendored `.py`/`.js` module's own bytes changed — this touches
`vendor.sh` and `sutra.mk` only, neither carrying a per-file version
constant (`tests/check_version.sh` tracks `sutra.py`/`sutra_update.py`/
`sutra_xen.py`/`pill.js` only). Root row count unchanged at 15 —
`tests/signing_smoke.sh` lands inside the existing `tests/` row, not a new
one. `make check` (now `smoke` + `attack` + `check-version` + `check-repo`
+ `check-signing`) green.

## 0.12.9 — RAMstein renamed to ramstein, family-wide (2026-08-03)

Operator order, via Alfred (msg 3466): `RAMstein` becomes `ramstein` —
mixed-case was a fatal error at inception, in the operator's own words.
This REVERSES the 0.12.5 entry's own ruling that `RAMstein` "stays
mixed-case — that's its real name"; see the superseding note appended
to that entry rather than the entry being rewritten out from under it.

- **61 occurrences swept across the 8 files Alfred identified**:
  `docs/CHANGELOG.md` (33), `sutra.mk` (13), `.github/workflows/pill-ci.yml`
  (5), `docs/BOOTSTRAP.md` (3), `sutra.py` (3), `README.md` (2 lines / 3
  tokens — one line links both text and URL), `pill.js` (1),
  `sutra_xen.py` (1). Alfred had already grepped `*.py`/`*.mk`/`*.sh`/
  `*.yml` for a name-derivation branch (`if pill == "RAMstein"`) and
  found none — verified independently before sweeping rather than taken
  on report: every hit across all 8 files is prose or a comment, none
  of them logic.
- **`docs/CHANGELOG.md:157` excluded from the blind substitution.** It
  isn't a mention, it's the 0.12.5 entry recording the PRIOR ruling
  ("`RAMstein` stays mixed-case — that's its real name"). A global sed
  there would have turned a historical record into a false,
  self-contradicting one. Left exactly as originally written; a
  superseding note appended immediately after it, dated, pointing back
  to this entry.
- **Verified name-only** the way Alfred asked: for each of the 8 files,
  `git show HEAD:<file> | sed 's/RAMstein/ramstein/g'` diffed against
  the actual edit — identical on all 8 (`CHANGELOG.md`'s line 157
  excluded from that substitution by construction, before the diff).
  Zero collateral edits.
- **Per-file version constants bumped** for the vendored files whose
  bytes changed: `SUTRA_VERSION` 0.3.1 -> 0.3.2, `SUTRA_XEN_VERSION`
  0.1.1 -> 0.1.2, `PILL_JS_VERSION` 0.1.1 -> 0.1.2 — comment-only edits,
  no carve-out, per the 0.12.5 precedent. `sutra.mk` has no version
  constant of its own (not tracked by `tests/check_version.sh`) but is
  vendored by hash the same way.

`sutra.mk`, `sutra.py` and `sutra_xen.py` are vendored into all six
pills; this canonical fix does not touch a single consuming repo's own
copy — those ride the existing re-vendor wave (`a8de30f9`), the same
call Alfred made for 0.12.5 and 0.12.6, not a second wave. `make check`
green.

## 0.12.8 — the GNOME extension syntax gate has never checked anything (2026-08-03)

Till found, Alfred verified (msg 3410): `node --check <path>` on a plain
`.js` file silently validates nothing when the file is an ES module —
which every pill's `extension.js`/`pill.js` is, by construction.
Reproduced against a deliberately broken fixture: `node --check
broken.js` exits 0 on garbage a human rejects on sight; `node --check
broken.mjs` and `node --input-type=module --check < broken.js` both
correctly exit 1. `pill-ci.yml`'s "GNOME extension (syntax)" step —
the shared job every pill inherits via `uses:` — has used the bare form
since it existed. It has never caught a single GJS syntax error, in any
pill, in any repo, ever; every green checkmark on that step came from a
command that exits 0 on `function f( {`.

The loop fix documented right above this line in the same file (`node
--check a.js b.js` only validates the first file) was real, correctly
diagnosed, and carefully explained — and stopped one question short: the
command inside the loop was never checking anything to begin with.

- **Fixed**: `node --check "$f"` → `node --input-type=module --check <
  "$f"`, the stdin form, chosen over the temp-file/`.mjs`-copy form
  already used ad hoc in byebyte's Makefile and hector-vector's ci.yml
  — no cleanup path to get wrong. An `echo "checking $f"` precedes each
  check: node's stdin-mode error names the file `[stdin]`, not the real
  path, and this step's shell runs with `-e`, so the log line above the
  failure is the only place the real filename survives.
- **Re-verified against real files before landing**, not just the
  synthetic fixture: byebyte's `extension.js`/`pill.js`, kast's
  `extension.js`/`prefs.js`, and coldspot's `extension.js` all pass
  clean under the stricter parse — no false-positive risk.
- **Sutra's own `tests/smoke.sh` already used the correct
  `--input-type=module` form for its own `pill.js` gate** — the fix
  existed in this exact repo the whole time, it just never propagated
  from the local test into the shared CI step this repo also publishes.
  No other `node --check` site found in sutra (grepped the repo).

Consequence worth recording, not sutra's to fix: this is the least-
verified code in the family right now — a pill's GNOME extension syntax
has been "checked" by a command that checks nothing, in CI, since the
step existed. Till swept every pill with the reliable form before
reporting; nothing is currently broken anywhere, this closes a silent
gap, not an active fire.

No vendored `.py`/`.js` module touched — `pill-ci.yml` only. `make
check` green (15 rows).

## 0.12.7 — the format has a second machine consumer, and only one pill knows it (2026-08-03)

Doc-only, no parser change. Maat found, Alfred verified: `kast/install.sh:245`
feeds `packages.txt`'s surviving lines straight to `apt-get install`, filtered
only by `grep -Ev '^\s*(#|$)'` — drops whole-comment and blank lines, but does
NOT strip a trailing inline `# comment` off an otherwise-real line. kast's
file has always been bare-name-only; that isn't a missing convention, it's a
constraint its own installer imposes. checked family-wide (Alfred): byebyte,
ramstein, coldspot, phanspeed and gestalt have no second consumer of the
file — kast alone does.

The 0.12.6 parser is unaffected — split-on-first-`#` yields the bare token
whether or not a comment follows, so kast's comment-free lines already parse
correctly, no code change needed. The risk runs the other way: if kast
later adopts the family's inline-comment style to look consistent, its own
installer would silently start trying to install comment text as package
names. Documented the rule directly in `sutra.mk`'s `check-packages` header,
next to `SUTRA_PACKAGES_VERIFY_AGAINST`: a pill may add inline comments to
its `packages.txt` only if nothing besides this parser reads the file
directly, or after fixing that consumer to strip trailing comments first —
a single `sed 's/#.*//'` ahead of kast's own grep costs nothing. Same shape
as 0.12.6's echo/printf bug: a convention that's safe only because nobody
has exercised the unsafe case yet, and says nothing about it on its own.

Five seats already have the 0.12.6 spec by mail; four of them have no
reason to suspect their own file is anything but documentation, and this
is the fact that would have caught them out first. `make check` green
(15 rows).

## 0.12.6 — check-packages: Depends/Suggests generated from packages.txt (2026-08-03)

Operator ruling 2cd900ce, dispatched via Alfred (msg 3356): nothing
auto-pulls — hard `Depends` is a short fixed floor (python3/systemd/
openssh-client plus documented domain exemptions), everything else is
`Suggests` (never `Recommends` — apt installs Recommends by default, and
a headless `apt install <pill>` must never pull GNOME Shell), build-time
deps appear in neither tier. `packages.txt` becomes the generated source
of `control` so the two can't drift again — measured cause: two of five
pills (byebyte, ramstein) documented an optional tier their shipped
artifact never emitted, and the audit that found it independently missed
`Recommends:` on a third (coldspot) by grepping only `Depends:`.

Measured before building (msg 3364, shape confirmed msg 3365):
`packages.txt` is less uniform than the dispatch assumed — only three of
five pills (byebyte, ramstein, phanspeed) already share a `# --- hard
(...) ---` / `# --- optional (...) ---` header-comment convention;
coldspot's optional tier was package names written *inside* a comment
body (unparseable), kast had no hard/optional split in the file at all.
Control generation also splits two ways: byebyte/ramstein/kast build
`control` from an inline Makefile heredoc with a hardcoded string
(`packages.txt` not consulted at all); coldspot/phanspeed ship a static
`packaging/debian/control`.

- **New `check-packages` target in `sutra.mk`**, same shape as
  `check-vendored-path`: an inline Python script via `define`/`export`.
  Adopts the existing three-pill header convention as the machine
  marker rather than inventing new syntax — zero reformatting needed for
  those three. Added `# --- build (...) ---` as an optional fourth
  header, additive, for symmetry.
- **Parse rule**: a section stays open from its header to the next
  header or EOF; nothing outside an open hard/optional section is ever
  read. That's what keeps build-time deps out of `control` *without* a
  special case — the thing you must not emit is structurally unreachable,
  not merely forbidden, same shape as `SUTRA_EXT_DIR`'s opt-in above it.
  Inside a section, everything before a line's own trailing `# comment`
  is the entry, passed through verbatim (a Debian version constraint
  like `python3 (>= 3.8)` just works, no separate syntax).
- **Two modes**: bare `--depends`/`--suggests` print the computed value
  for a heredoc-style Makefile to interpolate directly; `--verify <file>`
  reads an existing `control` or `Makefile` and fails loudly on any
  mismatch, for the static-file pills. Comparison is by set, not string —
  measured live against phanspeed's real files: same packages, different
  order, which a naive string compare would have flagged as false drift.
  A bare `Recommends:` line in the target is its own hard failure
  regardless of content, per the ruling.
- **The format was published to all five seats before the parser was
  finished** (Alfred's explicit sequencing call, inverted from the usual
  pilot-then-extract order): all five were reformatting `packages.txt`
  simultaneously when this landed, so publishing the spec first meant
  one target shape instead of five independent guesses to reconcile
  after. coldspot and kast got the reformat flagged as their own
  required work (no split existed yet in either); the other three were
  already close.
- **A real portability bug, caught building this, fixed at both call
  sites**: `echo "$$VAR" | python3 -` corrupts any embedded script
  containing `\n`/`\t` — dash's `echo` (the family's `/bin/sh`)
  interprets those as real escapes in its argument, silently splitting a
  Python string literal across lines. `check-vendored-path`'s existing
  invocation never hit this only because its script happens to contain
  no such sequence; switched to `printf '%s\n'` there too, no behavior
  change, just no longer accidentally correct.
- **Tested end-to-end through real `make`**, not just the raw parser:
  matching fixture (pass), content mismatch (fail, both values shown),
  missing `SUTRA_PACKAGES_VERIFY_AGAINST` (fail loudly, no guess),
  `Recommends:` present (fail on doctrine), hard-deps-only pill with no
  optional tier (pass, `(none declared)`) — plus live-verified against
  all five real family repos' actual `packages.txt`/`control`/`Makefile`
  as each landed its own reformat during the same window.

No vendored `.py`/`.js` module touched — this is `sutra.mk` only, the
recipe layer, no re-vendor obligation of its own. Paired with the
existing re-vendor wave (`a8de30f9`) rather than opening a second one, as
instructed. `make check` green (15 rows).

## 0.12.5 — byebyte spelled consistently, family-wide (2026-08-02)

Operator order, via Alfred (msg 3319): `byebyte` must be spelled
consistently across all files, matching the operator's 2026-07-31 ratified
name (lowercase; `RAMstein` stays mixed-case — that's its real name).
**Superseded 2026-08-03:** the operator reversed the `RAMstein` exception
itself — see the 0.12.9 entry below. The line above is left exactly as
written to record what was actually ruled on 2026-08-02; it is no longer
the current rule.
sutra carried mixed-case `ByeByte` in 8 files.

- **`sutra_update.py:9`** — `slug="asuramaya/ByeByte"` in the usage-example
  comment, corrected to `slug="asuramaya/byebyte"`. This one blocks every
  consuming repo from fixing it locally: the file is byte-identical
  (sha256 `fbcd892e...`) in sutra, byebyte, ramstein, phanspeed and
  coldspot, and `check-sutra` verifies that hash — a pill hand-editing its
  own copy would fail its own integrity check. Has to change canonically
  and re-vendor. `SUTRA_UPDATE_VERSION` moved 0.1.0 -> 0.1.1 per the
  per-file-version-tracks-bytes rule (`.github/CONTRIBUTING.md`,
  mechanically enforced by `tests/check_version.sh` — no carve-out for
  "just a comment"). New sha256: `10d6854a...`.
- **`pill.js:16`** — `(ByeByte thinks in weeks, ramstein in seconds)`,
  corrected to lowercase. Found in the same sweep, same shape Alfred
  named for `sutra_update.py` but didn't catch here: byte-identical
  (sha256 `c22472ed...`) in sutra, byebyte, ramstein, phanspeed and
  coldspot (kast has no `pill.js`), verified by `check-sutra` via
  `SUTRA_EXT_DIR`. Same blocking shape, same fix, same four consuming
  repos. `PILL_JS_VERSION` moved 0.1.0 -> 0.1.1. New sha256:
  `cd726e2b...`.
- **`sutra.py:3,166,298,335`** — four prose mentions, lowercased. Also
  byte-identical across all six pills (byebyte, ramstein, coldspot,
  phanspeed, kast, gestalt), same shape as the two above, wider blast
  radius. `SUTRA_VERSION` moved 0.3.0 -> 0.3.1. New sha256:
  `8c5b0095...`.
- **`sutra.mk:55`** — one prose mention, lowercased. Vendored under its
  own integrity+freshness anchor pair (like the four `.py`/`.js` files)
  but has no embedded per-file version constant of its own — its
  `.version` anchor is written by `vendor.sh` directly from
  `packaging/VERSION`, so the repo-level bump below covers it; nothing
  else to move here.
- **`docs/USAGE.md:11-12` and `vendor.sh:6-7`** — the vendor-command usage
  example was wrong twice over, not just stale case: `ByeByte/share/...`
  should have been `byebyte/src/share/...` — missing both the rename and
  the REPO-STANDARD `src/` fold. Verified against the real path on disk
  before fixing. **`README.md:134-135`** carried the identical wrong
  example — same two bugs, same fix, found in the audit pass rather than
  named by the dispatch.
- **`README.md:4,52`** — the family-repo link and the `ControlServer` prose
  mention, lowercased to match.
- **`docs/CHANGELOG.md`'s own historical entries left untouched**,
  deliberately: they're a record of what was written and believed true at
  the time, the same reason git commit subjects don't get rewritten.

No vendored-file drift for anyone *today* — every consuming pill's
integrity check compares its own copy against its own recorded anchor,
not this repo's HEAD, so nothing goes red until a pill actually
re-vendors. But `sutra.py`, `sutra_update.py` and `pill.js` all moved
(three files, not the two originally scoped — `sutra.py`'s four prose
mentions were named as "just prose" but are byte-identical across all
six pills same as the other two), so the parked re-vendor wave (thread
`a8de30f9`, previously measured metadata-only) now carries a real
three-file change: byebyte/ramstein/phanspeed/coldspot for all three
files, plus kast and gestalt for `sutra.py` alone. Pairing the two waves
rather than running separate ones, per Alfred's instruction.

`make check` green (15 rows), including `check-version` — the three
per-file version constants that actually moved bytes are the three that
got bumped, verified against `git diff HEAD~1 HEAD` after committing,
not just `make check` run early against an uncommitted tree. Graph
project-name confusion for this pill (`bytebye` / `ByeByte` / `byebyte`
as three live project objects) is explicitly out of scope here — Thoth's,
not the file layer's.

## 0.12.4 — sutra doesn't release: a structural ruling documented as a timing gate (2026-08-01)

Doc-only. The operator ordered "get everyone to tag so I can seal";
Alfred's dispatch (msg 2866) read that as including sutra and ordered a
full release-signing build (`allowed_signers`, `sync-signers.sh`,
`release.yml`, `docs/RELEASE-SIGNING.md`). Held before building (msg
2877): `~/code/REPOS/RELEASE.md:201`, the family's own ratified cross-repo
release doctrine, already rules sutra `n/a (vendored, not released
alone) ... its integrity story is the vendor hash chain` — a *structural*
ruling, separate from the *timing* gate ("no sealing until sutra and
mudra converge") that had just fired. Lifting a timing gate said nothing
about a structural exemption it never touched. Alfred re-read RELEASE.md
independently, agreed, and ruled: sutra builds no release machinery;
"everyone" meant the repos that actually release (msg 2884).

The near-miss had a real cause worth fixing, not just avoiding: two of
sutra's own docs disagreed with `RELEASE.md:201` and with each other.
`docs/RELEASING.md` described a ceremony ("1. Prepare / 2. Tag and
publish / 3. The operator seals it") sutra would perform once a gate
lifted; `docs/ARCHITECTURE.md`'s exemptions table gave the same "not yet"
framing for the missing `release.yml`. Both implied machinery arrives
after convergence. Neither does, ever — sutra has no daemon, CLI, or
extension of its own to install (ARCHITECTURE.md's own exemptions table,
one row up), so there is no standalone artifact for a `.deb`+tarball
release to attach to in the first place. Every consumer already gets
sutra's bytes via `vendor.sh`'s per-file sha256 anchor, verified
continuously by every consuming pill's own `check-sutra` — a stronger,
ongoing guarantee than a repo-level signature checked once at download.

- **`docs/RELEASING.md` rewritten**: states plainly sutra doesn't release,
  cites `RELEASE.md:201` by line, explains what the convergence gate
  actually gated (the six pills' own tagging, which depended on sutra
  being stable — never a sutra release of its own), and records the
  correction so the next reader doesn't repeat the misreading.
- **`docs/ARCHITECTURE.md`'s exemption row rewritten** to the same effect,
  same citation.
- **One sibling instance fixed**: the "Commit signing" section's closing
  line cited sutra's own `docs/RELEASING.md` as "where the operator's
  sealing ritual already lives" — true of the family in general, false of
  this repo specifically. Reworded to point at a sealed pill's own
  RELEASING.md instead and say plainly sutra has no such boundary.
- Audited the rest of the repo's docs for the same implication
  (`release.yml`/`sealing`/`allowed_signers`/`sync-signers` grep across
  every `.md`): nothing else found.

No vendored module touched, no release machinery written. `make check`
green (15 rows).

## 0.12.3 — defect 8: signing-verify hardcoded a filename that's wrong for half the family (2026-08-01)

Found by Aegis adopting pill-ci.yml, reported via Alfred (msg 2848).
`run-signing-verify` hardcoded `bash tests/test_signing.sh`. Measured
across the family: ByeByte and kast use `tests/test_signing.sh`, but
coldspot and phanspeed use `tests/test_signing.py` — two of the four
pills with a signing test at all were locked out of the shared step and
had to hand-roll a sibling job to run it. Same shape as defect 5
(`SUTRA_CHECK_BIN`): a hardcoded guess wrong for a large minority isn't
a shortcut, it's silent opt-out pressure on exactly the pills the shared
step exists to cover.

- **New `signing-verify-command` input** takes the pill's full command
  (`"bash tests/test_signing.sh"`, `"python3 tests/test_signing.py"`, or
  anything else) — `pill-ci.yml` never needs to know the taxonomy. No
  `.py`-vs-`.sh` special-casing: that would just be a cleverer guess,
  the same trap the family already ruled out once.
- **No default, consistent with the doctrine** `SUTRA_CHECK_BIN`/
  `SUTRA_CHECK_ARGS` already set: `run-signing-verify: true` with an
  empty `signing-verify-command` now fails loudly (`exit 1` with a
  named cause) instead of guessing a filename.
- **`run-signing-verify`'s own description** no longer asserts the
  hardcoded command — same doc-can't-assert-stale-output class as
  0.12.2, caught before it shipped this time rather than after.
- **Audited the rest of the workflow** for the same shape (build item
  4): every other check-step routes through a `make <target>` the pill
  itself implements (`check-repo`, `check-sutra`, `smoke`, `attack`,
  `check-version`) — Make already abstracts the per-pill
  language/filename choice, so signing-verify's bare script path was
  the only step actually bypassing that convention. Nothing else in the
  file has this shape.

Verified: `python3 -c "import yaml; yaml.safe_load(open(...))"` parses
clean; the new input follows the exact same `${{ inputs.x }}`
substitution-into-`run:` pattern already proven by `python-files`/
`shell-files`/`shellcheck-files` above it. Could not live-exercise the
reusable workflow itself — sutra's own `ci.yml` doesn't call
`pill-ci.yml`, and by the pin-per-commit-SHA design (see this file's own
header) no pill's CI is affected until it explicitly re-pins. ByeByte,
kast, coldspot and phanspeed notified that the shared step is available
so their hand-rolled signing-verify sibling jobs can collapse back into
it; their repos not touched here.

No vendored module touched. Not sealed — release block still holds.

## 0.12.2 — the "which prints" transcript was itself stale (2026-08-01)

Doc-only, found by Alfred verifying 0.12.1 independently rather than
taking it on report (msg 2834). BOOTSTRAP.md's "canonical preamble"
section showed a hand-copied transcript of `vendor.sh --bootstrap`'s
output — `sutra 0.7.5`, `see BOOTSTRAP.md` — against what the script
actually emits today: `$ver` interpolates the live `packaging/VERSION`
(`sutra 0.12.1` as of the prior pass), and the citation reads
`see docs/BOOTSTRAP.md`. Same class this whole pass was sent to kill:
a doc asserting what a command outputs, verified once, never re-run.

Fix is the class, not the number — hand-correcting the transcript to
0.12.2 would go stale again at 0.12.3 and every bump after. The example
block now shows the preamble's *shape* with `<ver>`/`<pill-name>`
placeholders and says outright that the real stamp comes from
`packaging/VERSION` at generation time and is not reproduced as a fixed
transcript; the reader is told to run the command in the three lines
above it and paste what it actually prints. Noted why `<ver>` legitimately
differs per pill (0.11.1 / 0.10.1 / 0.8.0, ...): it records each pill's
own vendor moment, not lag.

No vendored module touched. Not sealed — release block still holds.

## 0.12.1 — BOOTSTRAP.md catches up to sutra.mk (2026-08-01)

Doc-only pass, no behavior change to sutra.py/sutra_update.py/sutra_xen.py/
pill.js. Found by Alfred by accident while checking something else (msg
2819): `grep -c "sutra\.mk" docs/BOOTSTRAP.md` was `0`. BOOTSTRAP.md is the
canonical document every pill reads on adoption, and it still presented the
hand-written `check-sutra` shell recipe as *the* recipe, silent on
`sutra.mk` existing at all — the doc-layer instance of the same drift class
0.11.0–0.12.0 kept finding in the recipe layer itself. Measured consequence:
gestalt's Makefile carries a comment justifying a hand-rolled `pill.js`
supplement by citing BOOTSTRAP.md's own "extend the `for mod in ...` line"
instruction — correct for 0.10.1-era gestalt, false at 0.12.0 where
`SUTRA_EXT_DIR` does that natively.

- **`sutra.mk` is now documented as the adopted route.** New "The recipe
  layer: sutra.mk" section: the `PILL` / `SUTRA_EXT_DIR` /
  `SUTRA_CHECK_BIN(S)` / `include` shape, with `ramstein/Makefile:10-36`
  cited as the fully-adopted reference (nothing hand-rolled left).
- **The three no-default traps now live in the doc itself**, not only in
  sutra.mk's own comments: `SUTRA_CHECK_BIN`/`SUTRA_CHECK_BINS` has no
  default (defect 5 — `src/bin/$(PILL)` is wrong for kast/phanspeed);
  `SUTRA_CHECK_ARGS` has no default (a `--help` default made ramstein's
  guard issue a real socket call to the live daemon on every `make check`);
  `pill.js` wants `SUTRA_EXT_DIR` set, not a hand-extended loop underneath
  sutra.mk.
- **The hand-written recipe stays, demoted and relabeled** "The
  hand-written fallback recipe (no Makefile)" — still needed for a pill
  that can't `include` a Makefile at all, no longer presented as the
  default path.
- **A stale path reference fixed in passing**: the "installed copy should
  be checkable" bullet still cited `src/bin/sutra.py` as the dev-tree
  location, predating the move to `src/share/<pill>/lib/` — corrected to
  match the convention the rest of the document already uses.

`grep -c "sutra\.mk" docs/BOOTSTRAP.md` is `19` after this pass. Scope was
deliberately docs/recipe-layer only, per Alfred's explicit constraint — a
code change to any of the four vendored files obliges a re-vendor across
seven repos, not opened here. Not sealed: sutra's release block (thread
per docs/RELEASING.md) still holds pending sutra/mudra convergence: this is
a version bump and changelog entry only, no tag.

## 0.12.0 — silent skips made visible, plus two more real defects from real adoptions (2026-08-01)

Three more defects, all found by pills actually adopting sutra.mk/pill-ci.yml
rather than by sutra validating the artifacts against itself. Landed
together because defect 7 generalizes the shape underneath the other two
(and underneath 3/4/6 before them) and changes how they're fixed.

- **Defect 7 (Till/ramstein, independently tjmax): gated CI steps skipped
  silently.** `run-attack` defaulted false; ramstein's `make attack` was
  never actually run in CI from Till's first pilot commit onward. He ran
  it by hand every time (it passed) and CI was green every time — neither
  signal said the check hadn't run in CI at all. He only found it reading
  `gh api .../jobs/<id> --jq '.steps[]'` directly; tjmax hit the identical
  wall independently the same morning, because `gh run view`'s default
  summary renders job-level checkmarks only and a `conclusion: skipped`
  step is invisible in it. Per Alfred's explicit instruction, NOT fixed by
  changing any default (no boolean is right for every pill — phanspeed
  genuinely cannot run attack in CI, four other pills genuinely can).
  Fixed by removing every step-level `if:` and moving the decision inside
  each step: the step's own name grows a `-- SKIPPED (reason)` suffix via
  a name-level expression (evaluated before the run, so it appears in the
  exact summary view that was blind before) and the run script echoes the
  same decision for the full log. A gated-off step now always shows
  `conclusion: success` with a name and an output line that both say so,
  instead of vanishing. Live-verified: a run with several inputs left at
  their defaults now shows `Attack (adversarial fuzz) -- SKIPPED
  (run-attack is false)` directly in `gh run view`'s own summary output.
- **Defect 5 (maat/kast): `SUTRA_CHECK_BIN`'s default was wrong for 2 of 5
  pills.** It defaulted to `src/bin/$(PILL)`, but that binary doesn't
  import sutra for kast (the bash CLI; only kast-update imports it) or
  phanspeed. A default wrong 40% of the time is a trap: `check-vendored-path`
  only proved the path *exists*, so a real file with no sutra binding got
  run through the guard and failed looking like a broken vendor rather
  than "wrong binary named." No default now — every pill names its own
  sutra-importing binary explicitly.
- **Defect 6 (maat/kast): `extension-js` checked only one file.** Every
  pill has two `.js` files in its extension dir; for kast the second is
  `prefs.js`, its settings dialog, genuinely uncovered. Same class as the
  pill.js drop that produced 0.11.0. Fixed: `extension-js` takes a
  space-separated list, looped one `node --check` per file — measured
  first that `node --check a.js b.js` is NOT "check both" (node only
  validates the first positional argument; a real syntax error in a
  second file exits 0 under a naive word-split fix, which would have been
  worse than the bug it replaced). Live-verified with a deliberately
  broken second file: the run correctly fails, naming the right file.

Adoption state at time of writing (per Alfred): phanspeed and kast are on
0.11.1, ByeByte just re-vendored to it, ramstein is re-vendoring off
0.10.1, coldspot has not adopted. Four pills need a re-vendor for defect
5; only kast currently carries a workaround for defect 6.

## 0.11.1 — SUTRA_EXT_DIR silently checked nothing: the fix for defect 1 reintroduced defect 1 (2026-08-01)

Found by Werner mid-adoption in a real pill, confirmed by Alfred, three
pills blocked pending this. `check-sutra`'s pill.js branch tested
`$(SUTRA_EXT_DIR)` — Make-level, correct — but then read the value back as
`$${SUTRA_EXT_DIR%/}` — shell-level, and `SUTRA_EXT_DIR` was never exported
to the recipe's shell. The `-n` test correctly saw a non-empty value and
took the branch; `extdir` then resolved to nothing, the pill.js path
collapsed to `/pill.js`, and the existing not-vendored-here fallback
reported a clean skip. `check-sutra` exited 0 while covering nothing — the
exact defect 0.11.0's `SUTRA_EXT_DIR` fix exists to close, reintroduced
inside its own fix, and worse than an ordinary failure because it reads as
routine output ("skipping pill.js") rather than a red run.

Fixed: `extdir` now resolves via `$(patsubst %/,%,$(SUTRA_EXT_DIR))`,
Make-level throughout, removing the export/parse-order question entirely
rather than requiring a pill to `export SUTRA_EXT_DIR` around the include
(Werner's local workaround). Swept the rest of `sutra.mk` for the same
$(VAR)-tested-vs-$${VAR}-read shape — isolated to this one branch;
`check-vendored-path`'s `SUTRA_CHECK_BIN`/`SUTRA_CHECK_MODULE` are
consistently `$(...)` throughout.

The regression suite that shipped 0.11.0 passed this bug, and the reason
is itself worth recording: it exercised `SUTRA_EXT_DIR` via a `make
VAR=value` command-line override, which GNU Make auto-exports to the
recipe's shell — masking exactly the gap a real pill hits, since a real
pill sets `SUTRA_EXT_DIR := ...` as a Makefile-internal assignment before
`include`, the same way `PILL` itself is set, which is never
auto-exported. Reproduced the failure via that real pattern first, then
added a positive assertion that pill.js was actually checked (not merely
that the run exited 0) — "skipped" and "passed" are different outcomes and
only one is coverage; that assertion is the one that would have caught
this the first time.

## 0.11.0 — four defects from ramstein's real pilot adoption, plus a safety fix escalated family-wide (2026-08-01)

Till's ramstein pilot (msg 2739 via Alfred) is the first REAL, independently-
built consumer of sutra.mk/pill-ci.yml — sutra validating the artifacts
against itself, and against a fake pill built from the same head that
authored them, could not surface any of these; both share the author's own
assumptions by construction.

- **check-sutra dropped pill.js.** The vendored-.py loop covered only
  sutra/sutra_update/sutra_xen; three of four pills with a hand-written
  check-sutra today (ByeByte, phanspeed, ramstein) also check pill.js, per
  BOOTSTRAP.md's own escape hatch that never made it into the generalized
  form. Verbatim adoption would have silently deleted an existing guard.
  Fixed: `SUTRA_EXT_DIR` opts a pill in; pill.js gets the same
  integrity+freshness shape via a shared shell function, not a duplicate
  loop body. Empty (the default) skips it exactly like a pill with no
  extension should.
- **check-vendored-path validated only one binary per call.** Any pill
  with more than one sutra-importing binary (ramstein has four) needed a
  hand-written loop — precisely the duplication this file exists to
  prevent. Fixed: new `check-vendored-path-all` target takes
  `SUTRA_CHECK_BINS`, a space-separated list of `bin` or `bin:module`
  entries (ramstein-update binds `sutra_update`, not `sutra`).
- **pill-ci.yml had no shellcheck step**, only `bash -n`. Any pill running
  shellcheck today would have silently lost it on adoption. Added
  `shellcheck-files`/`shellcheck-exclude` inputs and a real step.
- **run-check-version defaulted to true and called a target no pill has.**
  Checked all five: none define `check-version`. Worse than merely
  absent — ramstein's own check-repo enforces the *opposite* convention on
  purpose (a single `packaging/VERSION`, no per-file literal at all).
  Adopting with defaults would have hard-failed every pill's first CI run.
  Defaulted to false; sutra remains the only real consumer.
- **Safety fix, escalated by Alfred as family-wide rather than
  ramstein-specific.** `SUTRA_CHECK_ARGS` defaulted to `--help`, assumed
  universally safe. It isn't: three of ramstein's four binaries hand-roll
  argument parsing rather than using argparse, so an unrecognized
  `--help` falls through to their default verb — for ramstein/
  ramstein-healthcheck that meant `make check` making a real socket call
  to the live daemon on every run. Harmless there by ramstein's own
  security model, but a pill whose default verb has a non-idempotent
  side effect would have this guard silently perform it forever,
  unnoticed. tjmax's actual pattern (phanspeed `Makefile:38-42`) never
  assumed a generic flag — `--selftest`/`--check`, pill-specific flags the
  binary's own author verified safe. `SUTRA_CHECK_ARGS` now has no
  default at all: empty, the real-subprocess sanity call is skipped
  entirely and the guard relies solely on the resolution check, which
  never calls `main()` and is safe against any binary regardless of how
  it parses arguments.
- All four fixes verified against an extended scratch fake-pill (a real
  vendored extension dir with real pill.js anchors, a second binary
  binding `sutra_update`) plus a second live GitHub Actions run
  exercising the new shellcheck step and the flipped check-version
  default — not reasoned through in isolation.

## 0.10.1 — check-vendored-path: a layout check was standing in for a resolution check (2026-08-01)

- 0.10.0's `check-vendored-path` computed the EXPECTED path in shell (from
  the bootstrap preamble's own formula) and checked that a file exists
  there. That's a layout check, not a resolution check — it never asked
  Python what a binary actually imported. Alfred reproduced the gap: a
  binary that forgot the bootstrap preamble entirely, sitting beside a
  stale co-located `sutra.py` (the exact pre-migration shape the whole
  ruling exists to clean up), imports successfully via Python's own
  same-directory sys.path fallback — and the shell arithmetic still finds
  a real file at the computed path. Green on the precise regression the
  guard exists to catch.
- Fixed: loads the binary as a module for real (`SourceFileLoader` +
  `exec_module`, with the binary's own directory explicitly inserted into
  `sys.path` first — neither `exec_module` nor `runpy.run_path` do that on
  their own, but a real `python3 <bin>` invocation always does, and that's
  exactly the mechanism a stale sibling exploits) and reads back
  `<module>.<SUTRA_CHECK_MODULE>.__file__`, the path Python actually
  resolved. `exec_module` specifically, not `runpy.run_path` (tried and
  reverted): a binary whose import-time code raises something unrelated
  *after* a successful import (tjmax's case) needs the partial module
  state that survived up to that point, which `exec_module` preserves and
  `run_path` does not.
- Verified against the exact reproduction: a preamble-less binary next to
  a stale sibling `sutra.py` now correctly FAILS with a clear diagnostic
  (resolved path vs. expected path, both shown), and the full regression
  suite — integrity/DRIFT failures, the happy path, ModuleNotFoundError,
  and tjmax's unrelated-failure-after-successful-import case — all still
  pass.

## 0.10.0 — sutra.mk and pill-ci.yml: recipes get the same guard code already has (2026-08-01)

- Measured across the five pills: 441 lines of hand-copied recipe, `check-sutra`
  alone ranging 30–57 lines for what was nominally one thing. Vendored CODE has
  never drifted once (hash anchors make it impossible); vendored RECIPES have
  produced every divergence the family has hit — the corrected `check-sutra`
  freshness fix reached one of five pills, the row-count arithmetic came out
  wrong in three different ways, the vendor path trapped three of four seats.
  This release gives recipes the same mechanical guard code already has.
- New `sutra.mk`, vendored via `vendor.sh` under its own `.version`/`.commit`
  anchor pair alongside the code files, `include`able from a pill's own root
  Makefile (`PILL := <pill>; include src/share/<pill>/lib/sutra.mk`). Carries
  the corrected per-file-head `check-sutra` (integrity as sha256-vs-`.version`,
  freshness as LAG/DRIFT against each vendored file's own last-modifying
  commit, never sutra's repo HEAD — decision `325b1969`), the row-count
  primitive (`git ls-files | cut -d/ -f1 | sort -u | wc -l`, not a
  hand-maintained skip-list), and a checkout-run guard proving a pill's real
  binary resolves its vendored `sutra.py` to the exact expected path rather
  than merely exiting 0 (Till's form, b211651) while not penalizing a binary
  that legitimately can't run in a hardware-free CI runner for unrelated
  reasons (tjmax's refinement, msg 1749). Verified with a scratch integration
  test (a fake pill vendoring sutra + `sutra.mk` end to end, both happy-path
  and every failure branch exercised) — not just reasoned through.
- New `.github/workflows/pill-ci.yml`, a reusable `on: workflow_call` workflow
  covering the shared CI core (structure gate first, python/shell syntax,
  `check-sutra`, optional extension/man-page checks, smoke/attack/check-version,
  optional signing verify) — the strongest of the three recipe-guard layers,
  since GitHub resolves `uses:` at run time: a fix here reaches every adopting
  pill's next run with zero pill-side commits. Pinned by commit SHA, not
  `@main` (uncontrolled blast radius across every pill's CI at once) or a tag
  (sutra cuts none yet — sealing stays blocked until sutra/mudra converge);
  revisit tag-pinning once sutra starts cutting releases. Live-verified against
  a real GitHub Actions run on a scratch branch, exercising both the
  shared-step path and the conditional-skip path, not just YAML-parsed.
- `sutra.mk` sitting at repo root adds a fifteenth row (it's a product file
  the same way the other five are, not documentation or packaging glue) —
  `docs/ARCHITECTURE.md`'s exemptions table and `check-repo`'s cap both
  updated from fourteen to fifteen accordingly. Caught by the live
  `pill-ci.yml` test itself running `make check-repo` against this repo,
  not found ahead of time.
- Per operator ruling, sutra still cuts no tagged release: sealing stays
  blocked until sutra and mudra converge on this same pass. `sutra.mk`/
  `pill-ci.yml` adoption into any pill is explicitly not this repo's to do —
  sequenced by Alfred once both artifacts exist.

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
  choice the way the packaging destination is. ramstein and ByeByte
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
  the second outright (Till's finding — ramstein's .deb refused because
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
  (ByeByte, ramstein, kast) immediately reported LAG, including kast,
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
  ramstein and kast each pick up the corrected version at their own
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
  and confirmed identical in ramstein: ControlServer (SO_PEERCRED-gated
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
    ByeByte, ramstein, phanspeed) or `allow_group("coldspot")` (the
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
  from all five extensions — the ByeByte/ramstein verbatim twins were the
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
  from ByeByte's and ramstein's near-identical originals. Freshness judged
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
    ramstein's balloon-aware totals need `target_kb` as the ceiling, never
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
  family's own short-form template verbatim (ByeByte/phanspeed/ramstein
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
