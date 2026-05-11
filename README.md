# Alka - The Universal Solvent

<img src="assets/alka-logo.svg" alt="Alka" width="200"/>

> A non-Turing-complete, component-driven hardware instruction set for (sub-)kernel state orchestration.

[![Zig](https://img.shields.io/badge/Zig-0.14+-yellow.svg)](https://ziglang.org)
[![License: Apache 2.0 with Runtime Exception](https://img.shields.io/badge/License-Apache_2.0_with_Runtime_Exception-blue.svg)](LICENSE)

## What is Alka?

Alka is a language designed for direct manipulation of hardware without the OS as intermediary. It compiles to fixed-size binary packets that execute directly on the PCIe bus.


**Core Philosophy:**
- **Contract-First**: Hardware constraints live in the `.alkavl` (Vial), not in code. Code is checked against the vial to see if it's safe to pour the solution.
- **Zero Overhead**: No interpreter. Compiles to 32-byte hardware commands for direct hardware access.
- **Implicit Safety**: The compiler automatically injects required operations (e.g., sliding window loops) based on substrate constraints
- **Universal Solubility**: The compiler doesn't care which language a component is written in, it all compiles to binary in the end and stitches that together.
- **Language as Recipe**: Alka is built on the idea that the tools of its compiler are interchangeable. If a smart programmer manages to rewrite a tool for a new purpose, they can swap it into their version of the compiler, and simply execute their version of the `.alka` file. It will behave differently, but compile all the same. This allows for custom-purpose compilers running the same recipes.
- **No Assumed Architecture**: The CPU is a first class citizen in most, if not all programming languages. Alka consciously subverts that.
- **Signal-based Highlighting**: The Alka highlighter was written with risk-management in mind. Instead of highlighting syntax purpose, it prefers to highlight the purpose and risk of components.
- **Automatic Antidote**: Alka programs can be pretty intrusive, especially when used for operations like Red Teaming. The language is designed so that any compiled `.alkas` also compiles a corresponding `.azoth` to fix what the binary may have broken.

## How and Why?

I designed Alka when I started getting into kernel and sub-kernel manipulation. Initially to try and manipulate my GPU to talk directly to my SSD over the PCIe bus using DMA. In other words, I wanted to bypass the CPU. Some languages are designed to allow you to do this, but require extensive boilerplate to do it safely.

This is the purpose kernels usually serve, to map hardware interaction to a safe, stable, software executable platform. Embedded engineers will know what programming bare metal feels like, but even here, computer hardware remains elusive, and wrong code can potentially turn your desktop PC into a very expensive paperweight.

This is where Alka comes in. The name is based on the alchemical *Alkahest*, the universal solvent. It takes an instruction set (also called a recipe) and predefined keywords for tools (the components), compares the definitions with the actual hardware the script is targeting, and outputs binary for that target hardware. This way, it is able to pre-check whether the operations performed are actually safe.

The intended purpose for this is hardware hacking, custom drivers, and to some extent cybersecurtity, pen-testing and general computer chicanery.

As for the alchemical language? I figured it would be kind of neat.

## VSCodium Extension

Install the `.vsix` package:
```bash
flatpak run com.vscodium.codium --install-extension alka-lang.vsix
```

**Syntax highlighting works with any theme** — Alka uses standard TextMate scopes (`keyword.control`, `string.quoted.double`, `comment.line`, etc.) so keywords, strings, and comments are colored by whatever theme you have active.

**Recommended:** Select the **"Alka Officina"** color theme (`Ctrl+K Ctrl+T`) for the full risk-based color personality:
- 🟡 **Gold** — Sovereignty commands (`CLAIM`, `STAKE`)
- 🔴 **Red** — Substrate operations (`OSSIFY`, `BOND`, `STILL`)
- 🟣 **Magenta** — Dissolution (`STRIKE`, `GHOST`, `HIJACK`)
- 🔵 **Cyan** — Solvent (`FLOW`, `SHIFT`)
- 🟢 **Neon Green** — Safety (`FENCE`, `SYNC`, `ISOLATE`)

<img src="assets/alka-ide.png" alt="Alka Officina Theme"/>

## File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level instruction sequences |
| `.alkavl` | The Vial | Physical hardware topology and constraints |
| `.alkas` | The Precipitate | Compiled Alka Solution binary packets |

## Quick Start

```bash
# Build the compiler
zig build

# Compile a program
./zig-out/bin/alkac examples/purify_1070ti.alka examples/ivyb_pascal.alkavl

# Output: purify_1070ti.alkas (Metrod binary packets)
```

## Example

```alka
// Purify_1070Ti - Move LLM weights from NVMe to VRAM
REQUIRE ivyb_pascal.alkavl;

CLAIM GPU_MAIN;
CLAIM NVME_BOOT;

LIMIT GPU_MAIN.THERMAL MAX 85C;

SHIFT GPU_MAIN.DATA_PLANE @ 0;
FLOW NVME_BOOT[OFFSET_1] GPU_MAIN.DATA_PLANE[0] 256MB;
FENCE GPU_MAIN.METAPAGE == 1;

SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
FLOW NVME_BOOT[OFFSET_2] GPU_MAIN.DATA_PLANE[0] 144MB;
FENCE GPU_MAIN.METAPAGE == 2;

SYNC L3;
SIGNAL INFERENCE_COMPLETE;
```

## The Vial (Substrate)

```alkavl
Vessel GPU_MAIN {
    PCI_ID: 10de:1b82;
    
    Aperture DATA_PLANE {
        BAR: 1;
        MAX_WINDOW: 256MB;  // Z77 trap
        TYPE: Prefetchable;
    }
    
    Thermal SENSOR_0 {
        HALT_AT: 85C;
        THROTTLE_AT: 80C;
    }
}
```

## Instruction Set

### Core Operations
- `CLAIM` - Stake hardware node
- `FLOW` - DMA transfer (bypasses CPU)
- `SHIFT` - Remap BAR window
- `FENCE` - Wait for condition
- `SNAP/REVERT` - State serialization

### Extended Operations (41 total)
- `VEIL` - Hide hardware from OS
- `STASIS` - Bus-level locking
- `STRIKE` - Rowhammer/bit flipping
- `FOSSILIZE` - Persistence in firmware
- `FORGE` - FPGA bitstream injection
- And more...

See [SPEC.md](SPEC.md) for complete reference.

## Architecture

```
.alka + .alkavl
      |
      v
[ Zig Compiler ] --> Alka Solution Packets (.alkas)
      |
      v
[ Binary Vector ] --> Hardware Execution
```

## Project Structure

```
alka-lang/
├── SPEC.md              # Language specification
├── build.zig            # Build configuration
├── src/
│   ├── main.zig         # Entry point
│   ├── parser/          # Lexer + parsers
│   ├── compiler/        # Validation
│   └── codegen/         # Metrod emission
├── examples/            # Sample programs
└── tests/               # Unit tests
```

## Requirements

- **Zig 0.14+** (or use the VSCodium Zig extension)

## Why Alka?

Traditional languages ask the OS for permission. Alka speaks directly to the PCIe bus.

- **AI Inference**: Stream weights directly from NVMe to VRAM without CPU overhead
- **Real-Time**: Hard nanosecond-precision timing for sensors
- **Sovereign**: Operate "underneath" the OS's permission system

## License

Apache 2.0 with runtime exception - See LICENSE file

---

*"The solvent that dissolves the boundary between software and silicon."*
