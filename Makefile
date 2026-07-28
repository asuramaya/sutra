# sutra — the shared pill backbone
.PHONY: smoke attack check-version check vendor

smoke:
	bash tests/smoke.sh

attack:
	python3 tests/attack_socket.py

# a vendored file's own version constant must move whenever the file's own
# bytes do; the repo VERSION release counter is free to move independently
check-version:
	bash tests/check_version.sh

check: smoke attack check-version

# vendor sutra into a pill's private lib dir (see BOOTSTRAP.md — DEST is
# never a shared bin/):  make vendor DEST=<pill>/share/<pill>/lib
#   [EXT=<extension-dir>] [BOOTSTRAP=<pill-name>]
vendor:
	@[ -n "$(DEST)" ] || { echo "usage: make vendor DEST=<pill>/share/<pill>/lib [EXT=<ext-dir>] [BOOTSTRAP=<pill-name>]"; exit 1; }
	bash vendor.sh "$(DEST)" $(if $(EXT),"$(EXT)") $(if $(BOOTSTRAP),--bootstrap="$(BOOTSTRAP)")
