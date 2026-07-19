# sutra — the shared pill backbone
.PHONY: smoke attack check vendor

smoke:
	bash tests/smoke.sh

attack:
	python3 tests/attack_socket.py

check: smoke attack

# vendor sutra into a pill's bin dir:  make vendor DEST=/path/to/pill/bin
vendor:
	@[ -n "$(DEST)" ] || { echo "usage: make vendor DEST=<pill>/bin"; exit 1; }
	bash vendor.sh "$(DEST)"
