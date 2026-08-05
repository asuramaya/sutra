# Releasing sutra

sutra IS released. This reverses the prior ruling in this document —
operator ruling, 2026-08-05, superseding `~/code/REPOS/RELEASE.md:201`'s
former "n/a (vendored, not released alone)". Read the current
`RELEASE.md:201` row and its "sutra's posture, and why it is not like the
others" subsection before touching anything below; this document is the
procedure, that one is the reasoning and the standing rule.

## The shape — two facts, both true at once

**sutra IS released, and it is NOT a runtime dependency of any pill.**

- **The artifact is a signed source tarball + `SHA256SUMS`. Never a
  `.deb`.** Nothing imports sutra at runtime — the consumption model is
  *vendoring*. A `.deb` would imply an installed library no pill links
  against, and would re-open the co-installation class ruling `3e44bd95`
  closed by giving every pill its own private
  `<prefix>/share/<pill>/lib/`.
- **The six pills keep vendoring byte-identical copies and gain no
  `Depends:`.** `3e44bd95`'s rejection of "a shared sutra.deb every pill
  depends on" stands, untouched: `install.sh` has no dependency
  mechanism, and per-pill pinning is what keeps version skew harmless.
- **What the release is for**: third parties and forks building their own
  pill, who today have no verifiable way to know they hold the intended
  source. It gives the vendor hash chain the human-approved root it has
  always lacked — the sha256 in `<file>.version` proves a copy *matches* a
  checkout, never that the checkout was ever *intended*.
- **A release is a promise.** Published means API stability and
  deprecation notice are owed from here on. sutra moved 0.9.0 → 0.13.0 in
  days; that cadence has to slow, or be explicitly declared unstable,
  once tags start shipping — this document does not resolve that on its
  own and it is worth raising before the first tag, not after.

## Two signing surfaces, same key, different consumers

sutra now has **two** independent signature checks, easy to conflate,
serving different readers:

| | covers | verified by | serves |
|---|---|---|---|
| **Tag signature** | the commit `vendor.sh` copies from | `vendor.sh`'s own guard, `git verify-tag` against `packaging/release-signing/allowed_signers` (sutra 0.13.0) | *vendoring* consumers — the six pills, at every re-vendor |
| **Tarball signature** | the exact published tarball bytes | a detached `SHA256SUMS.sig`, verified by hand or by a fork's own tooling | *tarball* consumers — third parties and forks who never vendor |

Same key, same ceremony, same `allowed_signers` anchor — two different
checkpoints because they answer two different questions ("is the state I'm
copying approved" vs. "is the archive I downloaded approved"), not because
sutra has two trust roots.

## The actual procedure

1. **Arm before tagging, never after.** `packaging/release-signing/
   allowed_signers` must carry a real line before any tag exists — the
   release workflow refuses outright if it's empty at tag time, because a
   tag's tree is exactly what `git archive` ships and a sealed release is
   never re-cut. Vajra's `sync-signers` does the arming, at the operator's
   own hand; that is not this repo's action to take.
2. **`make dist` locally first**, to see exactly what a tag would ship
   before it ships: builds `dist/sutra.tar.gz` (`--prefix=sutra/`, so it
   always extracts to one named directory, never bare into the caller's
   CWD — the family's known repeat tarbomb defect) and `dist/SHA256SUMS`.
   Verify by actually extracting into an empty directory, not by reading
   the flag.
3. **The operator tags** — `git tag -s vX.Y.Z`, their key, their touch.
   Nothing in this repo cuts a tag; sutra only *reacts* to one landing.
4. **`.github/workflows/release.yml` fires on the tag push**: re-verifies
   the tag matches `packaging/VERSION`, re-checks the anchor isn't empty,
   builds the same tarball fresh from that exact tag (never trusts a
   locally-built one), re-verifies the extraction is tarbomb-free, pulls
   release notes from `docs/CHANGELOG.md`'s matching section (never
   `--generate-notes` — refuses outright if the section is missing rather
   than shipping a commit dump as notes), and publishes an **unsigned**
   GitHub release: `sutra.tar.gz` + `SHA256SUMS`.
5. **The operator signs `SHA256SUMS` by hand, offline**, with the physical
   FIDO2 key — the same ceremony as every other sealed repo in the family
   — then `gh release upload vX.Y.Z SHA256SUMS.sig --clobber`. No secret or
   hardware key ever lives in Actions; a CI-held key would let anyone who
   compromises the account or the workflow sign whatever they just pushed,
   defeating the entire scheme.

`make check` (`smoke` + `attack` + `check-version` + `check-repo` +
`check-signing`) green before every commit, same as any other change —
that hasn't changed, and there is still no "before tagging" checklist
beyond arming: sutra's trust story was always continuous per-file
verification, and tagging adds a checkpoint on top rather than replacing
it.

## History — why this document used to say the opposite

Through 0.12.9, this document ruled sutra ineligible for release at all,
correctly at the time (`RELEASE.md:201` then read "n/a (vendored, not
released alone)"). Worth keeping on record, not because it still governs,
but because the reasoning that reversed it matters more than the old
conclusion:

- **2026-08-01**: an earlier draft of this document read as a *timing*
  gate — "no sealing until sutra and mudra converge" — which invited the
  misreading that a release was merely deferred. It nearly produced a
  full release-signing build here (dispatch msg 2866, held on msg 2877,
  corrected on msg 2884): the actual gate was the **six pills'** own
  tagging depending on sutra's convergence, never sutra cutting a release
  of its own.
- **2026-08-03 (sutra 0.13.0)**: `vendor.sh` gained a signed-tag guard for
  vendoring consumers — a provenance checkpoint, explicitly documented at
  the time as *not* a release, because the same ambiguity above was still
  live.
- **2026-08-05**: the operator reversed the "n/a" ruling directly — the
  gap the 0.13.0 checkpoint didn't close was third parties and forks with
  no verifiable root at all, and a signed tarball closes it without
  touching how any of the six pills consume sutra. This document's
  opening two paragraphs are that reversal; everything above is the
  procedure it now requires.

If a future ruling reverses release eligibility again, it corrects
`RELEASE.md:201` explicitly, by line, before this document changes to
match — not the reverse.
