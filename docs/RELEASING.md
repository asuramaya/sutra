# Releasing sutra

sutra has never cut a tagged release, and the operator has ruled that it
doesn't get one yet: **no sealing or release until sutra and mudra converge**
on this same family repo-structure pass. This document describes the shape
the ceremony will follow once that block lifts — see
[docs/ARCHITECTURE.md](ARCHITECTURE.md)'s exemptions table for why
`.github/workflows/release.yml` doesn't exist in this repo yet either; writing
it ahead of the block would be ceremony with nothing licensed to run it.

As with every pill, the maintainer prepares and publishes; **the operator
alone seals** — no automation stands in for that step.

## 1. Prepare

- Bump `packaging/VERSION`.
- Write the release's entry in `docs/CHANGELOG.md`.
- Run `make check` (`smoke` + `attack` + `check-version` + `check-repo`) —
  all green before tagging, not after.
- Confirm every pill still vendoring a pinned older sutra copy isn't broken
  by the change (a `check-sutra` freshness read against the new HEAD, run
  from the consuming side).

## 2. Tag and publish

`git tag` + push. CI builds and publishes the tagged artifact — deliberately
**unsigned** at this stage; publication is not sealing.

## 3. The operator seals it

The operator's own signature (`ssh-keygen -Y sign` against
`release-signing/allowed_signers`, once that machinery exists here) is what
turns a published tag into a sealed release. See the sibling pills'
`docs/RELEASE-SIGNING.md` pattern for the trust-chain shape this repo will
adopt when release machinery is actually built.

## Rules that don't bend

- A sealed release is never re-cut. Get it right before the operator signs,
  not after.
- Release notes come from `docs/CHANGELOG.md` via `--notes-file`, never
  `--generate-notes` — a generated note has no author accountable for what it
  claims changed.
- No release, sealed or otherwise, while `make check-repo` is red.

## When it goes wrong

**Tempted to cut a release ahead of the convergence pass** — don't. The block
isn't a technical gate this document can route around; it's the operator's
explicit ruling on sutra and mudra's sequencing, and lifts only when they say
so.
