# Alka - The Universal Solvent

> A non-Turing-complete, contract-driven hardware instruction set for physical machine state orchestration.

[![Zig](https://img.shields.io/badge/Zig-0.14+-yellow.svg)](https://ziglang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What is Alka?

Alka is a language designed for **sovereign silicon**—direct manipulation of hardware without the OS as intermediary. It compiles to fixed-size binary packets (Metrod format) that execute directly on the PCIe bus.

**Core Philosophy:**
- **Contract-First**: Hardware constraints live in the `.alkavl` (Vial), not in code
- **Zero Overhead**: No interpreter. Compiles to 32-byte hardware commands
- **Implicit Safety**: The compiler automatically injects required operations (e.g., sliding window loops) based on substrate constraints

## File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level instruction sequences |
| `.alkavl` | The Vial | Physical hardware topology and constraints |
| `.alkab` | The Precipitate | Compiled Metrod binary packets |

## Quick Start

```bash
# Build the compiler
zig build

# Compile a program
./zig-out/bin/alkac examples/purify_1070ti.alka examples/ivyb_pascal.alkavl

# Output: purify_1070ti.alkab (Metrod binary packets)
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
[ Zig Compiler ] --> Metrod Packets (.alkab)
      |
      v
[ vitriol.ko ] --> Hardware Execution
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

MIT - See LICENSE file

---

*"The solvent that dissolves the boundary between software and silicon."*