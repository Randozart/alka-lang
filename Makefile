.PHONY: build test clean run module module-load module-unload install

# Check if zig is available
ZIG := $(shell command -v zig 2>/dev/null || echo "")
ZIG_VENDOR := $(shell pwd)/vendor/zig/zig
ZIG_BIN := $(if $(ZIG),$(ZIG),$(ZIG_VENDOR))

build:
ifndef ZIG_BIN
	@echo "Error: Zig not found. Install Zig 0.13+ from https://ziglang.org/"
	@exit 1
endif
	@$(ZIG_BIN) build

test:
ifndef ZIG_BIN
	@echo "Error: Zig not found"
	@exit 1
endif
	@$(ZIG_BIN) build test

run: build
	@echo "Usage: ./zig-out/bin/alka <source.alka> <vial.alkavl>"
	@echo "Example: ./zig-out/bin/alka examples/purify_1070ti.alka examples/ivyb_pascal.alkavl"

clean:
	@rm -rf zig-out
	@$(MAKE) -C src/athanor clean 2>/dev/null || true

# Kernel module targets
module:
	@$(MAKE) -C src/athanor all

module-load: module
	@$(MAKE) -C src/athanor load

module-unload:
	@$(MAKE) -C src/athanor unload

module-info:
	@$(MAKE) -C src/athanor info

install: build module
	@sudo groupadd -f vitriol
	@sudo cp src/athanor/99-vitriol.rules /etc/udev/rules.d/
	@sudo udevadm control --reload-rules
	@sudo udevadm trigger
	@$(MAKE) -C src/athanor install
	@echo "Installation complete. Usage: ./alka-run.sh <recipe.alka> <vial.alkavl>"
