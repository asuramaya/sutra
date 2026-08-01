# sutra — the shared pill backbone
.PHONY: smoke attack check-version check-repo check vendor

smoke:
	bash tests/smoke.sh

attack:
	python3 tests/attack_socket.py

# a vendored file's own version constant must move whenever the file's own
# bytes do; the repo VERSION release counter is free to move independently
check-version:
	bash tests/check_version.sh

# The family's structural gate (REPO-STANDARD.md §5), mechanical only: it
# cannot judge whether a document is any good, only that the shape it's
# supposed to have is actually there and nothing contradicts it. Adapted
# from coldspot's reference check-repo (the family's first to land this
# target), NOT copied verbatim: sutra is a vendoring commons, not an
# application, so several of coldspot's per-pill assumptions don't hold
# here by design rather than by omission --
#   - required-file presence below accepts "present OR named in
#     docs/ARCHITECTURE.md's exemptions table" for EVERY entry, generalizing
#     coldspot's man-page-only carve-out, because sutra genuinely has no
#     install.sh/uninstall.sh/src/ (see the exemptions table for why);
#   - the stray-version-string check below is scoped to files OUTSIDE the
#     ruled per-file-version set (sutra.py/sutra_update.py/sutra_xen.py/
#     pill.js never appear in its grep list), because sutra's whole point is
#     that those four carry their OWN version constants, deliberately,
#     alongside packaging/VERSION -- see the exemptions table.
# The row cap is 15, not the family default of 12, per the same table
# (fourteen from the initial REPO-STANDARD pass, plus one for sutra.mk).
check-repo:
	@fail=0; \
	for f in README.md LICENSE Makefile install.sh uninstall.sh .gitignore .gitattributes \
	         docs/USAGE.md docs/ARCHITECTURE.md docs/RELEASING.md; do \
	    if [ ! -e "$$f" ] && ! grep -q "$$f" docs/ARCHITECTURE.md 2>/dev/null; then \
	        echo "check-repo FAIL: missing $$f and no exemption for it in docs/ARCHITECTURE.md"; fail=1; \
	    fi; \
	done; \
	rows=$$(git ls-files | cut -d/ -f1 | sort -u | wc -l); \
	if [ "$$rows" -gt 15 ]; then \
	    echo "check-repo FAIL: root has $$rows rows, sutra's exemption-justified cap is 15"; fail=1; \
	else \
	    echo "check-repo: root row count ok ($$rows)"; \
	fi; \
	if ! grep -q '^## Map' README.md 2>/dev/null; then \
	    echo "check-repo FAIL: README.md has no navigation block (## Map)"; fail=1; \
	fi; \
	for h in Troubleshooting "Repo Layout"; do \
	    if grep -q "^## $$h" README.md 2>/dev/null; then \
	        echo "check-repo FAIL: README.md carries a post-install heading ('$$h') that belongs in docs/USAGE.md"; fail=1; \
	    fi; \
	done; \
	if [ ! -f packaging/VERSION ]; then \
	    echo "check-repo FAIL: no packaging/VERSION"; fail=1; \
	fi; \
	if grep -rn "VERSION[[:space:]]*=[[:space:]]*['\"][0-9]" vendor.sh Makefile 2>/dev/null; then \
	    echo "check-repo FAIL: a literal version string exists outside packaging/VERSION and outside the ruled per-file set"; fail=1; \
	fi; \
	stray=$$(find docs -name '*.md' -not -path '*/.*' | while read -r f; do git ls-files --error-unmatch "$$f" >/dev/null 2>&1 || echo "$$f"; done); \
	if [ -n "$$stray" ]; then \
	    echo "check-repo FAIL: untracked *.md under docs/: $$stray"; fail=1; \
	fi; \
	spec=$$(find . -name '*-SPEC.md' -not -path './.git/*'); \
	if [ -n "$$spec" ]; then \
	    echo "check-repo FAIL: *-SPEC.md left in the repo (specs belong in the seat's office): $$spec"; fail=1; \
	fi; \
	if [ -f docs/ARCHITECTURE.md ] && grep -q '^## Standard exemptions' docs/ARCHITECTURE.md; then \
	    bad=$$(awk '/^## Standard exemptions/{f=1;next} f && /^\|/ && !/^\| *Item *\|/ && !/^\|---/{ n=gsub(/\|/,"|"); if (n<3) print }' docs/ARCHITECTURE.md); \
	    if [ -n "$$bad" ]; then echo "check-repo FAIL: exemptions table has a row missing a column"; fail=1; fi; \
	fi; \
	if [ "$$fail" -eq 0 ]; then echo "check-repo: all mechanical checks passed"; else exit 1; fi

check: smoke attack check-version check-repo

# vendor sutra into a pill's private lib dir (see docs/BOOTSTRAP.md — DEST is
# never a shared bin/):  make vendor DEST=<pill>/share/<pill>/lib
#   [EXT=<extension-dir>] [BOOTSTRAP=<pill-name>]
vendor:
	@[ -n "$(DEST)" ] || { echo "usage: make vendor DEST=<pill>/share/<pill>/lib [EXT=<ext-dir>] [BOOTSTRAP=<pill-name>]"; exit 1; }
	bash vendor.sh "$(DEST)" $(if $(EXT),"$(EXT)") $(if $(BOOTSTRAP),--bootstrap="$(BOOTSTRAP)")
