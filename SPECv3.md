# Alka Language Specification v3.0

> The "Universal Solvent" for physical machine state orchestration
>
> **Version**: 3.0 (Authoritative)
> **Timestamp**: 2026-05-11
> **Supersedes**: SPEC.md, SPECv2.md
> **Status**: Living document — this file is the single source of truth

---

## Table of Contents

1. [Overview](#1-overview)
2. [Design Philosophy](#2-design-philosophy)
3. [File Types](#3-file-types)
4. [Terminology](#4-terminology)
5. [Language Grammar](#5-language-grammar)
6. [The Substrate (.alkavl)](#6-the-substrate-alkavl)
7. [Complete Instruction Set](#7-complete-instruction-set)
8. [Six Alchemical Arts](#8-six-alchemical-arts)
9. [Substrate Orchestration](#9-substrate-orchestration)
10. [Metrod Binary Format (.alkas)](#10-metrod-binary-format-alkas)
11. [Azoth Rollback Format (.azoth)](#11-azoth-rollback-format-azoth)
12. [Compiler Pipeline](#12-compiler-pipeline)
13. [The Pharmacopeia (Tool System)](#13-the-pharmacopeia-tool-system)
14. [The Welder (Binary Stitcher)](#14-the-welder-binary-stitcher)
15. [Implicit Safety](#15-implicit-safety)
16. [Safety Guarantees](#16-safety-guarantees)
17. [Testing & Validation](#17-testing--validation)
18. [The Alchemical Mirror (REPL)](#18-the-alchemical-mirror-repl)
19. [Remote Execution (Net-Poll)](#19-remote-execution-net-poll)
20. [Architecture & Language Selection](#20-architecture--language-selection)
21. [Implementation Status](#21-implementation-status)
22. [Research Context](#22-research-context)

---

## 1. Overview

Alka is a **non-Turing-complete, contract-driven hardware instruction set** designed for safe, verifiable manipulation of bare metal resources. It operates on the principle that hardware constraints should be encoded as compile-time contracts, not runtime checks.

Alka speaks directly to the PCIe bus. Traditional languages ask the OS for permission; Alka does not.

### What Alka Is For

- **AI Inference**: Stream weights directly from NVMe to VRAM without CPU overhead (the "Moore Stream")
- **Real-Time Control**: Hard nanosecond-precision timing for sensors, FPGA, and ADC devices
- **Hardware Sovereignty**: Operate underneath the OS permission system
- **Security Research**: Forensic audit, attestation, hardware-level threat detection
- **FPGA Orchestration**: Dynamic reconfiguration of KV260 and similar devices

### What Alka Is Not

- A general-purpose programming language
- A replacement for C/Rust in kernel development
- Turing-complete (by design — no loops, no recursion, no arbitrary computation)

---

## 2. Design Philosophy

| Principle | Meaning |
|-----------|---------|
| **Contract-First** | The `.alkavl` (Vial) is the source of truth. Every instruction is validated against physical hardware constraints at compile time. |
| **Zero Overhead** | No interpreter, no runtime. Compiles to fixed-size 32-byte Metrod packets. |
| **State-Assertive** | Declarative ("be in this state"), not imperative ("do this"). |
| **Implicit Safety** | Compiler automatically injects required operations (sliding window loops, thermal checks, barriers). |
| **Polyglot Components** | Each tool can be written in the best language (Zig, C, ASM) and stitched into the binary with zero FFI overhead. |
| **Language as Recipe** | Tools are swappable. A custom compiler with modified tools produces different behavior from the same `.alka` file. |
| **No Assumed Architecture** | The CPU is not privileged. Any hardware node can be the primary actor. |
| **Automatic Antidote** | Every `.alkas` compilation also produces a `.azoth` rollback binary. |
| **Physical Contract** | If the machine doesn't physically support an instruction, it simply doesn't exist for that target. |

---

## 3. File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level instruction sequences (the Recipe) |
| `.alkavl` | The Vial | Physical hardware topology and constraints (the Substrate) |
| `.alkas` | The AlkaSol | Compiled binary solution — the active experiment |
| `.azoth` | The Azoth | Rollback/recovery binary — the antidote |
| `.alkab` | The Precipitate | Legacy name for Metrod binary packets (deprecated, use `.alkas`) |

---

## 4. Terminology

| Term | Definition |
|------|------------|
| **Rack** | Directory containing multiple Vials (hardware configurations) |
| **Vial** (`.alkavl`) | Static description of physical hardware constraints |
| **Recipe** (`.alka`) | High-level instruction script |
| **AlkaSol** (`.alkas`) | Compiled binary — the active experiment |
| **Azoth** (`.azoth`) | Compiled rollback binary — restores pre-execution state |
| **Pharmacopeia** | The modular instruction library (`tools/` folder) |
| **Tool** | A single instruction implementation (validate + execute) |
| **Welder** | The binary stitcher that concatenates tool blobs and patches addresses |
| **Officina** | The compiler (Zig) |
| **Athanor** | The kernel module (`vitriol.ko`) — the hardware executor |
| **Metrod** | The 32-byte binary packet format |
| **Substrate** | The physical hardware reality (PCIe bus, RAM, VRAM, sensors) |
| **Vessel** | A named hardware node within a Vial (GPU, NVMe, FPGA, CPU core) |
| **Aperture** | A memory-mapped I/O window (BAR) within a Vessel |

---

## 5. Language Grammar

### Minimal Syntax (Instruction List)

The simplest Alka program is one instruction per line:

```alka
CLAIM GPU_MAIN;
FLOW NVME_BOOT[0x1000] -> GPU_MAIN.DATA_PLANE[0] 256MB;
FENCE GPU_MAIN.METAPAGE == 1;
SYNC L3;
```

### Full Grammar

```
program         ::= { statement }

statement       ::= directive
                  | instruction
                  | block
                  | if_statement
                  | for_statement
                  | function_def
                  | variable_decl

directive       ::= "REQUIRE" string_literal
                  | "IMPORT" identifier

instruction     ::= IDENTIFIER [ operands ] [ ";" ]

operands        ::= operand { operand }
operand         ::= expression
                  | address
                  | "AS" identifier
                  | "TO" identifier
                  | "VIA" identifier
                  | "INTO" identifier
                  | "FOR" identifier

address         ::= IDENTIFIER [ "[" expression "]" ]

expression      ::= primary { binary_op primary }

primary         ::= number
                  | identifier
                  | memory_size
                  | "(" expression ")"

memory_size     ::= NUMBER UNIT    // e.g. 256MB, 4GB

binary_op       ::= "+" | "-" | "*" | "/" | "==" | "!=" | ">" | "<" | ">=" | "<="
                  | "->"           // FLOW destination arrow
                  | "@"            // SHIFT offset marker
```

### Control Flow (Optional)

```alka
// Conditional
IF gpu_temp > 80 THEN {
    YIELD 1000;
}

// Event handler
ON_SIGNAL "antidote_trigger" {
    REVERT GPU_MAIN.REGISTERS TO safe_state;
}

// Loop
FOR i IN 0..num_windows {
    SHIFT GPU_MAIN.DATA_PLANE @ (i * 256MB);
    FLOW NVME_BOOT[offset + i * 256MB] -> GPU_MAIN[0] 256MB;
}
```

### Variables (Optional)

```alka
LET aperture_size = 256MB;
LET num_windows = model_size / aperture_size;
```

### Functions (Optional)

```alka
FN transfer_chunk(src, dst, size) -> VOID {
    SHIFT dst @ offset;
    FLOW src -> dst[0] size;
    FENCE dst.METAPAGE == 1;
}
```

### Grammar Notes

1. Semicolons are optional in simple programs, required in complex contexts
2. Keywords are uppercase; identifiers are case-sensitive
3. Comments: `//` for single-line
4. All control flow and variable features are optional — the language works with flat instruction lists alone

---

## 6. The Substrate (.alkavl)

The Vial defines the physical laws that Alka must obey. Every `.alka` program requires a target `.alkavl`.

### Syntax

```alkavl
Vessel GPU_MAIN {
    PCI_ID: 10de:1b82;

    Aperture DATA_PLANE {
        BAR: 1;
        MAX_WINDOW: 256MB;
        TYPE: Prefetchable;
    }

    Aperture CTRL_PLANE {
        BAR: 0;
        SIZE: 16MB;
    }

    Thermal SENSOR_0 {
        HALT_AT: 85C;
        THROTTLE_AT: 80C;
    }
}

Vessel NVME_BOOT {
    BLOCK_DEVICE: /dev/nvme0n1;
    DMA_CAPABLE: true;
}

Vessel CPU_CORE_0 {
    ISOLATED: true;
    REAL_TIME: true;
}
```

### Vessel Properties

| Property | Type | Description |
|----------|------|-------------|
| `PCI_ID` | `vendor:device` | Hardware identification |
| `Aperture` | block | Memory-mapped I/O window |
| `Thermal` | block | Temperature limits and sensors |
| `BLOCK_DEVICE` | string | Linux block device path |
| `DMA_CAPABLE` | bool | Whether device supports DMA |
| `ISOLATED` | bool | Whether CPU core is isolated |
| `REAL_TIME` | bool | Whether CPU core runs real-time |

### Aperture Properties

| Property | Type | Description |
|----------|------|-------------|
| `BAR` | u8 | PCI BAR number (0-5) |
| `MAX_WINDOW` | size | Maximum sliding window size |
| `SIZE` | size | Fixed aperture size |
| `TYPE` | enum | `Prefetchable` or `Memory` |

### Thermal Properties

| Property | Type | Description |
|----------|------|-------------|
| `HALT_AT` | temp | Temperature at which execution halts |
| `THROTTLE_AT` | temp | Temperature at which execution throttles |

### Auto-Discovery (Scanner)

The `--probe` and `--probe-all` commands auto-generate `.alkavl` files by digesting:

1. **PCIe Genealogy** (`/sys/bus/pci/devices/`) — BAR bases, sizes, flags
2. **Memory Landscape** (`/proc/iomem`) — RAM gaps, prohibited ranges
3. **Thermal Pulse** (`/sys/class/hwmon/`) — Sensor binding
4. **CPU Birthmark** (`cpuid`) — Feature detection

---

## 7. Complete Instruction Set

### Op-Code Map (58 Instructions)

| Op-Code | Name | Category | Safety | Description |
|---------|------|----------|--------|-------------|
| 0x01 | CLAIM | CORE | L3 | Stake hardware node |
| 0x02 | STAKE | CORE | L3 | Claim memory region |
| 0x03 | FLOW | CORE | L2 | DMA transfer |
| 0x04 | SHIFT | CORE | L2 | Remap BAR window |
| 0x05 | FENCE | CORE | L2 | Wait for condition |
| 0x06 | SYNC | CORE | L2 | Memory barrier |
| 0x07 | SENSE | CORE | L2 | Read sensor |
| 0x08 | PULSE | CORE | L2 | Timing signal |
| 0x09 | SIGNAL | CORE | L2 | Trigger interrupt |
| 0x0A | YIELD | CORE | L2 | Cooperative yield |
| 0x0B | RECAST | FORGING | L2 | FPGA reconfigure |
| 0x0C | SNAP | CORE | L2 | Serialize state |
| 0x0D | REVERT | CORE | L2 | Restore state |
| 0x0E | LIMIT | CORE | L1 | Hard contract |
| 0x0F | VEIL | DISSOLUTION | L1 | Hide from OS |
| 0x10 | DELEGATE | CORE | L2 | CPU bypass |
| 0x11 | RHYTHM | PULSE | L2 | Timing constraint |
| 0x12 | DISTILL | CORE | L3 | Algorithmic synthesis |
| 0x13 | ENQUEUE | CORE | L3 | Command ring |
| 0x14 | MOLT | SOLIDIFICATION | L2 | Full state dump |
| 0x15 | VOUCH | CORE | L2 | Attestation |
| 0x16 | PROBE_BUS | CORE | L3 | Forensic audit |
| 0x17 | ECHO | CORE | L3 | Non-intrusive introspection |
| 0x18 | STASIS | PULSE | L2 | Bus-level locking |
| 0x19 | TRANSVERSE | CORE | L2 | Bit-level swizzling |
| 0x1A | SEARCH | CORE | L3 | Physical signature scanning |
| 0x1B | FOSSILIZE | SOLIDIFICATION | L1 | Substrate persistence |
| 0x1C | STRIKE | DISSOLUTION | CRITICAL | Rowhammer/bit flipping |
| 0x1D | QUENCH | CALCINATION | CRITICAL | Emergency power-state reset |
| 0x1E | FORGE | FORGING | L2 | Bitstream injection |
| 0x1F | VOID | CALCINATION | CRITICAL | Secure substrate erase |
| 0x20 | ABDUCT | TRANSMUTATION | L2 | Physical page stealing |
| 0x21 | SNOOP | TRANSMUTATION | L2 | Cache-coherent monitoring |
| 0x22 | SCATTER | TRANSMUTATION | L2 | Vectored I/O (scatter-gather) |
| 0x23 | WHISPER | DISSOLUTION | L1 | Side-channel extraction |
| 0x24 | GHOST | DISSOLUTION | L1 | Configuration space masking |
| 0x25 | HIJACK | DISSOLUTION | CRITICAL | IRQ stealing |
| 0x26 | DRIFT | PULSE | L2 | Cross-device sync |
| 0x27 | CLONE | SOLIDIFICATION | L2 | Full silicon snapshot |
| 0x28 | CRYSTALLIZE | FORGING | L2 | JIT-to-FPGA |
| 0x29 | OVERCLOCK | CALCINATION | L1 | Sub-driver tuning |
| 0x2A | FLUX | TRANSMUTATION | L2 | Cache invalidation |
| 0x2B | AUDIT | TESTING | L3 | Post-instruction residue check |
| 0x2C | DRY_RUN | TESTING | L3 | Simulate without executing |
| 0x2D | MOCK | TESTING | L3 | Use mock hardware |
| 0x2E | PROVE | TESTING | L3 | Formal verification |
| 0x2F | WATCH | MONITORING | L3 | Real-time monitoring |
| 0x30 | TRACE | MONITORING | L3 | Execution trace |
| 0x31 | GUARD | SAFETY | L1 | Runtime safety sentinel |
| 0x32 | ISOLATE | SAFETY | L1 | Complete hardware isolation |
| 0x33 | VERIFY | SAFETY | L2 | Cryptographic state verification |
| 0x34 | OSSIFY | SUBSTRATE | CRITICAL | Pin CPU core, bypass scheduler |
| 0x35 | BOND | SUBSTRATE | CRITICAL | RAM-to-GPU direct tunnel |
| 0x36 | STILL | SUBSTRATE | CRITICAL | Manual DRAM refresh control |
| 0x37 | RESONATE | SUBSTRATE | CRITICAL | Coordinate reset for pure window |
| 0x38 | OSCILLATE | SUBSTRATE | CRITICAL | Dual-bank refresh coordination |
| 0x39 | IMC_HIJACK | SUBSTRATE | CRITICAL | Direct memory controller access |
| 0x3A | OCCUPY | SUBSTRATE | CRITICAL | Seize PCIe device, sever OS access |

### Safety Levels

| Level | Meaning |
|-------|---------|
| **L1** | Hard contract — will hard abort on violation |
| **L2** | Soft contract — will inject safety operations |
| **L3** | Advisory — informational validation only |
| **CRITICAL** | Requires explicit Vial waiver — can cause physical damage |

---

## 8. Six Alchemical Arts

### I. TRANSMUTATION — Memory & Data Sovereignty

*The art of moving bits without the CPU "Bouncer" ever touching the payload.*

#### ABDUCT <phys_addr> <len>
Physical Page Stealing. Forces the Linux Kernel to "forget" a piece of RAM exists.
```alka
ABDUCT 0xe0000000 256MB;
```

#### SNOOP <bus_addr> -> <vessel>
Cache-Coherent Monitoring. Reads data on the PCIe bus without triggering Read-Completion.
```alka
SNOOP GPU_MAIN.BAR_0 -> traffic_log;
```

#### FLUX <vessel>
Non-Maskable Cache Invalidation. Manually invalidates L1/L2 without `wbinvd`.
```alka
FLUX GPU_MAIN;
```

#### SCATTER <map_vessel> -> <node>
Vectored I/O. Blasts data into non-contiguous VRAM chunks in one transaction.
```alka
SCATTER layer_map -> GPU_MAIN.DATA_PLANE;
```

---

### II. DISSOLUTION — Security & Physical Exploitation

*The art of breaking the "Virtual Illusion" of the Operating System.*

#### STRIKE <target> [PATTERN] [REPS]
Rowhammer / Bit-Flipping via high-frequency non-cached access.
```alka
STRIKE 0xfffffff 0xAAAAAAAA 10000;
```

#### WHISPER <node> [TIMING]
Side-Channel Extraction via nanosecond BAR response timing.
```alka
WHISPER GPU_MAIN.CTRL_PLANE 100ns;
```

#### GHOST <pci_id>
Configuration Space Masking. OS sees "Disconnected" while Alka maintains DMA.
```alka
GHOST 10de:1b82;
```

#### HIJACK <interrupt_vector>
IRQ Stealing. Intercepts hardware signals before the kernel handler.
```alka
HIJACK 0x2f;
```

#### VEIL <vessel>
Substrate Masking. Hides hardware from OS probing.
```alka
VEIL GPU_MAIN;
```

---

### III. THE PULSE — Hard Real-Time & Timing

*The art of nanosecond precision.*

#### RHYTHM <node> <freq> [STRICT]
Hard-Clock Alignment. Bypasses SpeedStep/Turbo Boost.
```alka
RHYTHM CORTICAL_ANNEX 1000Hz STRICT;
```

#### STASIS <bus>
PCIe Bus Locking. Sends "Retry" TLPs to freeze competing traffic.
```alka
STASIS PCIe_X16;
```

#### DRIFT <node_a> <node_b>
Cross-Device Sync. Aligns crystal oscillator cycles.
```alka
DRIFT NVME_BOOT GPU_MAIN;
```

---

### IV. SOLIDIFICATION — Persistence & Firmware

*The art of staying in the machine forever.*

#### FOSSILIZE <alka_seq> -> <node>
Shadow-ROM Injection. Executes at power-on before BIOS.
```alka
FOSSILIZE init_sequence -> GPU_MAIN.ROM;
```

#### CLONE <controller_state> -> <vessel>
Full Silicon Snapshot. Captures entire internal state for perfect REVERT.
```alka
CLONE GPU_MAIN -> gpu_full_backup;
```

#### MOLT <node> -> <vessel>
State Dump. Captures complete register state as Antidote foundation.
```alka
MOLT GPU_MAIN -> gpu_backup;
```

---

### V. FORGING — FPGA & Isomorphic Gates

*The art of turning Thought into Silicon.*

#### FORGE <vessel> INTO <tile>
Partial FPGA Reconfiguration. Changes one tile while others continue.
```alka
FORGE IMP_CORE INTO KV260.TILE_0;
```

#### CRYSTALLIZE <alka_logic> -> <gate_logic>
JIT-to-FPGA. Compiles logic into temporary hardware circuit.
```alka
CRYSTALLIZE inference_branch -> fpga_gate;
```

#### RECAST <vessel> <bitstream>
FPGA Reconfigure (simpler than FORGE).
```alka
RECAST KV260 CORE_METROD;
```

---

### VI. CALCINATION — Stress & Power Mastery

*The art of pushing silicon to its breaking point safely.*

#### QUENCH <node>
Thermal D3-Cold Cut. Physically cuts voltage via PCIe PM registers.
```alka
QUENCH GPU_MAIN;
```

#### OVERCLOCK <node> <voltage> <freq>
Sub-Driver Tuning. Pokes VRM directly to bypass safe limits.
```alka
OVERCLOCK GPU_MAIN 1.1V 2000MHz;
```

#### VOID <node> [SECURE_LEVEL]
Secure Substrate Obliteration. Sanitize at block level.
```alka
VOID NVME_BOOT SECURE;
```

---

## 9. Substrate Orchestration

*The art of coordinating the machine at the deepest level.*

These instructions operate below the OS scheduler, below the memory controller — at the level of physical silicon coordination.

#### OSSIFY <core_id>
Pin CPU core to Alka. Bypasses the Linux scheduler entirely. The core becomes a dedicated Alka execution unit.
```alka
OSSIFY 0;  // Pin core 0
```

#### BOND <ram_addr> -> <gpu_addr> <size>
Create a RAM-to-GPU direct tunnel. Bypasses the IOMMU for a specific memory region.
```alka
BOND 0x100000000 -> GPU_MAIN.VRAM 512MB;
```

#### STILL <dram_bank> [MODE]
Manual DRAM refresh control. Takes over refresh cycles from the memory controller.
```alka
STILL BANK_0 AUTO;
```

#### RESONATE <node_a> <node_b>
Coordinate reset between devices. Ensures both enter a known state simultaneously for a pure execution window.
```alka
RESONATE GPU_MAIN NVME_BOOT;
```

#### OSCILLATE <bank_a> <bank_b>
Dual-bank refresh coordination. Alternates refresh between two DRAM banks for continuous access.
```alka
OSCILLATE BANK_0 BANK_1;
```

#### IMC_HIJACK <imc_channel>
Direct memory controller access. Bypasses the OS memory manager.
```alka
IMC_HIJACK CHANNEL_0;
```

#### OCCUPY <pci_bdf>
Seize PCIe device. Severs all OS access — the device becomes exclusively Alka's.
```alka
OCCUPY 0000:01:00.0;
```

---

## 10. Metrod Binary Format (.alkas)

### Standard Packet (32 bytes)

```
+00: OP_CODE    (1 byte)   - Instruction identifier
+01: FLAGS      (1 byte)   - Execution flags
+02: VESSEL_ID  (2 bytes)  - Target vessel index
+04: SRC_ADDR   (8 bytes)  - Physical source address
+12: DST_ADDR   (8 bytes)  - Physical destination address
+20: SIZE       (4 bytes)  - Transfer size
+24: RESERVED   (4 bytes)  - Alignment padding
+28: CRC        (4 bytes)  - Integrity check (computed over bytes 0-27)
```

### Extended Packet (64 bytes)

Used for complex operations (STRIKE, FORGE, CRYSTALLIZE, etc.):

```
+00: OP_CODE    (1 byte)   - Instruction identifier
+01: INTENSITY  (1 byte)   - Operation intensity
+02: SAFETY     (2 bytes)  - Safety level override
+04: SRC_ADDR   (8 bytes)  - Physical source address
+12: DST_ADDR   (8 bytes)  - Physical destination address
+20: LENGTH     (8 bytes)  - Transfer length
+28: PATTERN    (32 bytes) - Operation pattern/data
+58: AUTH_SIG   (4 bytes)  - Authentication signature
+5C: RESERVED   (4 bytes)  - Padding
```

### CRC Algorithm

CRC is computed over all bytes **excluding** the CRC field itself:

```
crc = 0
for each byte b in packet[0..28]:
    crc = (crc << 1) | (crc >> 31)
    crc ^= b
```

---

## 11. Azoth Rollback Format (.azoth)

The Azoth binary is the **antidote** to the AlkaSol. It is generated alongside every `.alkas` and contains the inverse operations needed to restore the machine to its pre-execution state.

### Generation Rules

| AlkaSol Instruction | Azoth Counterpart |
|---------------------|-------------------|
| CLAIM | REVERT (restore driver binding) |
| FLOW | VOID (overwrite transferred data) |
| SHIFT | SHIFT (restore original offset) |
| STAKE | ABDUCT (release physical pages) |
| VEIL | GHOST (restore PCI visibility) |
| OSSIFY | YIELD (return core to scheduler) |
| BOND | FLUX (invalidate tunnel mappings) |
| OCCUPY | CLAIM (restore OS device access) |
| STRIKE | VOID (sanitize flipped bits) |
| QUENCH | RECAST (restore power state) |

### Azoth Packet Structure

Identical to Metrod packets, but with the `FLAGS` bit 7 set to indicate rollback mode:

```
FLAGS bit 7 = 1  →  Azoth (rollback)
FLAGS bit 7 = 0  →  AlkaSol (forward)
```

### Execution Trigger

Azoth binaries execute automatically when:
1. A `GUARD` condition is violated
2. An `ON_SIGNAL "antidote_trigger"` fires
3. The KV260 dead-man's switch detects heartbeat loss
4. Manual invocation: `alka --rollback <file.azoth>`

---

## 12. Compiler Pipeline

```
.alka + .alkavl
      |
      v
┌─────────────────────────┐
│  Stage 1: Parse          │  Tokenize .alka and .alkavl
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 2: Validate       │  Check against Vial constraints
│  (Tool Dispatch)         │  Each instruction → tool.validate()
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 3: Emit           │  Generate Metrod packets
│  (Metrod Packets)        │  32-byte or 64-byte packets
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 4: Refine         │  Welder pass:
│  (The Welder)            │  - CRC verification
│                          │  - Dead-code stripping (DRY_RUN, MOCK)
│                          │  - Peephole optimization (redundant SYNC)
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 5: Dual Output    │  Emit .alkas + .azoth
└─────────────────────────┘
```

### Implicit Safety Injections

The compiler automatically injects operations:

1. **Automatic Windowing**: If `FLOW` target exceeds aperture, injects `SHIFT` loop
2. **Thermal Shadowing**: Heat-generating instructions wrapped with `SENSE` + `GUARD`
3. **Linear Resource Tracking**: Physical addresses are linear types — cannot be claimed twice
4. **Barrier Injection**: `SYNC L3` auto-injected before `SIGNAL` after `FLOW`

---

## 13. The Pharmacopeia (Tool System)

### Architecture

Each instruction is a **Tool** — a modular, replaceable component with two entry points:

```zig
pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    validate: *const fn (operands: []const u64, ctx: Context) ValidateError!ValidateResult,
    execute: *const fn (operands: []const u64, ctx: Context) Result,
};
```

### Tool Context

```zig
pub const Context = struct {
    physical_addr: u64,
    pci_bus: u8,
    pci_device: u8,
    pci_function: u8,
    bar_base: u64,
    aperture_size: u64,
    thermal_limit: u64,
    current_temp: u64,
};
```

### Validate Result

```zig
pub const ValidateResult = struct {
    allowed: bool,
    injected_operations: []const []const u8,  // Operations the tool wants to inject
    reason: ?[]const u8,
};
```

### Execute Result

```zig
pub const Result = struct {
    success: bool,
    cycles_spent: u64,
    bytes_transferred: u64,
    error_message: ?[]const u8,
};
```

### Tool Directory Structure

```
src/tools/
├── mod.zig              # Tool registry + dispatch
├── interface.zig        # Tool interface definitions
├── core/                # Core tools
│   ├── claim.zig        # CLAIM (0x01) ✓
│   ├── flow.zig         # FLOW (0x03) ✓
│   ├── shift.zig        # SHIFT (0x04) ✓
│   ├── misc.zig         # FENCE, SYNC, SIGNAL, YIELD ✓
│   └── veil.zig         # VEIL (0x0F) ✓
├── substrate/           # Substrate orchestration tools
│   ├── ossify.zig       # OSSIFY (0x34) ✓
│   ├── bond.zig         # BOND (0x35) ✓
│   ├── still.zig        # STILL (0x36) ✓
│   ├── resonate.zig     # RESONATE (0x37) ✓
│   ├── oscillate.zig    # OSCILLATE (0x38) ✓
│   ├── imc_hijack.zig   # IMC_HIJACK (0x39) ✓
│   ├── occupy.zig       # OCCUPY (0x3A) ✓
│   └── strike.zig       # STRIKE (0x1C) ✓
├── forging/             # Forging tools
│   └── void.zig         # VOID (0x1F) ✓
└── pulse/               # Timing tools
    └── sense.zig        # SENSE (0x07) ✓
```

### Tools Requiring Implementation

| Op-Code | Name | Status | Priority |
|---------|------|--------|----------|
| 0x02 | STAKE | Generic stub | Medium |
| 0x08 | PULSE | Generic stub | Medium |
| 0x0B | RECAST | Generic stub | Low |
| 0x0C | SNAP | Generic stub | Medium |
| 0x0D | REVERT | Generic stub | Medium |
| 0x10 | DELEGATE | Generic stub | Low |
| 0x11 | RHYTHM | Generic stub | Low |
| 0x12 | DISTILL | Generic stub | Low |
| 0x13 | ENQUEUE | Generic stub | Low |
| 0x14 | MOLT | Generic stub | Medium |
| 0x15 | VOUCH | Generic stub | Low |
| 0x16 | PROBE_BUS | Generic stub | Low |
| 0x17 | ECHO | Generic stub | Low |
| 0x18 | STASIS | Generic stub | Low |
| 0x19 | TRANSVERSE | Generic stub | Low |
| 0x1A | SEARCH | Generic stub | Low |
| 0x1B | FOSSILIZE | Generic stub | Low |
| 0x1D | QUENCH | Generic stub | Medium |
| 0x1E | FORGE | Generic stub | Low |
| 0x20 | ABDUCT | Generic stub | Medium |
| 0x21 | SNOOP | Generic stub | Low |
| 0x22 | SCATTER | Generic stub | Low |
| 0x23 | WHISPER | Generic stub | Low |
| 0x24 | GHOST | Generic stub | Low |
| 0x25 | HIJACK | Generic stub | Low |
| 0x26 | DRIFT | Generic stub | Low |
| 0x27 | CLONE | Generic stub | Low |
| 0x28 | CRYSTALLIZE | Generic stub | Low |
| 0x29 | OVERCLOCK | Generic stub | Low |
| 0x2A | FLUX | Generic stub | Medium |
| 0x2B | AUDIT | Generic stub | Low |
| 0x2E | PROVE | Generic stub | Low |
| 0x2F | WATCH | Generic stub | Low |
| 0x30 | TRACE | Generic stub | Low |
| 0x31 | GUARD | Generic stub | Medium |
| 0x32 | ISOLATE | Generic stub | Medium |
| 0x33 | VERIFY | Generic stub | Low |

### The Manifest (pharma.json)

The `pharma.json` file tracks every tool's metadata:

```json
{
  "opcode": "0x01",
  "name": "CLAIM",
  "tool": "core/claim.zig",
  "safety": "L3",
  "description": "Stake hardware node",
  "latency_ns": 40
}
```

---

## 14. The Welder (Binary Stitcher)

The Welder performs post-emission refinement on the binary:

### Pass 1: CRC Verification
- Validates every packet's CRC
- Strips corrupted packets

### Pass 2: Dead-Code Stripping
- Removes `DRY_RUN` (0x2C) packets — simulation only
- Removes `MOCK` (0x2D) packets — test hardware only

### Pass 3: Peephole Optimization
- Strips redundant consecutive `SYNC` packets
- Merges adjacent `SHIFT` + `FLOW` sequences when possible

### Future Passes (Planned)
- Address patching from Vial into tool blobs
- Polyglot blob concatenation (C/Zig/ASM tools)
- Variable-length packet support

---

## 15. Implicit Safety

### Automatic Windowing

When a `FLOW` exceeds the aperture's `MAX_WINDOW`:

```alka
// User writes:
FLOW model.weights -> GPU_MAIN.DATA_PLANE;  // 5.5GB

// Compiler generates:
SHIFT GPU_MAIN.DATA_PLANE @ 0;
FLOW ... 256MB;
FENCE ...;
SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
FLOW ... 256MB;
// ... repeat 22 times
```

### Thermal Shadowing

Every heat-generating instruction is wrapped:

```alka
// User writes:
STRIKE 0xfffffff 0xAAAAAAAA 10000;

// Compiler generates:
SENSE GPU_MAIN.THERMAL;
GUARD GPU_MAIN.THERMAL > 85C QUENCH;
STRIKE 0xfffffff 0xAAAAAAAA 10000;
AUDIT GPU_MAIN;
```

### Linear Resource Tracking

Physical addresses are linear types:
- A resource can only be `CLAIM`ed once
- Must be released before re-claiming
- Compile error on double-stake

---

## 16. Safety Guarantees

1. **Compile-Time Verification**: All physical constraints checked before binary emission
2. **No Double-Staking**: Linear types prevent resource conflicts
3. **Thermal Throttling**: Automatic yield injection near thermal limits
4. **Aperture Enforcement**: Sliding window generation for oversized transfers
5. **CRC Integrity**: Every packet validated before execution
6. **Azoth Rollback**: Every forward operation has a defined inverse
7. **Guard Sentinels**: Runtime conditions can trigger automatic rollback

---

## 17. Testing & Validation

### Three-Tier Model

| Tier | Name | Method | Risk |
|------|------|--------|------|
| 1 | **Glass Vial** | Userspace mock hardware | None |
| 2 | **Phantom Substrate** | Kernel dry-run (DRY_RUN flag) | Low |
| 3 | **Sacrificial Canary** | QEMU with memory-mapped files | None |

### Digital Sandboxing

| Tier | Tool | Purpose | Speed |
|------|------|---------|-------|
| 1 | **QEMU** | Functional sandbox — emulate PCIe bus, chipset, MMIO | Reasonable |
| 2 | **Renode** | Multi-node simulation — PC + FPGA in same virtual space | Reasonable |
| 3 | **Gem5** | Cycle-accurate physics lab — DRAM controller timing, capacitor leakage | Slow (1hr = 1sec) |

### QEMU Mock BAR

```bash
-device ivshmem-plain,memdev=hostmem1 \
-object memory-backend-file,id=hostmem1,share=on,mem-path=/tmp/alka_vram,size=256M
```

A 256MB file acts as the GPU's BAR 1. Use `devmem2` inside the VM, hex editor outside — safe experimentation with zero risk to real hardware.

### Testing Instructions

| Instruction | Purpose |
|-------------|---------|
| `AUDIT` | Post-instruction residue check |
| `DRY_RUN` | Simulate without physical side effects |
| `MOCK` | Use virtual hardware representation |
| `PROVE` | Formal verification of invariants |

---

## 18. The Alchemical Mirror (REPL)

The Alka REPL is a **Live Physical Probe Station** — not a traditional code interpreter.

### Design: Transactional REPL

Because Alka instructions are physical assertions, the REPL is **transactional**:

1. **Input**: Type lines of Alka logic
2. **Mirror**: REPL simulates expected state change using the Vial
3. **Flush**: Type `POUR;` to compile and execute

### Interface

The REPL prompt is branded as the **"Swirling A"** — a terminal-based alchemical symbol that appears when jacking into the metal.

```
[ GPU: 42°C | BAR1: 256MB APERTURE | BUS: 0% LOAD | IOMMU: PT ]
Alka ⟴
```

### Launch Syntax

```bash
# Local REPL with Vial
alkac --repl --vial randy_pc_1070ti.alkavl

# Remote REPL (from laptop to target PC)
alkac --connect 192.168.1.50 --vial 1070ti.alkavl
```

### Features

- **Live Telemetry**: Top bar shows real-time hardware EKG
- **Semantic Risk-Highlighting**: `CLAIM` turns **Gold**, `FLOW` turns **Cyan**, `STRIKE` flashes **Magenta** border
- **Peek Mode**: `ECHO` and `SENSE` work without mutating state
- **Ghost Mode**: Simulates what *would* happen using the Alembic (substrate map) before committing with `POUR;`

### Commands

```alka
Alka ⟴ SENSE GPU_MAIN.THERMAL
// Result: 43C (Safe)

Alka ⟴ CLAIM GPU_MAIN.DATA_PLANE
// Result: Driver 'nvidia' unbound. BAR 1 Staked at 0xE0000000.

Alka ⟴ ECHO GPU_MAIN.CONFIG_SPACE[0x04]
// Result: 0x00100007 (Command Register: Bus Master Enabled)

Alka ⟴ POUR;
// Compiles and executes the buffered sequence
```

### Remote Mode

```bash
# From laptop, connect to target PC:
alka --connect 192.168.1.50 --vial 1070ti.alkavl
```

---

## 19. Remote Execution (Net-Poll)

### Architecture

1. **Laptop**: Runs `alka --repl` (The Mind)
2. **Target PC**: Runs Athanor Listener (The Body)
3. **Link**: UDP-based packet injection — the shim intercepts at the **interrupt handler level**, before the kernel's network stack processes packets

### Metrod Network Packet (48 bytes)

```
+00: Standard Alka Instruction  (32 bytes)
+20: Sequence_ID                (8 bytes)  - Prevents replay attacks
+28: Auth_HMAC                  (16 bytes) - Cryptographic proof
+38: Timing_Constraint          (8 bytes)  - Max execution delay (ns)
+40: Reserved                   (8 bytes)
```

### Staged Execution Model

For remote deployment without direct access:
1. **Payload**: Alka fragments embedded in benign-looking files (PNG, PDF via steganography)
2. **Trigger**: Bootstrap assembles fragments into complete `.alkas`
3. **Execution**: Bootstrap hands assembled binary to Athanor via IOCTL

---

### Azoth Heartbeat (KV260 Dead-Man's Switch)

The KV260 FPGA acts as an external watchdog:

1. PC sends a pulse to KV260 every **10ms** via PCIe
2. If pulse stops (PC frozen, kernel panic, or operator dead), KV260 triggers:
   - Sends `QUENCH` to power rail, OR
   - Resets PCIe bus, OR
   - Executes the `.azoth` rollback binary
3. Hardware healed before thermal damage or data loss

This is the ultimate safety net for intrusive operations — the machine heals itself when the operator can't.

---

## 20. Architecture & Language Selection

| Module | Task | Language | Reason |
|--------|------|----------|--------|
| **Officina** (`alkac`) | Logic Compilation | **Zig** | `comptime` for hardware-aware validation |
| **Athanor** (`vitriol.ko`) | Kernel/Hardware Bridge | **C** | Seamless Linux/NVIDIA integration, ABI stability |
| **The Brain** (Orchestrator) | Remote C2 / Logic | **Rust** | Safety and concurrency for remote operations |
| **The Pulse** (Bits) | Jitter-free pokes | **Assembly** | Absolute clock cycle control |

### Why Polyglot Works Here

- Components compile to **naked binary blobs** — no FFI overhead
- No function prologues/epilogues — instructions concatenated directly
- Pharmacopeia acts as **Universal Linker** at the binary level
- Each component compiled with substrate-specific flags (`-march=ivybridge`)

---

## 21. Cybersecurity & Red-Teaming Operations

### USB Exfiltration ("Double Agent")

Alka can leverage USB controllers as covert exfiltration channels by writing directly to DMA buffers, interleaving stolen data with legitimate USB traffic.

#### XHCI Controller Mapping

```alkavl
Vessel USB_CONTROLLER {
    PCI_ID: 1b36:000d;  // Standard XHCI
    DMA_RING_ADDR: 0x...;
    SLACK_SPACE: 4KB;   // Hidden sectors outside partition table
}
```

#### Shadow FLOW

```alka
CLAIM USB_CONTROLLER;
// User copies "benign" file...
FLOW target.secrets_ram -> USB_CONTROLLER.DMA_BUFFER;
// ...interleaved with legitimate transfer
```

#### Detection Counter

`PROBE_BUS` detects mismatch between OS file operations and physical TLP traffic — the same tool that enables exfiltration can detect it.

---

### BYOVD (Bring Your Own Vulnerable Driver)

Alka can exploit legitimate but over-privileged kernel drivers as execution proxies, avoiding the need to load custom kernel modules.

#### Exploitation Vectors

| Vector | Description | Alka Primitive |
|--------|-------------|----------------|
| **WebGPU/Vulkan Escape** | Browser shader OOB access to BAR registers | `FLOW`, `SHIFT` |
| **ROP Gadget Heist** | Chain existing kernel code (`nvidia.ko`, `xhci-hcd.ko`) as primitives | `ENQUEUE`, `DELEGATE` |
| **Signed Driver Proxy** | Use legitimate but over-privileged driver as Alka runner | `CLAIM`, `HIJACK` |

#### Gadget Finder

A tool to scan existing kernel driver binaries for sequences matching Alka opcodes:
- Scan `nvidia.ko`, `xhci-hcd.ko`, etc. for `FLOW`/`SHIFT`/`CLAIM` equivalent sequences
- Emit "Address Lists" instead of raw bytecode — the driver does the hardware access on Alka's behalf

---

### Staged Execution Model

For remote deployment without direct access, Alka supports multi-stage payload delivery:

1. **Stage 1 (Payload)**: Alka fragments embedded in benign-looking files (PNG, PDF via steganography)
2. **Stage 2 (Trigger)**: Exploit triggers bootstrap to assemble fragments into complete `.alkas`
3. **Stage 3 (Execution)**: Bootstrap hands assembled binary to Athanor via IOCTL

This model enables:
- **Air-gap crossing**: Payload delivered via removable media
- **Email delivery**: Fragments split across multiple attachments
- **Web delivery**: Fragments served as normal web resources

---

### Antidote System (State Restoration)

Every intrusive Alka operation should have a defined rollback path.

#### State Restoration Workflow

```alka
// Before experiment - capture "Safe State"
SNAP GPU_MAIN.REGISTERS AS safe_gpu;
SNAP USB_XHCI AS safe_usb;

// Experiment execution...
CLAIM GPU_MAIN;
FLOW payload -> GPU_MAIN.DRAM;

// On signal "antidote" - restore
ON_SIGNAL "antidote_trigger" {
    REVERT safe_gpu -> GPU_MAIN.REGISTERS;
    REVERT safe_usb -> USB_XHCI;
    PRINT "Physical State Restored";
}
```

#### MOLT-based Restoration

```alka
MOLT USB_XHCI -> backup;
REVERT backup -> USB_XHCI;
```

#### Azoth Auto-Generation

The compiler automatically generates `.azoth` rollback binaries alongside `.alkas`:

| AlkaSol Instruction | Azoth Counterpart |
|---------------------|-------------------|
| `CLAIM` | Restore driver binding |
| `FLOW` | `VOID` (overwrite transferred data) |
| `SHIFT` | `SHIFT` (restore original offset) |
| `STAKE` | Release physical pages |
| `VEIL` | `GHOST` (restore PCI visibility) |
| `OSSIFY` | `YIELD` (return core to scheduler) |
| `BOND` | `FLUX` (invalidate tunnel mappings) |
| `OCCUPY` | `CLAIM` (restore OS device access) |
| `STRIKE` | `VOID` (sanitize flipped bits) |
| `QUENCH` | `RECAST` (restore power state) |

---

### Hardware-Assisted Zero Trust

Alka serves as both attack and defense tool for hardware-level security.

| Technique | Description | Alka Instructions |
|-----------|-------------|-------------------|
| **CDR (Content Disarm)** | Strip all metadata, re-render pixels — destroys steganographic payloads | `DISTILL`, `TRANSVERSE` |
| **Remote Browser Isolation** | Execute web content in cloud container — GPU exploits hit disposable server | `DELEGATE`, `ISOLATE` |
| **Control Flow Guarding** | Intel CET detects illegal RIP jumps from ROP chains | `GUARD`, `AUDIT` |
| **Physical Firewall** | IOMMU enforces static memory partitioning | `LIMIT`, `FENCE` |
| **Bus Monitoring** | KV260 monitors PCIe bus for anomalous TLP patterns | `SNOOP`, `PROBE_BUS` |
| **TPM Attestation** | Cryptographic verification of critical memory regions | `VOUCH`, `VERIFY` |

---

### Zero Trust Attack Vectors (Offensive Analysis)

Alka operates at the boundary between the **Linguistic Layer** (IAM, JWT, RDP certificates, usernames) and the **Substrate Layer** (PCIe bus, NIC buffers, GPU VRAM). Traditional security protects the Linguistic Layer; Alka speaks the Substrate.

#### What Alka Learns Through Physical Snooping

| Target | What's Found | Method |
|--------|-------------|--------|
| TPM → CPU bus | Decryption keys in transit | `SNOOP` |
| RAM page tables | Physical address of "Allow_RDP" bit | `ABDUCT`, `SEARCH` |
| PCIe Config Space | HWID (Hardware Identity) | `ECHO` |
| GPU VRAM | Verified Device status bits | `SENSE` |

#### The RDP Reach-Through

A vector payload hidden in a UI element is reconstructed by the GPU into an Alka Instruction that `ABDUCT`s the physical RAM belonging to the IAM service. No file on disk, no process in `ps` — the attack lives in the display pipeline.

#### Trusted Device Identity Theft

A PC's identity isn't its IP or username — it's its **HWID**, which is just bits in PCIe Config Space. Using `VEIL` + `HIJACK`, Alka can reflect a legitimate device's HWID to impersonate it on the network.

#### IoT Weak Link

`HIJACK` an IP camera, use the NIC as a UDP artillery battery through relaxed firewall rules. IoT devices typically have no IOMMU, no TPM, and permissive network policies.

---

### Ghost Processes & Viral Substrate Hopping

#### Invisible Execution

Using `DELEGATE` (0x10) + `VEIL` (0x0F), Alka moves logic into peripheral micro-controllers (GPU firmware, KV260 ARM core). No x86 instructions execute — no PID exists. `top`, `ps`, and EDR show nothing.

#### Viral Transmutation Paths

| Path | Method | Persistence |
|------|--------|-------------|
| **Peripheral Leap** | `FOSSILIZE` writes Alka binary into Option ROM; move device to new PC → executes on power-up | Hardware-level |
| **Bus-to-Bus Infection** | `CLAIM` the NIC, blast raw UDP; packets land in target's DMA Ring Buffer, auto-brewed into AlkaSol | Network-level |
| **VRAM Carving** | SVG/WebGL forces browser to allocate massive VRAM buffer; Alka stub hidden in high-entropy pixels | Session-level |

#### The Sovereignty War

When two Alka operators target the same machine:
- Attacker sends AlkaSol, Defender sends Azoth
- Race of Physical State Restoration
- Whoever controls `REVERT` with highest `RHYTHM` wins

---

### PHINT: Probing Unknown Hardware Remotely

When you don't have a datasheet, treat the device as a **Black Box Signal Processor**.

#### Active Stimulus & Side-Channel Response

| Technique | Method | What It Reveals |
|-----------|--------|-----------------|
| **Register Echo** | Toggle bits on BAR offsets, observe response | Classifies registers: Command vs Config vs Live Sensor |
| **WHISPER Side-Channel** | Measure nanosecond jitter on BAR access | Distinguishes SRAM vs DRAM vs logic state |
| **Interrupt Signature** | `HIJACK` interrupts before OS; classify by pattern | 60Hz = Display, Burst = Storage/Network, Stochastic = RNG |

#### The Remote Mirror (KV260 Bridge)

1. `SNAP` unknown device registers every 10ms on target
2. Send snapshots via UDP to lab machine
3. `FORGE` register map on KV260 FPGA
4. Digital Twin available for safe probing — no risk to production hardware

---

### Substrate Sonar: Global Discovery

#### The Physical Beacon

A GPU writes a unique 64-bit "Meme-Constant" to a predictable BAR1 offset. This constant is the device's **physical identity** — not an IP, not a hostname, but a frequency.

#### RESONANCE_SCAN (0x47)

Blasts raw UDP packets with a mathematical challenge. Any Alka beachhead on the network recognizes the constant and triggers `SIGNAL` back.

#### Rapid Precipitation Workflow

1. Sonar finds blip on network
2. Officina sees echo, identifies device class
3. Auto-brew `.alkavl` for target hardware
4. Blast payload via `TUNNEL` (0x3F)
5. Substrate occupied

#### Defensive Application: Attestation-at-Scale

Send the "Meme" to all employee PCs. Run Alka Sonar. Non-responding PC = potentially compromised (Alka presence removed or device replaced).

---

### Network Identity Obfuscation

When operating remotely, Alka traffic must blend into legitimate network noise.

#### Raw Packet Synthesis

Bypass the kernel's automatic source IP labeling. `FORGE_HEADER` pulls entropy from GPU/KV260 to generate a new source IP per packet. Limited only by BCP 38 (ingress filtering).

#### Distributed Substrate Proxies

"Blip" nodes act as intermediate proxies. Traffic appears to come from legitimate user machines, not the operator.

#### Traffic Transmutation

`STOCHASTIC_FLOW` adds intentional high-precision jitter per packet. Traffic profile matches browser-background-sync or video-stream buffer — indistinguishable from legitimate HTTPS.

#### Attribution Countermeasures

| Technique | What It Detects | Alka Counter |
|-----------|-----------------|-------------|
| NetFlow/IPFIX | Asymmetric flows | Symmetric padding via `SCATTER` |
| TTL Fingerprinting | Distance traveled | TTL normalization at proxy nodes |
| Physical Clock Skew | Unique crystal oscillator fingerprint | `RHYTHM`-based clock alignment |

---

### The 5 Axioms of Alka Architecture

1. **Hardware is a physical territory** — Taking over a PC is occupation of space, not password hacking
2. **The Box doesn't have a lock on the inside** — If you're inside the hardware, you decide what the OS sees
3. **Identity is a Frequency** — PC identity is "Response to the Meme-Constant," not IP or username
4. **Simulation is the first step of Transmutation** — Digital sandbox before live pour
5. **The machine wants to be known** — Hardware broadcasts identity across PCIe bus 1000x/sec. Software ignores it. Alka listens.

---

### Additional Instructions (Research/Advanced)

These instructions are defined for advanced operations but not yet in the core opcode table:

| Op-Code | Name | Category | Description |
|---------|------|----------|-------------|
| 0x3B | COALESCE | SUBSTRATE | State mirroring via FPGA KV260 anchor |
| 0x3F | TUNNEL | NETWORK | Full payload blast back via network |
| 0x40 | PROBE | SCANNER | Substrate scan → outputs formatted `.alkavl` |
| 0x41 | HEARKEN | DISSOLUTION | Interrupt interception and classification |
| 0x42 | BARRAGE | NETWORK | Raw UDP packet blasting to DMA Ring Buffer |
| 0x43 | FORGE_HEADER | NETWORK | Raw packet synthesis with entropy-pulled source IP |
| 0x44 | STOCHASTIC_FLOW | NETWORK | Traffic transmutation — intentional jitter per packet |
| 0x47 | RESONANCE_SCAN | SCANNER | Substrate sonar — blast UDP with mathematical challenge |

---

### Efficiency Comparison: AlkaSol vs Standard Binary

| Feature | Standard Binary (LLVM/GCC) | AlkaSol (Stitched) |
|---------|---------------------------|---------------------|
| **Instruction Density** | High (lots of "Glue" code) | **Absolute (100% Signal)** |
| **Branch Penalty** | Frequent (Function calls) | **Zero (Linear Execution)** |
| **Variable Passing** | Stack/Registers (Slow/Messy) | **Shared Vessel (Physical Offset)** |
| **Optimization** | General (Safe for many PCs) | **Substrate-Perfect (Your PC Only)** |

### Shared Vessel Convention

Register R15 (or equivalent) points to a **substrate context** — all tool components read/write state via fixed physical offsets, eliminating parameter passing overhead. This is the ABI convention that makes polyglot stitching possible without FFI.

### Post-Precipitation Optimization

The Welder's refinement pass is formally called **Post-Precipitation Optimization**. Beyond CRC verification and dead-code stripping, it:
- Strips glue code between instruction blobs
- Removes dead branches identified by Vial constraints
- Merges adjacent instructions (e.g., if `CLAIM` sets a bit that `FLOW` checks, the check is elided)

---

### Complexity Classification

| Complexity | Instructions |
|------------|--------------|
| **Low** | CLAIM, STAKE, YIELD, SNAP, REVERT, LIMIT, SIGNAL, RECAST, AUDIT, DRY_RUN, PROVE, TRACE |
| **Medium** | FLOW, SHIFT, FENCE, SYNC, SENSE, PULSE, ECHO, VOUCH, STASIS, FLUX, MOLT, CLONE, ENQUEUE, TRANSVERSE, MOCK, WATCH, GUARD, VERIFY |
| **High** | DELEGATE, RHYTHM, VEIL, SEARCH, FOSSILIZE, STRIKE, GHOST, HIJACK, DRIFT, FORGE, QUENCH, OVERCLOCK, VOID, WHISPER, DISTILL, PROBE_BUS, ABDUCT, ISOLATE |
| **Extreme** | STRIKE (Rowhammer), FOSSILIZE (Shadow-ROM), ABDUCT (Page Stealing), SCATTER (Vectored I/O), CRYSTALLIZE (JIT-to-FPGA) |

---

## 22. Implementation Status

### Complete
| Component | Status |
|-----------|--------|
| Zig compiler (parser, validator, emitter) | Working |
| Metrod packet format (32-byte) | Working |
| CRC computation and verification | Working |
| Welder refinement pass | Working |
| Tool validation dispatch | Working |
| Hardware scanner (`--probe`, `--probe-all`) | Working |
| VSIX extension with risk-based coloring | Working |
| 15 tool implementations | Working |
| Apache 2.0 + Runtime Exception license | Applied |

### VSIX Extension Details

The VSIX uses standard **TextMate scopes** (`keyword.control`, `string.quoted.double`, `comment.line`) so syntax highlighting works with any theme. The **"Alka Officina"** theme adds risk-based coloring on top:

| Risk Tier | Color | Keywords | Physical Impact |
|-----------|-------|----------|-----------------|
| **Tier 0 (Logic)** | **Lime** | `FOR`, `LET`, `IF` | Zero risk (CPU only) |
| **Tier 1 (Flow)** | **Cyan** | `FLOW`, `SHIFT` | Standard Bus Traffic |
| **Tier 2 (Sovereign)** | **Gold** | `CLAIM`, `VOUCH` | Driver Unbinding |
| **Tier 3 (Dissolution)** | **Magenta** | `STRIKE`, `ABDUCT` | **PHYSICAL STRESS** |
| **Tier 4 (Antidote)** | **Orange** | `REVERT`, `MOLT` | State Restoration |

### In Progress
| Component | Status |
|-----------|--------|
| Azoth rollback binary generation | Not started |
| Extended packet format (64-byte) | Defined, not implemented |
| Vial parser (full Aperture/Thermal parsing) | Partial |
| Remaining 43 tool implementations | Stubbed |
| `build.zig` build system | Not started |

### Planned
| Component | Priority |
|-----------|----------|
| Athanor kernel module (`vitriol.ko`) | High |
| REPL (`--repl` mode) | Medium |
| Net-Poll remote execution | Medium |
| QEMU test harness | Medium |
| Azoth automatic generation | High |
| Polyglot blob stitching | Low |
| Variable-length packet support | Low |
| Control flow parsing (IF, FOR, FN) | Low |

---

## 22. Research Context

Alka operates at the **Hardware-Software Integrity Gap**.

### Core Principles

- **Substrate Sovereignty**: The OS is a "virtual reality" over physical reality
- **MMU Bypass**: DMA/P2P transfers don't consult CPU permission bits
- **Data-to-Execution Bridge**: The distinction between "data" and "instruction" is an OS convenience, not a physical truth
- **Physical Topography**: If you control where bits sit in physical memory, you control the machine

### Applications

- **Optimizing** AI workloads (Moore Stream — NVMe→VRAM direct transfer)
- **Securing** systems against hardware-level threats (Forensic Audit, Attestation)
- **Exploring** the boundary between software and silicon

### Defense Research

- **CDR (Content Disarm)**: Strip metadata, re-render pixels — destroys steganographic payloads
- **Remote Browser Isolation**: Execute web content in disposable containers
- **Physical Firewall**: IOMMU enforces static memory partitioning; KV260 monitors PCIe bus
- **TPM Attestation**: Cryptographic verification of critical memory regions

---

*Alka v3.0 — The Universal Solvent*
*"The solvent that dissolves the boundary between software and silicon."*
