# sutra.mk -- the family's shared RECIPE layer, vendored like code (see
# docs/BOOTSTRAP.md for the sibling code-vendoring mechanics). Include from
# a pill's own root Makefile:
#
#   PILL := coldspot
#   include src/share/coldspot/lib/sutra.mk
#
# PILL must be set before the include line. Everything else resolves
# relative to sutra.mk's OWN location -- $(lastword $(MAKEFILE_LIST)) at
# include-time is exactly that path, however the including Makefile spelled
# it -- never to sutra's own repo. That is the design constraint: get it
# wrong and five pills each debug their own copy of the same mistake, which
# is the exact failure mode this file exists to close.
#
# 441 lines of this recipe were maintained by hand across five pills before
# this existed; check-sutra alone ranged 30-57 lines for what was nominally
# one thing, and every divergence the family suffered was a recipe, never
# vendored CODE (which has never drifted once, because it has a hash
# anchor -- see docs/ARCHITECTURE.md). This is that same guard, extended to
# recipes: ship the recipe itself under the anchor, so a pill runs the
# current correct thing by construction instead of a snapshot someone
# copied by hand and never revisited.

_SUTRA_MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
_SUTRA_CANON := $(HOME)/code/REPOS/sutra

# --- check-sutra: integrity (hard gate) + freshness (LAG/DRIFT) -----------
#
# Integrity: the vendored .py's sha256 against its own .version anchor --
# hand-edited or corrupted, always a hard fail, no nuance.
#
# Freshness: the .commit anchor compared against canonical sutra's history
# for THAT FILE SPECIFICALLY -- `git -C "$canon" log -1 --format=%H --
# "$mod.py"` -- never canonical's repo HEAD, which advances on every commit
# including ones that never touch the file at all. That was the 0.7.3 fix
# (decision 325b1969, correcting d51e090f's original HEAD-compare, which
# false-positived a LAG warning across the whole family the first time a
# docs-only commit landed). It reached one pill by hand-copying before this
# file existed; the other four still carry the stale form. Recorded at or
# after the file's own last commit -> fresh. A strict ancestor of it ->
# LAG, the copy has genuinely fallen behind, warn only. Not in canonical's
# history at all -> DRIFT, hard fail.
.PHONY: check-sutra
check-sutra:
	@[ -n "$(PILL)" ] || { echo "check-sutra: set PILL=<pill-name> before including sutra.mk"; exit 1; }
	@canon="$(_SUTRA_CANON)"; libdir="$(_SUTRA_MK_DIR)"; fail=0; \
	for mod in sutra sutra_update sutra_xen; do \
	    py="$$libdir$$mod.py"; ver="$$libdir$$mod.version"; cmt="$$libdir$$mod.commit"; \
	    [ -f "$$py" ] || { echo "check-sutra: $$py not vendored here, skipping $$mod"; continue; }; \
	    v=$$(cut -d' ' -f1 "$$ver"); \
	    sha=$$(awk '{print $$NF}' "$$ver"); \
	    actual=$$(sha256sum "$$py" | cut -d' ' -f1); \
	    if [ "$$sha" != "$$actual" ]; then \
	        echo "check-sutra FAIL: $$py doesn't match $$ver" \
	             "(hand-edited? re-vendor: bash $$canon/vendor.sh $$libdir --bootstrap=$(PILL))"; \
	        fail=1; continue; \
	    fi; \
	    echo "check-sutra: integrity ok ($$mod $$v, sha256 $$sha)"; \
	    if [ -d "$$canon/.git" ]; then \
	        if [ ! -f "$$cmt" ]; then \
	            echo "check-sutra: freshness unknown for $$mod (no $$cmt anchor, an older vendor)"; \
	        else \
	            recorded=$$(cat "$$cmt"); \
	            filehead=$$(git -C "$$canon" log -1 --format=%H -- "$$mod.py"); \
	            if git -C "$$canon" merge-base --is-ancestor "$$filehead" "$$recorded" 2>/dev/null; then \
	                echo "check-sutra: freshness ok ($$mod vendored from $$recorded, at or after its own head $$filehead)"; \
	            elif git -C "$$canon" merge-base --is-ancestor "$$recorded" "$$filehead" 2>/dev/null; then \
	                echo "check-sutra: LAG ($$mod vendored from $$recorded, canonical has since moved to $$filehead) -- warn, not a failure"; \
	            else \
	                echo "check-sutra FAIL: DRIFT ($$mod's vendored commit $$recorded is not in canonical's history at $$canon) -- re-vendor"; \
	                fail=1; \
	            fi; \
	        fi; \
	    fi; \
	done; \
	if [ ! -d "$$canon/.git" ]; then \
	    echo "check-sutra: canonical sutra checkout not present, freshness skipped"; \
	fi; \
	exit $$fail

