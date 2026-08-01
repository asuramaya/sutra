#!/usr/bin/env bash
# check_version.sh -- the invariant the per-file version convention
# (.github/CONTRIBUTING.md) actually needs enforced: a vendored file's own version
# constant moves whenever the file's own bytes do. The repo VERSION release
# counter is decoupled by design and free to move independently. A prior CI
# step asserted VERSION == SUTRA_VERSION instead -- correct before the
# convention, wrong on every commit after it (red since 0.2.0; caught by
# Alfred, CHANGELOG 0.7.5).
set -euo pipefail
cd "$(dirname "$0")/.."

# One generic pattern covers every file: `[export const] SOMETHING_VERSION
# = "x.y.z"` (or single-quoted, JS-style) -- anchored so a stray mention
# elsewhere in a file (a comment, a docstring) can't be mistaken for the
# declaration.
PATTERN="s/^(export const )?[A-Za-z_]+VERSION = ['\"]([^'\"]+)['\"];?\$/\\2/p"

fails=0

check_one() {
    local file="$1"
    if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
        echo "check-version: no parent commit -- skipping $file (repo's first commit)"
        return
    fi
    if git diff --quiet HEAD~1 HEAD -- "$file"; then
        echo "ok: $file unchanged, its version constant is free to sit still"
        return
    fi
    local now prev
    now="$(sed -n -E "$PATTERN" "$file")"
    prev="$(git show "HEAD~1:$file" 2>/dev/null | sed -n -E "$PATTERN" || true)"
    if [ -z "$now" ]; then
        echo "FAIL: $file has no version constant matching the expected shape"
        fails=$((fails + 1))
    elif [ "$now" = "$prev" ]; then
        echo "FAIL: $file changed this commit but its version constant ($now) didn't move"
        fails=$((fails + 1))
    else
        echo "ok: $file changed, version constant moved '${prev:-none}' -> '$now'"
    fi
}

check_one sutra.py
check_one sutra_update.py
check_one sutra_xen.py
check_one pill.js

if [ "$fails" -eq 0 ]; then
    echo "CHECK-VERSION OK"
else
    echo "CHECK-VERSION FAILED ($fails)"
    exit 1
fi
