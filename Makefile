.PHONY: build test clean run

# Check if zig is available
ZIG := $(shell command -v zig 2>/dev/null || echo "")

build:
ifndef ZIG
	@echo "Error: Zig not found. Install Zig 0.13+ from https://ziglang.org/"
	@echo "Or use your VSCodium Zig extension's interpreter."
	@exit 1
endif
	@zig build

test:
ifndef ZIG
	@echo "Error: Zig not found"
	@exit 1
endif
	@zig test

run: build
	@echo "Usage: ./zig-out/bin/alkac <source.alka> <vial.alkavl>"
	@echo "Example: ./zig-out/bin/alkac examples/purify_1070ti.alka examples/ivyb_pascal.alkavl"

clean:
	@rm -rf zig-out