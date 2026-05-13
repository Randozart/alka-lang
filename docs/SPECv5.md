# Alka Language Specification v5.1

> The "Universal Solvent" for physical machine state orchestration
>
> **Version**: 5.1 (Authoritative)
> **Timestamp**: 2026-05-13
> **Supersedes**: SPEC.md, SPECv2.md, SPECv3.md, SPECv4.md, SPECv5.md
> **Status**: Living document — this file is the single source of truth
>
> **Major changes from v5.0**:
> - No `;` terminator — newlines terminate instructions (see §5)
> - Dot-reference `.Member` syntax for context-based vessel addressing (see §5)
> - `!!` override directive — per-instruction chain validation bypass (see §5)
> - Flexible unit capitalization — all case-insensitive formats supported (see §5)
> - `CLAIM!` force re-claim syntax (see §7)
> - Zig LSP server for real-time validation, autocomplete, and hover (see §23)
> - VSCodium extension support via OpenVSX (see §23)
> - Expanded pharmacopia with parameter metadata for tool introspection (see §16)

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
10. [Dataflow & Pipes](#10-dataflow--pipes)
11. [Distributed Substrate Mesh](#11-distributed-substrate-mesh)
12. [Tool Chaining](#12-tool-chaining)
13. [Metrod Binary Format (.alkas)](#13-metrod-binary-format-alkas)
14. [Azoth Rollback Format (.azoth)](#14-azoth-rollback-format-azoth)
15. [Compiler Pipeline](#15-compiler-pipeline)
16. [The Pharmacopeia (Tool System)](#16-the-pharmacopeia-tool-system)
17. [The Welder (Binary Stitcher)](#17-the-welder-binary-stitcher)
18. [Implicit Safety](#18-implicit-safety)
19. [Safety Guarantees](#19-safety-guarantees)
20. [Testing & Validation](#20-testing--validation)
21. [The Alchemical Mirror (REPL)](#21-the-alchemical-mirror-repl)
22. [Remote Execution (Net-Poll)](#22-remote-execution-net-poll)
23. [The Pharmacist's Gloss](#23-the-pharmacopists-gloss)
24. [SPARK-First Policy](#24-spark-first-policy)
25. [Implementation Roadmap](#25-implementation-roadmap)
26. [Cybersecurity & Red-Teaming Operations](#26-cybersecurity--red-teaming-operations)
27. [Research Context](#27-research-context)
28. [Practitioner's Companion](#28-practitioners-companion)

---

## 1. Overview

Alka is a **non-Turing-complete, contract-driven hardware instruction set** designed for safe, verifiable manipulation of bare metal resources. It operates on the principle that hardware constraints should be encoded as compile-time contracts, not runtime checks.

Alka speaks directly to the PCIe bus. Traditional languages ask the OS for permission; Alka does not.

### What Alka Is

> *"Alka is a way to orchestrate otherwise complex and dangerous, or even terribly mundane instructions, and turn them into a powerhouse of a runtime."*

Alka is a **binary stitcher for polyglot micro-programs, governed by a hardware config file.** Each tool is written in whatever language suits the task (SPARK Ada, Zig, C, ASM, SystemVerilog), compiled to a naked binary blob, and the Alka compiler stitches them together at the binary level. No FFI. No function calls. No interpreter. Just one continuous train of thought executed at the speed of the electrical traces.

### What Alka Is For

- **AI Inference**: Stream weights directly from NVMe to VRAM without CPU overhead (the "Moore Stream")
- **Real-Time Control**: Hard nanosecond-precision timing for sensors, FPGA, and ADC devices
- **Hardware Sovereignty**: Operate underneath the OS permission system
- **Security Research**: Forensic audit, attestation, hardware-level threat detection
- **FPGA Orchestration**: Dynamic reconfiguration of KV260 and similar devices
- **Dataflow Pipelines**: Continuous autonomous DMA streaming between hardware endpoints
- **Distributed Substrate**: Treat multiple machines as a single silicon body via network or direct cable links
- **Speculative Decoding**: Use small GPUs as draft models for large GPU verification
- **Cybersecurity**: Embed verified hardware operations in host binaries, persistent substrate manipulation

### What Alka Is Not

- A general-purpose programming language
- A replacement for C/Rust in kernel development
- Turing-complete (by design — no loops, no recursion, no arbitrary computation)
- A "pure" language — it is 100% side-effects, designed to mutate physical state

### The Core Realization

Alka is **not a "real" programming language** in the academic sense. It has no AST, no scoping rules, no standard library. What it is:

- **Motherboard Microcode**: Takes high-level intent and sequences the physical gate-switches of the PCIe bus, NVMe controller, and GPU memory
- **The Unix Philosophy Applied to Silicon**: Each tool does one thing well; the PCIe bus is the pipe
- **A Pharmacopeia (Forth for 2026)**: Instead of a dictionary of words, a library of adaptive primitives that precipitate optimal logic based on hardware affordances

---

## 2. Design Philosophy

| Principle | Meaning |
|-----------|---------|
| **Contract-First** | The `.alkavl` (Vial) is the source of truth. Every instruction is validated against physical hardware constraints at compile time. |
| **Zero Overhead** | No interpreter, no runtime. Compiles to fixed-size 32-byte Drop packets. |
| **State-Assertive** | Declarative ("be in this state"), not imperative ("do this"). |
| **Implicit Safety** | Compiler automatically injects required operations (sliding window loops, thermal checks, barriers). |
| **Polyglot Components** | Each tool can be written in the best language (SPARK, Zig, C, ASM) and stitched into the binary with zero FFI overhead. |
| **Language as Recipe** | Tools are swappable. A custom compiler with modified tools produces different behavior from the same `.alka` file. |
| **No Assumed Architecture** | The CPU is not privileged. Any hardware node can be the primary actor. |
| **Automatic Antidote** | Every `.alkas` compilation also produces a `.azoth` rollback binary. |
| **Physical Contract** | If the machine doesn't physically support an instruction, it simply doesn't exist for that target. |
| **Affordance-Based** | Components are substrate-aware, not hardware-hardcoded. They interrogate the Vial and precipitate optimal logic. |
| **Deterministic Self-Explanation** | Because the language is non-Turing-complete and anchored to an immutable Vial, the Gloss (inlay hints) is a human-language projection of mathematical certainty. |
| **Cooking with Hardware** | The compiler has empathy — it auto-chunks, auto-windows, and auto-validates so the human focuses on the Recipe while the machine handles the Oven. |
| **Tool Generality** | Every tool is a generic primitive, not a use-case-specific operation. Tools compose across any hardware target. |
| **Chain Validation** | Tool sequences form logical chains. The compiler validates pre/post states and warns on risky sequences. |

### The Unix Philosophy, Applied to Silicon

Unix (1978): *Make each program do one thing well. Pipe the output of one into the input of another.*

Alka: *Make each hardware operation a hyper-specialized tool. Pipe the physical state from one to another across the PCIe bus.*

Instead of piping text between software processes, **Alka pipes electricity between silicon chips.**

- `CLAIM` doesn't know what a GPU is. It only knows how to unbind a driver.
- `SHIFT` doesn't know about tensors. It only knows how to move a BAR window.
- `FLOW` doesn't know about LLMs. It only knows how to trigger a P2P DMA transfer.
- `POKE` doesn't know about rowhammer. It only knows how to write a pattern to an address.

### The Myth of "Purity"

A "Pure" language (like Haskell) has zero side-effects. Hardware is *nothing but side-effects.* Flipping a bit in a register changes the voltage of a wire.

**Alka is the Anti-Haskell.** It is 100% side-effects. It doesn't do math. Its only purpose is to mutate the physical state of the universe.

Trying to make a hardware-manipulation language "Pure" is like trying to make a hammer out of glass. The "messy" folder of tools is exactly what a toolbox is supposed to look like.

### The Mandolin Principle

When a musician plugs an electric guitar into a pedalboard, they don't "write code" for the distortion pedal. They plug a physical 1/4-inch cable from the `OUT` of the guitar to the `IN` of the pedal.

**Alka Pipes are 1/4-inch cables for silicon chips.**

### SPARK-First Policy

All base hardware-manipulation tools are written in SPARK Ada and formally verified. This is not optional — it is the foundation of Alka's safety guarantees. See §24 for details.

---

## 3. File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level instruction sequences (the Recipe) |
| `.alkavl` | The Vial | Physical hardware topology, constraints, and affordances (the Substrate) |
| `.alkas` | The AlkaSol | Compiled binary solution — the active experiment |
| `.azoth` | The Azoth | Rollback/recovery binary — the antidote |
| `.alkab` | The Precipitate | Legacy name for Metrod binary packets (deprecated, use `.alkas`) |
| `.alkagraph` | The Graph | Node-graph visualization of an `.alka` file (auto-generated by VSIX) |
| `.alkar` | The Residue | Embed metadata — encrypted Drops inside a host binary (Phase 3) |

---

## 4. Terminology

| Term | Definition |
|------|------------|
| **Rack** | Directory containing multiple Vials (hardware configurations) |
| **Vial** (`.alkavl`) | Static description of physical hardware constraints and affordances |
| **Recipe** (`.alka`) | High-level instruction script |
| **AlkaSol** (`.alkas`) | Compiled binary — the active experiment |
| **Azoth** (`.azoth`) | Compiled rollback binary — restores pre-execution state |
| **Pharmacopeia** | The modular instruction library (`tools/` folder) |
| **Tool** | A single instruction implementation (validate + execute) |
| **Welder** | The binary stitcher that concatenates tool blobs and patches addresses |
| **Officina** | The compiler (Zig) |
| **Athanor** | The kernel module (`vitriol.ko`) — the hardware executor |
| **Drop** | The 32-byte binary packet (formerly "Metrod") |
| **Substrate** | The physical hardware reality (PCIe bus, RAM, VRAM, sensors) |
| **Vessel** | A named hardware node within a Vial (GPU, NVMe, FPGA, CPU core) |
| **Aperture** | A memory-mapped I/O window (BAR) within a Vessel |
| **Affordance** | A capability declaration — what a Vessel *can do*, not just what it *is* |
| **Pipe** | A continuous DMA ring buffer — hardware runs autonomously after initiation |
| **Tunnel** | A distributed substrate link — treats remote machines as local silicon |
| **Gloss** | Inlay hints generated by the VSIX — self-explaining code via deterministic projection |
| **Precipitation** | The process by which a component generates optimal binary logic based on Vial affordances |
| **Chain** | A sequence of tools where each tool's post-state satisfies the next tool's pre-state |
| **Override** | A per-instruction line (`!!`) that suppresses chain validation for the next instruction |
| **Dot-Reference** | A `.Member` syntax that resolves against the active vessel context established by `CLAIM` |
| **Gloss** | Inlay hints generated by the Zig LSP server — self-explaining code via deterministic projection |
| **LSP** | The Language Server Protocol server (`alka-lsp`) providing real-time validation, autocomplete, and hover |

### Grammar Notes

1. Newlines terminate instructions — no semicolons. The `;` character is reserved for future use.
2. Keywords are uppercase; identifiers are case-sensitive
3. Comments: `//` for single-line
4. Dot-prefixed identifiers (`.VRAM`, `.BAR1`) resolve against the active vessel context established by the most recent `CLAIM`
5. `!!` can appear on its own line or inline before an instruction: both `!!` and `!! SLICE .VRAM 0 512MB` are valid
6. Memory size units are case-insensitive: `MB`, `Mb`, `mB`, `mb`, `MiB`, `KiB`, `GiB`, `TiB` all work
7. All control flow and variable features are optional — the language works with flat instruction lists alone
8. `=>` is reserved for PIPE definitions; `->` is reserved for FLOW destinations

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

    Memory VRAM {
        TOTAL: 8GB;
        RESERVED: 256MB;
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
| `Memory` | block | VRAM/RAM capacity and reservations |

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

### Affordances (v5.0)

Affordances describe **what a Vessel can do**, not just what it is. Components interrogate affordances at compile-time to precipitate optimal logic.

```alkavl
Vessel GPU_1070TI {
    PCI_ID: 10de:1b82;

    AFFORDANCE: DMA_MASTER;
    AFFORDANCE: P2P_SOURCE;
    AFFORDANCE: VOLATILE_REFRESH;
    AFFORDANCE: BAR_SLIDING_WINDOW {
        CONTROL_REG: 0x4000;
        MAX_STEP: 256MB;
    }
}

Vessel GPU_960 {
    PCI_ID: 10de:1401;

    AFFORDANCE: P2P_SINK;
    AFFORDANCE: BAR_SLIDING_WINDOW {
        CONTROL_REG: 0x4000;
        MAX_STEP: 256MB;
    }
    AFFORDANCE: SPECULATIVE_DRAFT {
        MAX_MODEL_SIZE: 500MB;
        TOKEN_RATE: 100;
    }
}
```

### Affordance Types

| Affordance | Description | Used By |
|------------|-------------|---------|
| `DMA_MASTER` | Can initiate DMA transfers | `FLOW`, `SCATTER` |
| `DMA_SLAVE` | Can receive DMA transfers | `FLOW`, `SCATTER` |
| `P2P_SOURCE` | Can send P2P data directly | `FLOW`, `PIPE` |
| `P2P_SINK` | Can receive P2P data directly | `FLOW`, `PIPE` |
| `BAR_SLIDING_WINDOW` | Supports aperture remapping | `SHIFT`, `SLICE` |
| `RESIZABLE_BAR` | Supports Resizable BAR | `SHIFT` |
| `SOFTWARE_MAPPED` | Requires software emulation | `SHIFT` |
| `VOLATILE_REFRESH` | Manual DRAM refresh control | `SUSPEND`, `COORDINATE` |
| `SPECULATIVE_DRAFT` | Can run draft models | `SPECULATE` |
| `NETWORK_BRIDGE` | Can establish network bonds | `TUNNEL`, `ICHOR` |
| `VIDEO_OUTPUT` | Can transmit via display port | `BEAM` |
| `VIDEO_INPUT` | Can receive via capture | `BEAM` |
| `NV_CAPABLE` | Has non-volatile storage | `PERSIST` |

### Auto-Discovery (Scanner)

The `--probe` and `--probe-all` commands auto-generate `.alkavl` files by digesting:

1. **PCIe Genealogy** (`/sys/bus/pci/devices/`) — BAR bases, sizes, flags
2. **Memory Landscape** (`/proc/iomem`) — RAM gaps, prohibited ranges
3. **Thermal Pulse** (`/sys/class/hwmon/`) — Sensor binding
4. **CPU Birthmark** (`cpuid`) — Feature detection
5. **Affordance Inference** — Capabilities derived from detected hardware features

---

## 7. Complete Instruction Set

### Op-Code Map (64 Instructions)

**Legend**: `[SPARK]` = formally verified in SPARK Ada. `[ZIG]` = implemented in Zig. `[PLANNED]` = not yet implemented. `[→ SPARK]` = should become SPARK-verified.

| Op-Code | Name | Category | Safety | Lang | Description |
|---------|------|----------|--------|------|-------------|
| 0x01 | CLAIM | CORE | L3 | [SPARK] | Take ownership of a hardware node |
| 0x02 | STAKE | CORE | L3 | [→ SPARK] | Reserve a memory region |
| 0x03 | FLOW | CORE | L2 | [SPARK] | DMA transfer between two addresses |
| 0x04 | SHIFT | CORE | L2 | [SPARK] | Remap a memory window (BAR) |
| 0x05 | FENCE | CORE | L2 | [SPARK] | Wait for a condition |
| 0x06 | SYNC | CORE | L2 | [→ SPARK] | Memory barrier |
| 0x07 | SENSE | CORE | L2 | [ZIG] | Read a sensor |
| 0x08 | PULSE | CORE | L2 | [→ SPARK] | Emit a timing signal |
| 0x09 | SIGNAL | CORE | L2 | [SPARK] | Trigger an event/interrupt |
| 0x0A | YIELD | CORE | L2 | [→ SPARK] | Cooperative yield |
| 0x0B | RECAST | FORGING | L2 | [→ SPARK] | Reconfigure a device |
| 0x0C | SNAP | CORE | L2 | [→ SPARK] | Serialize state (merged with MOLT) |
| 0x0D | REVERT | CORE | L2 | [→ SPARK] | Restore state |
| 0x0E | LIMIT | CORE | L1 | [→ SPARK] | Enforce a constraint |
| 0x0F | ~~VEIL~~ | — | — | — | **Merged into CLAIM** (STEALTH flag) |
| 0x10 | DELEGATE | CORE | L2 | [PLANNED] | CPU bypass |
| 0x11 | RHYTHM | PULSE | L2 | [→ SPARK] | Timing constraint |
| 0x12 | DISTILL | CORE | L3 | [PLANNED] | Algorithmic synthesis |
| 0x13 | ENQUEUE | CORE | L3 | [PLANNED] | Command ring |
| 0x14 | ~~MOLT~~ | — | — | — | **Merged into SNAP** |
| 0x15 | VOUCH | CORE | L2 | [PLANNED] | Attestation |
| 0x16 | PROBE_BUS | CORE | L3 | [PLANNED] | Forensic audit |
| 0x17 | ECHO | CORE | L3 | [ZIG] | Non-intrusive introspection |
| 0x18 | STASIS | PULSE | L2 | [→ SPARK] | Bus-level locking |
| 0x19 | TRANSVERSE | CORE | L2 | [PLANNED] | Bit-level swizzling |
| 0x1A | SEARCH | CORE | L3 | [PLANNED] | Physical signature scanning |
| 0x1B | PERSIST | SOLIDIFICATION | L1 | [→ SPARK] | Store in memory indefinitely (renamed from FOSSILIZE) |
| 0x1C | POKE | DISSOLUTION | CRITICAL | [→ SPARK] | Write pattern to address (renamed from STRIKE) |
| 0x1D | RESET | CALCINATION | CRITICAL | [→ SPARK] | Reset subsystem to known state (renamed from QUENCH) |
| 0x1E | INJECT | FORGING | L2 | [→ SPARK] | Load firmware/config (renamed from FORGE) |
| 0x1F | WIPE | CALCINATION | CRITICAL | [→ SPARK] | Securely erase region (renamed from VOID) |
| 0x20 | ABDUCT | TRANSMUTATION | L2 | [PLANNED] | Physical page stealing |
| 0x21 | SNOOP | TRANSMUTATION | L2 | [PLANNED] | Cache-coherent monitoring |
| 0x22 | SCATTER | TRANSMUTATION | L2 | [PLANNED] | Vectored I/O (scatter-gather) |
| 0x23 | WHISPER | DISSOLUTION | L1 | [PLANNED] | Side-channel extraction |
| 0x24 | GHOST | DISSOLUTION | L1 | [PLANNED] | Configuration space masking |
| 0x25 | HIJACK | DISSOLUTION | CRITICAL | [PLANNED] | IRQ stealing |
| 0x26 | DRIFT | PULSE | L2 | [PLANNED] | Cross-device sync |
| 0x27 | CLONE | SOLIDIFICATION | L2 | [PLANNED] | Full silicon snapshot |
| 0x28 | CRYSTALLIZE | FORGING | L2 | [PLANNED] | JIT-to-FPGA |
| 0x29 | OVERCLOCK | CALCINATION | L1 | [PLANNED] | Sub-driver tuning |
| 0x2A | FLUX | TRANSMUTATION | L2 | [→ SPARK] | Cache invalidation |
| 0x2B | AUDIT | TESTING | L3 | [ZIG] | Post-instruction residue check |
| 0x2C | DRY_RUN | TESTING | L3 | [ZIG] | Simulate without executing |
| 0x2D | MOCK | TESTING | L3 | [ZIG] | Use mock hardware |
| 0x2E | PROVE | TESTING | L3 | [ZIG] | Formal verification |
| 0x2F | WATCH | MONITORING | L3 | [ZIG] | Real-time monitoring |
| 0x30 | TRACE | MONITORING | L3 | [ZIG] | Execution trace |
| 0x31 | GUARD | SAFETY | L1 | [→ SPARK] | Runtime safety sentinel |
| 0x32 | ISOLATE | SAFETY | L1 | [→ SPARK] | Complete hardware isolation |
| 0x33 | VERIFY | SAFETY | L2 | [→ SPARK] | Cryptographic state verification |
| 0x34 | AFFINITY | SUBSTRATE | CRITICAL | [→ SPARK] | Pin resource to target (renamed from OSSIFY) |
| 0x35 | TUNNEL | SUBSTRATE | CRITICAL | [→ SPARK] | Direct channel between endpoints (renamed from BOND) |
| 0x36 | SUSPEND | SUBSTRATE | CRITICAL | [→ SPARK] | Pause auto-behavior (renamed from STILL) |
| 0x37 | COORDINATE | SUBSTRATE | CRITICAL | [→ SPARK] | Coordinate devices (merged RESONATE+OSCILLATE) |
| 0x38 | ~~OSCILLATE~~ | — | — | — | **Merged into COORDINATE** |
| 0x39 | DIRECT | SUBSTRATE | CRITICAL | [→ SPARK] | Bypass OS, access controller (renamed from IMC_HIJACK) |
| 0x3A | BIND | SUBSTRATE | CRITICAL | [→ SPARK] | Bind to device with force (renamed from OCCUPY) |
| 0x3B | SLICE | CORE | L2 | [SPARK] | Split region into chunks (renamed from REFRACT) |
| 0x3C | PIPE | CORE | L1 | [→ SPARK] | Continuous DMA ring buffer |
| 0x4B | SIGNET | IDENTITY | L3 | [PLANNED] | Hardware PUF fingerprint |
| 0x4C | PRISM | VISION | L2 | [PLANNED] | Memory-as-texture visualization |
| 0x4D | PITCH | AUDIO | L2 | [PLANNED] | Acoustic bus monitoring |
| 0x4E | BOND_NET | NETWORK | L2 | [PLANNED] | Distributed substrate mesh link |
| 0x4F | DISSECT | FORENSIC | L3 | [PLANNED] | Binary gadget extractor |
| 0x50 | BEAM | NETWORK | L2 | [PLANNED] | Video cable data transmission |
| 0x51 | ICHOR | NETWORK | L2 | [PLANNED] | Point-to-point LAN (raw Ethernet) |
| 0x52 | SPECULATE | CORE | L2 | [PLANNED] | Speculative decoding bridge |

### Safety Levels

| Level | Meaning |
|-------|---------|
| **L1** | Hard contract — will hard abort on violation |
| **L2** | Soft contract — will inject safety operations |
| **L3** | Advisory — informational validation only |
| **CRITICAL** | Requires explicit Vial waiver — can cause physical damage |

### Language Policy

| Language | Purpose |
|----------|---------|
| **SPARK Ada** | All base hardware-manipulation tools. Formally verified. Zero runtime exceptions. |
| **Zig** | Utilities: AUDIT, DRY_RUN, MOCK, WATCH, TRACE, PROVE, ECHO. Not safety-critical. |
| **C** | Kernel module (VITRIOL). Thin wrappers only. |
| **ASM** | Performance-critical paths only, when SPARK cannot express the operation. |

---

## 8. Six Alchemical Arts

### I. TRANSMUTATION — Memory & Data Sovereignty

*The art of moving bits without the CPU "Bouncer" ever touching the payload.*

#### ABDUCT <phys_addr> <len> `[PLANNED]`
Physical Page Stealing. Forces the Linux Kernel to "forget" a piece of RAM exists.
```alka
ABDUCT 0xe0000000 256MB;
```

#### SNOOP <bus_addr> -> <vessel> `[PLANNED]`
Cache-Coherent Monitoring. Reads data on the PCIe bus without triggering Read-Completion.
```alka
SNOOP GPU_MAIN.BAR_0 -> traffic_log;
```

#### FLUX <vessel>
Non-Maskable Cache Invalidation. Manually invalidates L1/L2 without `wbinvd`.
```alka
FLUX GPU_MAIN;
```

#### SCATTER <map_vessel> -> <node> `[PLANNED]`
Vectored I/O. Blasts data into non-contiguous VRAM chunks in one transaction.
```alka
SCATTER layer_map -> GPU_MAIN.DATA_PLANE;
```

---

### II. DISSOLUTION — Security & Physical Exploitation

*The art of breaking the "Virtual Illusion" of the Operating System.*

#### POKE <target> [PATTERN] [REPS]
Targeted write to a physical address. The pattern and repetition count determine the access frequency. Used for rowhammer experiments, bit-flipping research, and direct VRAM manipulation.
```alka
POKE 0xfffffff 0xAAAAAAAA 10000;
```

#### WHISPER <node> [TIMING] `[PLANNED]`
Side-Channel Extraction via nanosecond BAR response timing.
```alka
WHISPER GPU_MAIN.CTRL_PLANE 100ns;
```

#### GHOST <pci_id> `[PLANNED]`
Configuration Space Masking. OS sees "Disconnected" while Alka maintains DMA.
```alka
GHOST 10de:1b82;
```

#### HIJACK <interrupt_vector> `[PLANNED]`
IRQ Stealing. Intercepts hardware signals before the kernel handler.
```alka
HIJACK 0x2f;
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

#### DRIFT <node_a> <node_b> `[PLANNED]`
Cross-Device Sync. Aligns crystal oscillator cycles.
```alka
DRIFT NVME_BOOT GPU_MAIN;
```

---

### IV. SOLIDIFICATION — Persistence & Firmware

*The art of staying in the machine forever.*

#### PERSIST <data> -> <node> [MODE]
Store data in memory indefinitely. Two modes based on target affordances:
- **PIN**: Pin a physical page so the OS never reclaims it. Survives soft reboots if the memory controller preserves state.
- **NV**: Write to non-volatile storage (device ROM, flash, EEPROM). Survives hard power cycles.

The compiler selects the mode based on the target's `NV_CAPABLE` affordance. If both are available, PIN is default; use `MODE NV` to force non-volatile.

```alka
// Pin a page in RAM (survives soft reboot)
PERSIST attack_vector -> GPU_MAIN.VRAM PIN;

// Write to device ROM (survives power cycle)
PERSIST init_sequence -> GPU_MAIN.ROM NV;
```

#### CLONE <controller_state> -> <vessel> `[PLANNED]`
Full Silicon Snapshot. Captures entire internal state for perfect REVERT.
```alka
CLONE GPU_MAIN -> gpu_full_backup;
```

---

### V. FORGING — FPGA & Isomorphic Gates

*The art of turning Thought into Silicon.*

#### INJECT <vessel> INTO <tile>
Partial device reconfiguration. Changes one tile/region while others continue.
```alka
INJECT IMP_CORE INTO KV260.TILE_0;
```

#### CRYSTALLIZE <alka_logic> -> <gate_logic> `[PLANNED]`
JIT-to-FPGA. Compiles logic into temporary hardware circuit.
```alka
CRYSTALLIZE inference_branch -> fpga_gate;
```

#### RECAST <vessel> <bitstream>
Device Reconfigure (simpler than INJECT).
```alka
RECAST KV260 CORE_METROD;
```

---

### VI. CALCINATION — Stress & Power Mastery

*The art of pushing silicon to its breaking point safely.*

#### RESET <node>
Thermal D3-Cold Cut. Physically cuts voltage via PCIe PM registers. Resets the subsystem to a known safe state.
```alka
RESET GPU_MAIN;
```

#### OVERCLOCK <node> <voltage> <freq> `[PLANNED]`
Sub-Driver Tuning. Pokes VRM directly to bypass safe limits.
```alka
OVERCLOCK GPU_MAIN 1.1V 2000MHz;
```

#### WIPE <node> [SECURE_LEVEL]
Secure Substrate Obliteration. Sanitize at block level.
```alka
WIPE NVME_BOOT SECURE;
```

---

## 9. Substrate Orchestration

*The art of coordinating the machine at the deepest level.*

These instructions operate below the OS scheduler, below the memory controller — at the level of physical silicon coordination.

#### AFFINITY <resource_id>
Pin a resource to a target. Bypasses the Linux scheduler entirely. The resource becomes a dedicated Alka execution unit.
```alka
AFFINITY 0;  // Pin core 0
```

#### TUNNEL <ram_addr> -> <gpu_addr> <size>
Create a direct channel between two endpoints. Bypasses the IOMMU for a specific memory region. Works for any two devices, not just RAM-to-GPU.
```alka
TUNNEL 0x100000000 -> GPU_MAIN.VRAM 512MB;
```

#### SUSPEND <subsystem> [MODE]
Pause auto-behavior of a subsystem. Takes over refresh cycles from the memory controller, or suspends a device's autonomous behavior.
```alka
SUSPEND BANK_0 AUTO;
```

#### COORDINATE <node_a> <node_b> <mode>
Coordinate devices. Three modes:
- **RESET**: Coordinate reset between devices. Ensures both enter a known state simultaneously for a pure execution window.
- **ALTERNATE**: Dual-bank coordination. Alternates access between two banks for continuous availability.
- **SYNC**: Synchronize state between two devices.

```alka
COORDINATE GPU_MAIN NVME_BOOT RESET;
COORDINATE BANK_0 BANK_1 ALTERNATE;
COORDINATE GPU_A GPU_B SYNC;
```

#### DIRECT <controller_channel>
Bypass the OS memory manager. Direct access to any controller — memory, I/O, DMA.
```alka
DIRECT CHANNEL_0;
```

#### BIND <pci_bdf> [FORCE]
Bind to a device. Severs all OS access — the device becomes exclusively Alka's. With `FORCE`, overrides existing bindings.
```alka
BIND 0000:01:00.0;
BIND 0000:01:00.0 FORCE;
```

#### CLAIM <vessel> [STEALTH]
Take ownership of a hardware node. Unbinds existing kernel drivers and stakes physical registers. With `STEALTH`, hides the device from OS probing after claiming (merged VEIL functionality).
```alka
CLAIM GPU_MAIN;
CLAIM GPU_MAIN STEALTH;
```

---

## 10. Dataflow & Pipes

*The art of continuous autonomous data movement.*

Until now, `FLOW` was a one-time bucket brigade: *Move 400MB from A to B, then stop.* For rendering, streaming, or continuous data movement, you need **Pipes.**

### PIPE Syntax

```alka
// Continuous DMA ring buffer — hardware runs autonomously
PIPE NVMe.BLOCK[0x0] => GPU.BAR1[0x0] 64MB 0x0

// Bidirectional pipe with zero-copy
PIPE GPU.OUTPUT => NIC.UDP_TX(PORT:8080) 16MB 0x3

// Multi-hop pipe
PIPE FPGA.AXI_OUT => SHM_BRIDGE => NIC.WEBRTC
```

**The Physics:** Sets up a Ring Buffer and configures the hardware's DMA engine to continuously loop over it. Once initiated, **Alka exits.** The CPU goes to sleep. The hardware just keeps moving data autonomously.

### PIPE Operands

| Operand | Description |
|---------|-------------|
| `src` | Source physical address or device ID |
| `dst` | Destination physical address or device ID |
| `ring_size` | Ring buffer size in bytes |
| `flags` | Bit 0: bidirectional, Bit 1: zero-copy, Bit 2: hardware-accelerated |

### Use Cases

| Pipe | Description |
|------|-------------|
| `SSD => GPU => Browser` | Stream model weights, display inference in real-time |
| `FPGA => SHM => WebRTC` | Raw sensor data to browser without a web server |
| `Mic ADC => FPGA => Speaker DAC` | Real-time audio processing pipeline |
| `GPU VRAM => NIC` | Continuous framebuffer streaming for remote rendering |

### Browser ↔ Hardware

```alka
REQUIRE athanor.alkavl;

STAKE 0x40000000 16MB AS SHM_BRIDGE;
PIPE KV260.AXI_OUT => SHM_BRIDGE;
PIPE SHM_BRIDGE => NIC_UDP_TX.PORT_8080;
```

The browser connects to `localhost:8080`. It isn't talking to a Node.js server. It is reading the raw binary output of the FPGA straight off the network card's physical buffer.

### SLICE — Region Chunking

For small VRAM devices (2GB/4GB GPUs), large regions must be chunked into BAR-sized drops.

```alka
// Auto-chunks 512MB region into 2x 256MB drops
SLICE 0x0 0x20000000 0x10000000;
```

| Operand | Description |
|---------|-------------|
| `src` | Source physical address (NVMe offset) |
| `total` | Total region size in bytes |
| `chunk` | Chunk size (defaults to 256MB if 0) |

**The Physics:** Loops: shifts BAR1 window, transfers chunk, advances offset. Signals metapage on completion. Critical for 2GB/4GB GPUs (GTX 960, GTX 1050 Ti). Enables streaming of models larger than VRAM by treating the GPU as a "PCIe L4 Cache."

---

## 11. Distributed Substrate Mesh

*The art of treating multiple machines as a single silicon body.*

Standard clustering is inefficient because 80% of time is spent on software overhead (TCP serialization, OS context switches, permission checks). Alka treats the wire between machines as a **Remote PCIe Lane.**

### TUNNEL — Distributed Substrate Link `[PLANNED: network variant]`

Creates a shared memory space across the network. Card A "sees" Card B as if they were on the same motherboard.

```alka
TUNNEL laptop.GPU_1090 -> athanor.VRAM_BRIDGE;
```

**The Physics:** Uses UDP Artillery to create a "Shared Memory" space across the network. Enables treating an entire office as **One Giant Computer.**

### BEAM — Video Cable Data Transmission `[PLANNED]`

Treats HDMI/DisplayPort as a high-bandwidth data bus. HDMI 2.1 (48 Gbps) and DisplayPort 2.0 (80 Gbps) dwarf standard 1GbE LAN.

```alka
// Transmit weights as high-frequency pixel noise via HDMI
BEAM laptop.GPU_1090.OUTPUT => KV260.INPUT 48GBPS;
```

**The Physics:** GPU "renders" LLM weights as high-frequency pixel noise and blasts them out of the HDMI port. KV260 FPGA decodes pixels back into Drop Binary Packets and injects them into the PCIe bus. Zero latency — a "Live Broadcast" of weights.

### ICHOR — Point-to-Point LAN `[PLANNED]`

Bypasses the TCP/IP stack entirely. Uses Raw Ethernet Frames (EtherType 0x414C - 'AL').

```alka
// Direct Ethernet link, no router
ICHOR local_nic.ETH0 => remote_nic.ETH0 10GBPS;
```

**The Physics:** Writes bits directly to the NIC's DMA ring. Bits fly across the wire and land directly in the target's RAM. Achieves RDMA throughput without expensive Mellanox cards.

### SPECULATE — Speculative Decoding Bridge `[PLANNED]`

Uses a small GPU as a draft model for a large GPU's verification.

```alka
// 960 generates 8 tokens, 1070 Ti verifies in parallel
SPECULATE GPU_960 -> GPU_1070TI COUNT 8;
```

**The Physics:** Sets up a bidirectional physical pipe. Draft GPU generates tokens at 100+ tok/s. Target GPU verifies the batch in one parallel pass. If disagreement, sends `REVERT` signal back to draft's KV-cache. Communication over P2P DMA takes ~2 microseconds vs 10ms over OS/CPU.

### SIGNET — Hardware PUF Fingerprint `[PLANNED]`

Generates a hardware-locked key from microscopic manufacturing defects.

```alka
SIGNET GPU_MAIN;
```

**The Physics:** Performs sub-nanosecond pokes and measures jitter. Generates a key that never leaves the silicon. Signs Alka Solutions with the GPU's own "fingerprint."

### PRISM — Memory-as-Texture Visualization `[PLANNED]`

Treats a physical memory range as a texture for optical forensics.

```alka
PRISM VRAM_RANGE[0x0..0x10000000] => FRAMEBUFFER;
```

**The Physics:** Pipes raw physical RAM directly to video out. "Watch the weights move" — LLM weights flowing through VRAM as shifting patterns of color and noise.

### PITCH — Acoustic Bus Monitoring `[PLANNED]`

Maps PCIe lane activity to audible frequency for tuning by ear.

```alka
PITCH PCIe_X16 => AUDIO_DAC;
```

**The Physics:** Maps TLP packet frequency to audible frequency. A healthy Moore Stream sounds like a steady, high-pitched hum. A bottleneck sounds like a "discordant note" or "stutter."

### DISSECT — Binary Gadget Extractor `[PLANNED]`

Scans existing binaries for Alka-compatible gadgets.

```alka
DISSECT nvidia.ko -> PHARMA_MANIFEST;
```

**The Physics:** Scans `.exe` or `.so` files and identifies "Alka-Compatible Gadgets." Automatically precipitates a Pharma Manifest from foreign code.

---

## 12. Tool Chaining

*The art of composing tools into logical chains where each tool's output satisfies the next tool's input.*

### The Problem

In v4, there was no formal relationship between tools. You could write `FLOW` before `CLAIM`, or `SIGNAL` before `FENCE`, and the compiler would accept it. The executor would fail at runtime, but by then it's too late — the hardware is already in an unknown state.

### The Solution: Pre/Post States

Every tool declares:
- **Pre-state**: What hardware state must exist before execution
- **Post-state**: What hardware state exists after execution
- **Side-effects**: What physical changes occur (thermal, memory, bus)

The compiler validates that each tool's pre-state is satisfied by the previous tool's post-state.

### Chain Graph

```
CLAIM ──→ LIMIT ──→ SLICE ──→ SYNC ──→ FENCE ──→ SIGNAL
  │         │         │         │         │          │
  ▼         ▼         ▼         ▼         ▼          ▼
owned    bounded   chunked   visible   waited    triggered
```

### Tool Chain Metadata

Each tool in the pharmacopia declares its chain properties:

```json
{
  "opcode": "0x03",
  "name": "FLOW",
  "chain": {
    "pre_state": ["vessel_claimed", "aperture_mapped"],
    "post_state": ["data_transferred"],
    "side_effects": ["thermal_increase", "memory_modified"],
    "suggests_after": ["SYNC", "FENCE"],
    "warns_if_before": ["CLAIM", "SHIFT"]
  }
}
```

### Compiler Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| **Pre-state unsatisfied** | ERROR | Tool's pre-state not met by any prior tool. Cannot compile. |
| **Warns-if-before violated** | WARNING | Tool appears before a tool it should follow. Compiles with warning. |
| **Side-effect unchecked** | WARNING | Tool produces side-effects (thermal, memory) with no subsequent check. |
| **Suggests-after missing** | INFO | Tool suggests a follow-up that is not present. Informational only. |

### Override Flag

The `--override` flag suppresses WARNING-level chain violations. The user explicitly acknowledges the risk:

```bash
alka build recipe.alka --override
# WARNING: FLOW appears before CLAIM
# WARNING: SIGNAL appears before FENCE
# Override acknowledged. Proceeding.
```

ERROR-level violations cannot be overridden — the compiler refuses to compile impossible sequences.

### Auto-Suggestions

When a chain violation is detected, the compiler suggests a fix:

```
ERROR: FLOW requires "vessel_claimed" pre-state, but no CLAIM precedes it.
SUGGESTION: Insert CLAIM before FLOW:
  CLAIM GPU_MAIN;
  FLOW NVME_BOOT[0x1000] -> GPU_MAIN[0] 256MB;
```

### Valid Chain Examples

**Standard inference pipeline:**
```
CLAIM → LIMIT → SLICE → SYNC → FENCE → SIGNAL
```

**Security research:**
```
CLAIM → POKE → AUDIT → WIPE
```

**Persistence:**
```
CLAIM → PERSIST → VERIFY → REVERT
```

**Distributed:**
```
CLAIM → TUNNEL → FLOW → FENCE → SIGNAL
```

### Implementation Status

**Current (v5.0)**: Minimal working implementation validates 6 core chains:
1. FLOW requires CLAIM before it
2. SIGNAL requires FENCE before it
3. SLICE requires CLAIM before it
4. FLOW requires SHIFT before it (when aperture mapping needed)
5. POKE requires CLAIM before it
6. TUNNEL requires CLAIM on both endpoints

**TODO** (marked with `// CHAIN_VALIDATION_TODO` in source):
- Full chain graph from pharmacopia.json metadata
- Side-effect tracking (thermal, memory)
- Auto-inject suggestions
- `--override` flag implementation
- Chain visualization in Gloss

---

## 13. Metrod Binary Format (.alkas)

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

Used for complex operations (POKE, INJECT, CRYSTALLIZE, etc.):

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

## 14. Azoth Rollback Format (.azoth)

The Azoth binary is the **antidote** to the AlkaSol. It is generated alongside every `.alkas` and contains the inverse operations needed to restore the machine to its pre-execution state.

### Generation Rules

| AlkaSol Instruction | Azoth Counterpart |
|---------------------|-------------------|
| CLAIM | REVERT (restore driver binding) |
| FLOW | WIPE (overwrite transferred data) |
| SHIFT | SHIFT (restore original offset) |
| STAKE | ABDUCT (release physical pages) |
| OSSIFY/AFFINITY | YIELD (return core to scheduler) |
| TUNNEL | FLUX (invalidate tunnel mappings) |
| BIND/OCCUPY | CLAIM (restore OS device access) |
| POKE/STRIKE | WIPE (sanitize flipped bits) |
| RESET/QUENCH | RECAST (restore power state) |
| PIPE | WIPE (tear down ring buffer) |
| SLICE/REFRACT | FLUX (invalidate partial transfers) |
| SPECULATE | REVERT (restore draft KV-cache) |
| PERSIST | REVERT (unpin page or erase NV) |
| INJECT/FORGE | REVERT (restore original firmware) |

### Azoth Packet Structure

Identical to Drop packets, but with the `FLAGS` bit 7 set to indicate rollback mode:

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

## 15. Compiler Pipeline

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
│                          │  Affordance interrogation
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 3: Chain Check    │  Validate tool sequence against
│  (NEW in v5.0)           │  chain graph. Warn on risky chains.
│                          │  ERROR on impossible sequences.
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 4: Precipitate    │  Components generate optimal binary
│  (Affordance-Based)      │  based on Vial capabilities
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 5: Emit           │  Generate Drop packets
│  (Drop Packets)          │  32-byte or 64-byte packets
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 6: Refine         │  Welder pass:
│  (The Welder)            │  - CRC verification
│                          │  - Dead-code stripping (DRY_RUN, MOCK)
│                          │  - Peephole optimization (redundant SYNC)
│                          │  - Pipe loop expansion
└──────────┬──────────────┘
           v
┌─────────────────────────┐
│  Stage 7: Dual Output    │  Emit .alkas + .azoth
│                          │  Generate .alkagraph (node graph)
└─────────────────────────┘
```

### Implicit Safety Injections

The compiler automatically injects operations:

1. **Automatic Windowing**: If `FLOW` target exceeds aperture, injects `SHIFT` loop
2. **Thermal Shadowing**: Heat-generating instructions wrapped with `SENSE` + `GUARD`
3. **Linear Resource Tracking**: Physical addresses are linear types — cannot be claimed twice
4. **Barrier Injection**: `SYNC L3` auto-injected before `SIGNAL` after `FLOW`
5. **Pipe Loop Expansion**: `PIPE` instructions expanded into ring buffer setup sequences
6. **Speculative Bridge**: `SPECULATE` auto-injects `REVERT` path for draft disagreement
7. **Chain Validation**: Invalid tool sequences produce errors or warnings with suggestions

### Affordance Interrogation

Components interrogate the Vial at compile-time:

```zig
// SHIFT.zig — Universal Aperture Mover
pub fn precipitate(vial: Vial, vessel: Vessel) []const u8 {
    if (vessel.has_affordance(.RESIZABLE_BAR)) {
        return emit_modern_resbar(vessel);
    }
    if (vessel.has_affordance(.BAR_SLIDING_WINDOW)) {
        return emit_legacy_window_slide(vessel);
    }
    if (vessel.has_affordance(.SOFTWARE_MAPPED)) {
        return emit_software_emulation(vessel);
    }
    @compileError("Vessel cannot shift aperture");
}
```

The component doesn't know *which* GPU it's targeting. It only knows **what the GPU can do**. The compiler generates the optimal binary for that specific substrate.

---

## 16. The Pharmacopeia (Tool System)

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
    aperture_max: u64,
    thermal_limit: u64,
    current_temp: u64,
    affordances: []const Affordance,
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
├── dispatch_table.zig   # Auto-generated from pharmacopia.json
├── core/                # Core tools
│   ├── claim.zig        # CLAIM (0x01) [SPARK]
│   ├── stake.zig        # STAKE (0x02) [→ SPARK]
│   ├── spark_flow.zig   # FLOW (0x03) [SPARK]
│   ├── spark_shift.zig  # SHIFT (0x04) [SPARK]
│   ├── spark_fence.zig  # FENCE (0x05) [SPARK]
│   ├── sync.zig         # SYNC (0x06) [→ SPARK]
│   ├── spark_signal.zig # SIGNAL (0x09) [SPARK]
│   ├── yield.zig        # YIELD (0x0A) [→ SPARK]
│   ├── limit.zig        # LIMIT (0x0E) [→ SPARK]
│   ├── spark_slice.zig  # SLICE (0x3B) [SPARK] (was spark_refract.zig)
│   ├── pipe.zig         # PIPE (0x3C) [→ SPARK]
│   ├── snap.zig         # SNAP (0x0C) [→ SPARK] (merged with MOLT)
│   ├── revert.zig       # REVERT (0x0D) [→ SPARK]
│   ├── echo.zig         # ECHO (0x17) [ZIG]
│   ├── veil.zig         # REMOVED (merged into CLAIM)
│   └── poke.zig         # POKE (0x1C) [→ SPARK] (was strike.zig)
├── substrate/           # Substrate orchestration tools
│   ├── affinity.zig     # AFFINITY (0x34) [→ SPARK] (was ossify.zig)
│   ├── tunnel.zig       # TUNNEL (0x35) [→ SPARK] (was bond.zig)
│   ├── suspend.zig      # SUSPEND (0x36) [→ SPARK] (was still.zig)
│   ├── coordinate.zig   # COORDINATE (0x37) [→ SPARK] (new, merged)
│   ├── direct.zig       # DIRECT (0x39) [→ SPARK] (was imc_hijack.zig)
│   └── bind.zig         # BIND (0x3A) [→ SPARK] (was occupy.zig)
├── forging/             # Forging tools
│   ├── inject.zig       # INJECT (0x1E) [→ SPARK] (was forge.zig)
│   ├── wipe.zig         # WIPE (0x1F) [→ SPARK] (was void.zig)
│   └── recast.zig       # RECAST (0x0B) [→ SPARK]
├── pulse/               # Timing tools
│   ├── sense.zig        # SENSE (0x07) [ZIG]
│   ├── pulse.zig        # PULSE (0x08) [→ SPARK]
│   ├── stasis.zig       # STASIS (0x18) [→ SPARK]
│   └── rhythm.zig       # RHYTHM (0x11) [→ SPARK]
├── transmutation/       # Memory tools
│   ├── flux.zig         # FLUX (0x2A) [→ SPARK]
├── solidification/      # Persistence tools
│   ├── persist.zig      # PERSIST (0x1B) [→ SPARK] (was fossilize.zig)
├── calcination/         # Power tools
│   ├── quench.zig       # RESET (0x1D) [→ SPARK] (was quench.zig)
├── safety/              # Safety tools
│   ├── guard.zig        # GUARD (0x31) [→ SPARK]
│   ├── isolate.zig      # ISOLATE (0x32) [→ SPARK]
│   └── verify.zig       # VERIFY (0x33) [→ SPARK]
├── testing/             # Test utilities (Zig only)
│   ├── audit.zig        # AUDIT (0x2B) [ZIG]
│   ├── dry_run.zig      # DRY_RUN (0x2C) [ZIG]
│   ├── mock.zig         # MOCK (0x2D) [ZIG]
│   └── prove.zig        # PROVE (0x2E) [ZIG]
└── monitoring/          # Monitoring tools (Zig only)
    ├── watch.zig        # WATCH (0x2F) [ZIG]
    └── trace.zig        # TRACE (0x30) [ZIG]
```

### The Manifest (pharmacopia.json)

The `pharmacopia.json` file tracks every tool's metadata:

```json
{
  "opcode": "0x01",
  "name": "CLAIM",
  "tool": "core/claim.zig",
  "safety": "L3",
  "description": "Take ownership of a hardware node",
  "latency_ns": 40,
  "risk_tier": 2,
  "affordances_required": [],
  "chain": {
    "pre_state": [],
    "post_state": ["vessel_claimed"],
    "side_effects": ["driver_unbound"],
    "suggests_after": ["LIMIT", "STAKE"],
    "warns_if_before": []
  }
}
```

### Noun-First Component Model

Components are **Transformers of Nouns**, not static programs:

- `FLOW` is a **Bus Negotiator** — adapts based on source/destination affordances
- `SHIFT` is an **Aperture Mover** — adapts based on windowing capabilities
- `PIPE` is a **Ring Buffer Establisher** — adapts based on DMA engine support

The same `FLOW` instruction:
- Between SSD → GPU: precipitates P2P DMA
- Between FPGA → Speaker: precipitates real-time DAC stream
- Between RAM → NIC: precipitates raw Ethernet frames

---

## 17. The Welder (Binary Stitcher)

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

### Pass 4: Pipe Loop Expansion
- Expands `PIPE` instructions into ring buffer setup sequences
- Inserts completion signaling and watchdog timers

### Future Passes (Planned)
- Address patching from Vial into tool blobs
- Polyglot blob concatenation (SPARK/Zig/C/ASM tools)
- Variable-length packet support

---

## 18. Implicit Safety

### Automatic Windowing

When a `FLOW` or `SLICE` exceeds the aperture's `MAX_WINDOW`:

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
POKE 0xfffffff 0xAAAAAAAA 10000;

// Compiler generates:
SENSE GPU_MAIN.THERMAL;
GUARD GPU_MAIN.THERMAL > 85C RESET;
POKE 0xfffffff 0xAAAAAAAA 10000;
AUDIT GPU_MAIN;
```

### Linear Resource Tracking

Physical addresses are linear types:
- A resource can only be `CLAIM`ed once
- Must be released before re-claiming
- Compile error on double-stake

---

## 19. Safety Guarantees

1. **Compile-Time Verification**: All physical constraints checked before binary emission
2. **No Double-Staking**: Linear types prevent resource conflicts
3. **Thermal Throttling**: Automatic yield injection near thermal limits
4. **Aperture Enforcement**: Sliding window generation for oversized transfers
5. **CRC Integrity**: Every packet validated before execution
6. **Azoth Rollback**: Every forward operation has a defined inverse
7. **Guard Sentinels**: Runtime conditions can trigger automatic rollback
8. **Affordance Validation**: Components verify hardware capabilities before emitting logic
9. **Deterministic Self-Explanation**: The Gloss provides human-readable projections of compile-time certainty
10. **Chain Validation**: Tool sequences validated against pre/post state graph
11. **SPARK Verification**: All base hardware tools formally proved correct

---

## 20. Testing & Validation

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

### Tool Harness

All 43 tools are tested against edge cases:
- Empty inputs (zero operands)
- Boundary values (max u64, zero, page-aligned)
- Zero aperture context
- Thermal extreme context (150°C, halt=0)
- SPARK-specific validation rules

Run with: `zig build test-harness`

---

## 21. The Alchemical Mirror (REPL)

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
- **Semantic Risk-Highlighting**: `CLAIM` turns **Gold**, `FLOW` turns **Cyan**, `POKE` flashes **Magenta** border
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

## 22. Remote Execution (Net-Poll)

### Architecture

1. **Laptop**: Runs `alka --repl` (The Mind)
2. **Target PC**: Runs Athanor Listener (The Body)
3. **Link**: UDP-based packet injection — the shim intercepts at the **interrupt handler level**, before the kernel's network stack processes packets

### Drop Network Packet (48 bytes)

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
   - Sends `RESET` to power rail, OR
   - Resets PCIe bus, OR
   - Executes the `.azoth` rollback binary
3. Hardware healed before thermal damage or data loss

This is the ultimate safety net for intrusive operations — the machine heals itself when the operator can't.

---

## 23. The Pharmacist's Gloss

*The art of self-explaining code through deterministic projection.*

Because Alka is non-Turing-complete and anchored to an immutable Vial, the "Gloss" (inlay hints) isn't just a helpful comment — it is a **Human-Language Projection of a Mathematical Certainty.**

### Architecture

The Gloss is implemented as a **Zig LSP server** (`alka-lsp`) that communicates over the Language Server Protocol via stdio. A thin VSCodium extension wraps the LSP for editor integration.

```
┌──────────────────────────────────────────────┐
│  VSCodium Extension                          │
│  ├── Syntax highlighting (Tree-sitter)       │
│  ├── LSP client (stdio → alka-lsp)          │
│  └── Keybindings / commands                  │
├──────────────────────────────────────────────┤
│  alka-lsp (Zig)                              │
│  ├── server.zig       — LSP protocol handler │
│  ├── vial_context.zig — Parse + cache .alkavl│
│  ├── chain_linter.zig — Real-time validation │
│  ├── completions.zig  — Autocomplete engine  │
│  ├── hover.zig        — Tooltips             │
│  └── diagnostics.zig  — Error/warning squiggles
├──────────────────────────────────────────────┤
│  Compiler (alkac.zig)                        │
│  ├── Parser + chain_validator                │
│  └── pharmacopia.json metadata               │
└──────────────────────────────────────────────┘
```

### The Visual Gloss (What the Architect sees)

Instead of just seeing a wall of colors, your `.alka` file now looks like an annotated ritual. The text in italics is "Ghost Text" generated by the LSP in real-time:

```alka
CLAIM GTX_960
// ^^^^^^ Hover: GTX_960: NVIDIA GPU (10de:13c2), 2GB GDDR5, halt@98C
SHIFT .BAR1 0 256MB
//    ^^^^^ Hover: GTX_960.BAR1: 256MB window, base 0xF0000000
SLICE .VRAM 0 512MB 256MB
//    ^^^^^ Hover: GTX_960.VRAM: 2GB GDDR5 through BAR1 aperture
```

### Real-Time Chain Validation

The LSP runs `chain_validator.zig` on every keystroke (debounced):

| Squiggle | Meaning | Example |
|----------|---------|---------|
| 🔴 Red | Pre-state unsatisfied (error) | `SLICE` without prior `SHIFT` |
| 🟡 Yellow | Risky sequence (warning) | `LIMIT` after `CLAIM` without guard |
| 🟢 Green | All constraints satisfied | Valid chain |
| 🔵 Blue glow | Tool is SPARK-verified | `FLOW`, `SHIFT`, `FENCE`, `SIGNAL`, `SLICE` |
| 🟣 Purple glow | `!!` override active | Chain validation suppressed |

### Completions

| Context | Suggestions |
|---------|-------------|
| After `CLAIM` | Tools requiring `vessel_claimed`: `SHIFT`, `LIMIT`, `STAKE`, etc. |
| After `SHIFT` | Tools requiring `aperture_mapped`: `FLOW`, `SLICE` |
| Typing `.` after vessel | Aperture names from vial (`.BAR1`, `.VRAM`) |
| After tool name | Parameter names from pharmacopia metadata |
| After `!!` | All tool names |

### Hover Details

Hovering over any identifier resolves it against the current vial context and pharmacopia metadata:

```
SHIFT .BAR1 0 256MB
      ^^^^^
      ┌─────────────────────────────────────────────┐
      │ GTX_960.BAR1                                │
      │ Type: Aperture                              │
      │ BAR: 1                                      │
      │ Max Window: 256MB                           │
      │ Base: 0xF0000000 (from PCI config)          │
      │ Purpose: VRAM access window                 │
      │ Defined in: gtx960_2gb.alkavl:12            │
      └─────────────────────────────────────────────┘
```

### The `!!` Override

The `!!` directive suppresses chain validation for the next instruction:

```alka
CLAIM GTX_960
!!  // Bypass: hardware is pre-configured, SHIFT not needed
SLICE .VRAM 0 512MB 256MB
```

The LSP shows a purple squiggle on the `!!` line and a tooltip: "Chain validation bypassed for next instruction."

### Vial Contextualization

Because the LSP is linked to the **`.alkavl` (Vial)**, descriptions are **Hardware-Specific.**
- On an **i7-3770 (Ivy Bridge)**, the Gloss for `FLOW` might indicate DMA width limits
- On a **Modern Xeon**, it might indicate Intel DSA engine availability

### The Timeline Preview

Since the language is deterministic, the LSP can include a **"Solution Preview"** pane. As you write your **Recipe (.alka)**, the pane renders a real-time **Timeline of the Metal**:

```text
[ TIMELINE PREVIEW ]
000ms: [CLAIM]   Drivers Neutralized. GPU Owned.
005ms: [SHIFT]   Aperture aligned to 0x0.
012ms: [FLOW]    ===> DMA START (8.2 GB/s)
094ms: [FENCE]   CPU Parked. Waiting for hardware...
095ms: [FLOW]    COMPLETE. 256MB moved.
```

---

## 24. SPARK-First Policy

*All base hardware-manipulation tools are formally verified in SPARK Ada.*

### The Principle

Hardware operations are irreversible. A wrong DMA transfer corrupts data. A wrong BAR remap crashes the system. A wrong voltage poke fries silicon. These operations cannot be "fixed" with a patch — the damage is physical.

Therefore, **every tool that directly manipulates hardware must be formally verified.** SPARK Ada provides mathematical proofs that the tool is correct for *all* valid inputs, not just the ones we tested.

### SPARK-Verified Tools (Current)

| Tool | Opcode | What it does | Proof status |
|------|--------|-------------|--------------|
| FLOW | 0x03 | DMA transfer | ✅ Proved (gnatprove + Z3) |
| SHIFT | 0x04 | BAR window remap | ✅ Proved (gnatprove + Z3) |
| FENCE | 0x05 | Condition wait | ✅ Proved (gnatprove + Z3) |
| SIGNAL | 0x09 | Event trigger | ✅ Proved (gnatprove + Z3) |
| SLICE | 0x3B | Region chunking | ✅ Proved (gnatprove + Z3) |

### SPARK-Verified Tools (Planned)

These tools manipulate hardware directly and **must** become SPARK-verified before production use:

| Tool | Opcode | Priority | Reason |
|------|--------|----------|--------|
| CLAIM | 0x01 | HIGH | Driver unbind is irreversible without rollback |
| STAKE | 0x02 | HIGH | Memory reservation affects kernel |
| SYNC | 0x06 | MEDIUM | Memory barrier correctness is critical |
| PULSE | 0x08 | MEDIUM | Timing signals affect all devices |
| YIELD | 0x0A | LOW | Cooperative, low risk |
| LIMIT | 0x0E | HIGH | Thermal limits are safety-critical |
| SNAP | 0x0C | MEDIUM | State serialization must be complete |
| REVERT | 0x0D | HIGH | Rollback correctness is safety-critical |
| POKE | 0x1C | CRITICAL | Bit manipulation can cause physical damage |
| RESET | 0x1D | HIGH | Power state changes are dangerous |
| INJECT | 0x1E | HIGH | Firmware injection is irreversible |
| WIPE | 0x1F | CRITICAL | Secure erase must be complete |
| FLUX | 0x2A | MEDIUM | Cache invalidation affects all cores |
| GUARD | 0x31 | HIGH | Safety sentinel must never fail |
| ISOLATE | 0x32 | HIGH | Complete isolation must be total |
| VERIFY | 0x33 | MEDIUM | Cryptographic verification must be correct |
| AFFINITY | 0x34 | HIGH | CPU pinning affects scheduler |
| TUNNEL | 0x35 | HIGH | IOMMU bypass is dangerous |
| SUSPEND | 0x36 | HIGH | DRAM refresh suspension can cause data loss |
| COORDINATE | 0x37 | HIGH | Device coordination must be atomic |
| DIRECT | 0x39 | CRITICAL | Controller bypass is extremely dangerous |
| BIND | 0x3A | CRITICAL | Device seizure is irreversible |
| PIPE | 0x3C | HIGH | Autonomous DMA must be bounded |
| PERSIST | 0x1B | HIGH | Persistent storage must be reliable |
| RHYTHM | 0x11 | MEDIUM | Timing constraints affect all devices |
| STASIS | 0x18 | HIGH | Bus locking affects all PCIe traffic |

### Zig-Only Tools (Intentionally Not SPARK)

These tools are utilities that do not directly manipulate hardware. They are safe to implement in Zig:

| Tool | Purpose |
|------|---------|
| AUDIT | Post-operation residue check |
| DRY_RUN | Simulation without side effects |
| MOCK | Virtual hardware representation |
| PROVE | Formal verification engine |
| WATCH | Real-time monitoring |
| TRACE | Execution trace logging |
| ECHO | Non-intrusive introspection |

### The SPARK Build Pipeline

```
src/spark/
├── vitriol_tools.gpr       # GNAT project file
├── vitriol_types.ads/adb   # Shared types (Drop, VialConstraints)
├── tool_flow.ads/adb       # FLOW tool
├── tool_shift.ads/adb      # SHIFT tool
├── tool_fence.ads/adb      # FENCE tool
├── tool_signal.ads/adb     # SIGNAL tool
├── tool_slice.ads/adb      # SLICE tool (was tool_refract)
├── vitriol_tool_wrapper.c  # C ABI bridge
└── obj/                    # Compiled .o files
    ├── vitriol_types.o
    ├── tool_flow.o
    ├── tool_shift.o
    ├── tool_fence.o
    ├── tool_signal.o
    ├── tool_slice.o
    └── vitriol_tool_wrapper.o
```

Build: `gprbuild -P src/spark/vitriol_tools.gpr`
Prove: `gnatprove -P src/spark/vitriol_tools.gpr --level=4`

### Verification Levels

| Level | Meaning |
|-------|---------|
| 1 | No overflow at runtime |
| 2 | No runtime exceptions |
| 3 | All pre-conditions checked |
| 4 | All post-conditions proved |

All Alka SPARK tools target **Level 4**.

---

## 25. Implementation Roadmap

*Integrated from ROADMAP.md. Status tracked inline.*

### Current Status

```
Phase 0 (Rename Metrod → Drop) ──────────┐
                                           ├──→ Phase 1 (SPARK tool completion) ✅ DONE
                                           │         │
                                           │         └──→ Phase 7 (Proof automation)
                                           │
                                           ├──→ Phase 2 (Polyglot Pharmacopia) ✅ DONE
                                           │         │
                                           │         ├──→ Phase 3 (Embed/.alkar)
                                           │         │         │
                                           │         │         └──→ Phase 5 (Declarative syntax)
                                           │         │
                                           │         └──→ Phase 4 (CLI overhaul)
                                           │
                                           ├──→ Phase 6 (Atomic binary output)
                                           │
                                           ├──→ Phase 8 (Tool renames, v5.0) ✅ DONE
                                           │
                                           └──→ Phase 9 (v5.1 Language Design) 🔄 IN PROGRESS
                                                     │
                                                     ├──→ 9a (Parser rewrite)
                                                     ├──→ 9b (Context tracking)
                                                     ├──→ 9c (Pharmacopia params)
                                                     ├──→ 9d (Tree-sitter)
                                                     ├──→ 9e (LSP server)
                                                     └──→ 9f (VSCodium extension)
```

### Phase 0: Rename — Metrod → Drop ✅ DONE

The term "Metrod" referred to a separate project. Alka's 32-byte packet is now called **Drop**.
~309 occurrences renamed across 18 source files. No ABI change.

### Phase 1: SPARK Tool Completion ✅ DONE

5 SPARK tools formally verified: FLOW, SHIFT, FENCE, SIGNAL, SLICE (was REFRACT).
30 checks proved, 0 errors. C ABI bridge working with packed struct fix.

### Phase 2: Polyglot Pharmacopia ✅ DONE

Manifest-driven tool registry. `pharmacopia.json` declares all 43 tools.
`zig build dispatch` generates `dispatch_table.zig`.
43 tools registered (38 Zig, 5 SPARK Ada).

### Phase 3: Embed Architecture (.alkar) `[PLANNED]`

Embed encrypted Drops inside host binaries (`.exe`, `.png`, ELF).
Two-binary architecture: host carries payload, `.alkar` carries keys.
New instruction: `UNPACK`.

### Phase 4: CLI Overhaul `[PLANNED]`

New command tree: `alka prove`, `alka build`, `alka run`, `alka embed`, `alka scan`.
Automatic privilege escalation via polkit. No `sudo` wrapper needed.

### Phase 5: Declarative Recipe Syntax `[PLANNED]`

```alka
STREAM "mistral-7b.gguf" LAYER 3;
```

Compiler derives addresses from GGUF header + Vial. Imperative syntax still works.

### Phase 6: Proof Automation `[PLANNED]`

Build-time: SPARK proofs + Z3 proofs cached, re-run on source change.
Recipe-time: Z3 proof on every `alka run` (~100ms).
`alka run` pipeline: prove → build → escalate → execute → rollback on failure.

### Phase 7: Install Target `[PLANNED]`

`make install` → `/usr/local/bin/alka`, system vials in `/etc/alka/vials/`, polkit rules.
Common GPUs get pre-built `.alkavl` files.

### Phase 8: Tool Renames & Merges (v5.0) ✅ DONE

All tool names generalized. Redundant tools merged. Chain validation added.
SPARK-first policy documented.

### Phase 9: v5.1 Language Design & LSP Gloss ✅ IN PROGRESS

Major syntax and tooling overhaul:

#### 9a. Parser Rewrite — No Semicolons, Dot-References, `!!` Override `[IN PROGRESS]`
- Remove `;` as statement terminator — newlines terminate instructions
- Add dot-reference `.Member` syntax for context-based vessel addressing
- Add `!!` override directive for per-instruction chain bypass
- Add `!` suffix on `CLAIM` for force re-claim (`CLAIM!`)
- Add flexible unit capitalization (all case-insensitive variants: `KB`, `KiB`, `MB`, `MiB`, etc.)
- Error on stray `;` characters

#### 9b. Compiler Context Tracking `[PLANNED]`
- Track active vessel context across instructions
- Resolve `.Member` references against vial at compile time
- `CLAIM!` clears stale aperture state

#### 9c. Pharmacopia Parameter Metadata `[PLANNED]`
- Add `params` array to each tool (name, type, description)
- Enables LSP autocomplete and hover enrichment
- Auto-generate parameter validation in compiler

#### 9d. Tree-Sitter Grammar `[PLANNED]`
- Syntax highlighting for VSCodium
- Keywords, directives, vessel refs, operators, units

#### 9e. Zig LSP Server (`alka-lsp`) `[PLANNED]`
- `server.zig` — LSP protocol over stdio
- `vial_context.zig` — cache parsed `.alkavl` files per workspace
- `chain_linter.zig` — real-time chain validation (reuses `chain_validator.zig`)
- `completions.zig` — autocomplete for tools, parameters, vessel refs
- `hover.zig` — pharmacopia descriptions + vial data tooltips
- `diagnostics.zig` — red/yellow/green squiggles for chain state

#### 9f. VSCodium Extension `[PLANNED]`
- Thin wrapper around LSP server
- OpenVSX distribution (not Microsoft Marketplace)
- Commands: compile, suggest, preview timeline

### Implementation Order

```
Now → Phase 9a (Parser rewrite: no `;`, dot-refs, `!!`, units)
           │
           ▼
Next  → Phase 9b (Compiler context tracking)
           │
           ▼
Week 2 → Phase 9c (Pharmacopia params) + Phase 9d (Tree-sitter)
           │
           ▼
Week 3 → Phase 9e (LSP server) + Phase 9f (VSCodium extension)
           │
           ▼
Ongoing → SPARK verification of remaining hardware tools (§24)
```

---

## 26. Cybersecurity & Red-Teaming Operations

*Alka is designed for security research. This section documents the operations that are relevant to red-teaming and penetration testing.*

### Hardware-Level Persistence

`PERSIST` can store data in physical memory or non-volatile storage:

```alka
// Pin a page in RAM — survives soft reboot
PERSIST payload -> GPU_MAIN.VRAM PIN;

// Write to device ROM — survives power cycle
PERSIST payload -> NIC.ROM NV;
```

### Device Seizure

`BIND` and `CLAIM` take exclusive control of hardware:

```alka
// Seize GPU, sever OS access
BIND 0000:01:00.0 FORCE;

// Claim and hide from OS
CLAIM GPU_MAIN STEALTH;
```

### Bit Manipulation Research

`POKE` enables targeted bit manipulation for rowhammer and fault injection research:

```alka
POKE target_addr 0xAAAAAAAA 10000;
```

### Embedding in Host Binaries

Phase 3 (`.alkar`) enables embedding verified hardware operations inside seemingly benign binaries. The host binary's imports show nothing suspicious — the actual hardware operations are encrypted Drops hidden in padding sections.

### Forensic Audit

`AUDIT`, `PROBE_BUS`, and `DISSECT` enable post-operation analysis:

```alka
AUDIT GPU_MAIN;           // Check residue after operation
PROBE_BUS;                // Forensic bus scan
DISSECT nvidia.ko;        // Extract Alka-compatible gadgets
```

### Safety Warning

These operations can cause:
- **Data corruption**: POKE, WIPE, ABDUCT
- **System instability**: BIND, CLAIM, DIRECT
- **Physical damage**: POKE (rowhammer), RESET (power cycling)
- **Persistence**: PERSIST (survives reboots)

Always use `DRY_RUN` before executing on real hardware. Always have an `.azoth` rollback binary ready.

---

## 27. Research Context

### Alka is a Research Language

Alka exists to answer one question: **Can we make hardware manipulation safe through formal verification and contract-first design?**

The answer so far is yes — for the 5 SPARK-verified tools, we have mathematical proofs of correctness. The remaining 38 tools need the same treatment before Alka can be considered production-ready for high-risk operations.

### The Alchemical Mirror

The metaphor is intentional. Alchemy was the proto-science that became chemistry. Alka is the proto-language that will become the standard for hardware orchestration. The names are not decoration — they are a reminder that we are working at the boundary between the physical and the digital.

### Acknowledgments

- SPARK Ada for formal verification
- Zig for the compiler
- Z3 for SMT solving
- GNATprove for SPARK proof automation
- The Linux kernel for the hardware we manipulate

---

*End of SPECv5. Written 2026-05-13. Single source of truth for Alka v5.1.*
*All previous specs (v1–v4) are superseded by this document.*

---

## 28. Practitioner's Companion

The SPEC defines the language. The **Practitioner's Handbook** (`docs/HANDBOOK.md`) defines the craft — how to apply Alka to real hardware, common patterns, device-specific guidance, and troubleshooting.

**Key sections in the Handbook:**

| Topic | Handbook § | Description |
|-------|------------|-------------|
| Domain Boundary | §1 | What Alka does vs. what the programmer provides |
| GPU | §2 | BAR0/BAR1, firmware channels, VRAM sliding window |
| CPU (x86) | §2 | APIC, MSI, chipset MMIO |
| Fans | §2 | Super I/O behind LPC bridge |
| Audio (USB) | §2 | xHCI transfer descriptors |
| NVMe | §2 | Doorbell registers, submission queues |
| NIC | §2 | Descriptor ring DMA |
| FPGA | §2 | PCIe configuration + INJECT |
| Bridge Traversal | §3 | I2C/SPI/LPC behind PCI bridges |
| Safety Patterns | §4 | Thermal interlock, SNAP-REVERT, !! override |
| Pitfalls | §5 | Alignment, reordering, dead devices, BIND failures |

The Handbook is a living document — expect additions as new hardware targets are explored.