# --- the row-count primitive ----------------------------------------------
# The exact measurement, not a find+skip-list: three of five pills each
# wrote their own skip-list independently and all three came out wrong
# differently. This is what git itself tracks -- build output and local
# scratch never enter it, by construction (REPO-STANDARD.md's "honest
# measurement"). A pill's own check-repo should reference this variable
# instead of re-deriving the command by hand.
SUTRA_ROOT_ROWS = $(shell git ls-files | cut -d/ -f1 | sort -u | wc -l)

.PHONY: check-sutra-rows
check-sutra-rows:
	@echo "root row count: $(SUTRA_ROOT_ROWS)"

# --- the checkout-run guard ------------------------------------------------
# Till's form (b211651): a binary that silently imported a DIFFERENT
# sutra.py off sys.path would still exit 0 -- rc=0 alone proves nothing
# about WHICH copy got imported. Prove the path itself.
#
# tjmax's refinement (msg 1749): a binary that can't cleanly exit 0 in a
# hardware-free runner (root/CAP_* requirements, no real device to talk to)
# shouldn't fail this guard on that account -- that failure has nothing to
# do with whether the vendored copy resolved correctly. So this checks two
# independent things rather than one: (1) does running the real binary from
# the checkout ever hit ModuleNotFoundError/ImportError -- if it does, that
# IS this guard's business and it's a hard fail regardless of exit code;
# (2) does the bootstrap preamble's own published arithmetic
# (dirname(dirname(realpath(__file__)))/share/<pill>/lib, see
# docs/BOOTSTRAP.md), computed from the REAL binary's real on-disk location,
# resolve to exactly where sutra.mk itself is vendored. (2) is what proves
# the exact expected path rather than trusting a self-report the binary
# might not even print.
#
# SUTRA_CHECK_BIN is the pill-specific part: which binary to run. Defaults
# to src/bin/$(PILL), the family's established convention; override if a
# pill's layout differs.
SUTRA_CHECK_BIN ?= src/bin/$(PILL)
SUTRA_CHECK_ARGS ?= --help

.PHONY: check-vendored-path
check-vendored-path:
	@[ -n "$(PILL)" ] || { echo "check-vendored-path: set PILL=<pill-name> before including sutra.mk"; exit 1; }
	@[ -e "$(SUTRA_CHECK_BIN)" ] || { echo "check-vendored-path: no $(SUTRA_CHECK_BIN) -- set SUTRA_CHECK_BIN="; exit 1; }
	@out=$$(python3 "$(SUTRA_CHECK_BIN)" $(SUTRA_CHECK_ARGS) 2>&1); rc=$$?; \
	if [ $$rc -ne 0 ]; then \
	    if echo "$$out" | grep -qE 'ModuleNotFoundError|ImportError'; then \
	        echo "check-vendored-path FAIL: $(SUTRA_CHECK_BIN) could not import sutra from the checkout:"; \
	        echo "$$out"; exit 1; \
	    fi; \
	    echo "check-vendored-path: $(SUTRA_CHECK_BIN) exited $$rc for reasons unrelated to the" \
	         "import (no ModuleNotFoundError/ImportError in its output) -- not this guard's" \
	         "concern, see tjmax msg 1749"; \
	fi; \
	expected="$$(cd "$(_SUTRA_MK_DIR)" && pwd)/sutra.py"; \
	bindir="$$(cd "$$(dirname "$(SUTRA_CHECK_BIN)")" && pwd)"; \
	resolved="$$(dirname "$$bindir")/share/$(PILL)/lib/sutra.py"; \
	if [ "$$resolved" != "$$expected" ]; then \
	    echo "check-vendored-path FAIL: $(SUTRA_CHECK_BIN)'s own bootstrap-preamble arithmetic" \
	         "resolves to $$resolved, but sutra.mk (and the vendored copies beside it) sit at" \
	         "$$expected -- the checkout's own layout doesn't match what the preamble derives"; \
	    exit 1; \
	fi; \
	[ -f "$$resolved" ] || { echo "check-vendored-path FAIL: resolved path $$resolved doesn't exist"; exit 1; }; \
	echo "check-vendored-path: ok -- $(SUTRA_CHECK_BIN)'s bootstrap arithmetic resolves to" \
	     "$$resolved, and it exists"
