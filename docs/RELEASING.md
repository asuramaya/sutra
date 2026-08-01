# Releasing sutra

sutra does not cut its own tagged, sealed release. This is a structural
ruling, not a gate waiting to lift — `~/code/REPOS/RELEASE.md:201` (the
family's ratified cross-repo release doctrine, alfred, 2026-07-17):

    | sutra | n/a (vendored, not released alone) | n/a | its integrity story is the vendor hash chain |

sutra ships no daemon, CLI, or extension of its own to install — see
[docs/ARCHITECTURE.md](ARCHITECTURE.md)'s exemptions table. There is no
tarball or `.deb` anyone downloads and runs standalone, so the family's
release artifact shape (`.deb` + tarball + `SHA256SUMS`, operator-signed by
hand) has nothing to attach to here. Every consumer instead receives
sutra's bytes through `vendor.sh`, each file carrying its own sha256
anchor (`.version`/`.commit`) that `check-sutra` verifies on every
consuming pill's own build — a per-file guarantee, checked continuously,
stronger than a repo-level signature checked once at download.

`packaging/VERSION` remains sutra's own release counter, bumped on every
meaningful change (`sutra/Makefile`'s own comment: it "is free to move
independently" of any per-file version constant) — but it is never tagged
or sealed. There is no `.github/workflows/release.yml` here, and there
will not be one.

## What actually blocked, and what it means that it lifted

An earlier version of this document read as a timing gate: "no sealing or
release until sutra and mudra converge," describing a ceremony sutra
itself would eventually perform once that gate lifted. That was wrong on
its own terms even before convergence — sutra was never on the other side
of a release gate, per RELEASE.md:201 above — but the wording invited
exactly that misreading, and on 2026-08-01 it nearly produced a full
signing-machinery build for this repo (dispatch msg 2866, held before
building on msg 2877, corrected on msg 2884).

What the gate actually meant: sutra's own convergence (sutra.mk,
pill-ci.yml, the recipe-layer hardening through 0.12.3) was a real
precondition for the **six pills'** own tagging — they vendor from and
depend on sutra being stable before they seal a release built against it.
That gate has fired; the pills (and mudra) proceed to tag on the
operator's word. It says nothing about sutra cutting a release of its own,
because sutra was never structurally eligible for one.

## Rules that don't bend

- No release, sealed or otherwise, of sutra itself. If a future ruling
  changes this, it corrects `RELEASE.md:201` explicitly, by line, before
  any release machinery gets written here — not the reverse.
- `make check` (`smoke` + `attack` + `check-version` + `check-repo`) green
  before every commit, same as any other change. sutra's trust story is
  continuous per-file verification, not a point-in-time ceremony — there
  is no "before tagging" here to gate anything on.
