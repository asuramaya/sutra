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

# vendor sutra into a pill's bin dir:  make vendor DEST=/path/to/pill/bin
vendor:
	@[ -n "$(DEST)" ] || { echo "usage: make vendor DEST=<pill>/bin"; exit 1; }
	bash vendor.sh "$(DEST)"
