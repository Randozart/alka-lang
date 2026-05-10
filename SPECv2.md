# Alka Language Specification v2.0

> The "Universal Solvent" for physical machine state orchestration
> 
> **Version**: 2.0 (Deduplicated)
> **Timestamp**: 2026-05-10T00:00:00Z
> **Based on**: SPEC.md

---

## Overview

Alka is a non-Turing-complete, contract-driven hardware instruction set designed for safe, verifiable manipulation of bare metal resources. It operates on the principle that hardware constraints should be encoded as compile-time contracts, not runtime checks.

### Design Philosophy

- **Contract-First**: The Substrate (`.alkavl`) is the source of truth
- **Zero Overhead**: Compiles to fixed-size binary packets (Metrod format)
- **State-Assertive**: Declarative, not imperative
- **Implicit Safety**: Compiler automatically injects required operations

---

## File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level intent, instruction sequences |
| `.alkavl` | The Vial | Physical hardware topology and constraints |
| `.alkas` | The AlkaSol | Compiled binary solution |
| `.azoth` | The Azoth | Rollback/recovery binary |

---

## Terminology (Strict Definitions)

| Term | Definition |
|------|------------|
| **Rack** | Directory containing multiple Vials (hardware configurations) |
| **Vial** (`.alkavl`) | Static description of physical hardware constraints |
| **Recipe** (`.alka`) | High-level instruction script |
| **Components** | Modular instruction implementations in `tools/` folder |
| **AlkaSol** (`.alkas`) | Compiled binary - the active experiment |
| **Azoth** (`.azoth`) | Compiled binary - rollback/recovery |

---

## Language Grammar

Alka is designed to be both minimal and extensible. Simple programs are just instruction lists; complex programs can use variables, control flow, and functions.

### Minimal Syntax (Instruction List)

The simplest Alka program is just instructions, one per line:

```alka
CLAIM GPU_MAIN;
FLOW NVME[0x1000] -> GPU[0] 256MB;
FENCE GPU.METAPAGE == 1;
SYNC L3;
```

### Full Grammar

#### Program Structure
```
program         ::= { statement }

statement       ::= directive
                  | instruction
                  | block
                  | if_statement
                  | for_statement
                  | function_def

directive       ::= "REQUIRE" string_literal
                  | "IMPORT" identifier

instruction     ::= IDENTIFIER [ operands ] [ ";" ]

operands        ::= operand { "," operand }
operand         ::= expression
                  | address
                  | "AS" identifier

address         ::= IDENTIFIER [ "[" expression "]" ]
```

#### Expressions
```
expression      ::= primary { binary_op primary }

primary         ::= number
                  | identifier
                  | memory_size
                  | "(" expression ")"

memory_size     ::= NUMBER UNIT
                  | IDENTIFIER

binary_op       ::= "+" | "-" | "*" | "/" | "==" | "!=" | ">" | "<" | ">=" | "<="
                  | "->"   // arrow for FLOW destination
```

#### Control Flow
```
if_statement    ::= "IF" expression "THEN" block
                    { "ELSEIF" expression "THEN" block }
                    [ "ELSE" block ]
                  | "ON" expression "{" statement "}"   // event handler

for_statement   ::= "FOR" IDENTIFIER "IN" range "{" block "}"

range           ::= expression ".." expression
                  | expression      // single value

block           ::= "{" { statement } "}"
```

#### Functions (Optional)
```
function_def    ::= "FN" IDENTIFIER "(" [ param_list ] ")" "->" IDENTIFIER "{" block "}"

param_list      ::= IDENTIFIER { "," IDENTIFIER }
```

#### Variables (Optional)
```
variable_decl   ::= "LET" IDENTIFIER "=" expression
```

### Complete Example

```alka
// Full Alka program with optional features
REQUIRE ivyb_pascal.alkavl;

LET aperture_size = 256MB;
LET num_windows = model_size / aperture_size;

CLAIM GPU_MAIN;

FOR i IN 0..num_windows {
    SHIFT GPU_MAIN.DATA_PLANE @ (i * aperture_size);
    FLOW NVME_BOOT[base + (i * aperture_size)] -> GPU_MAIN[0] aperture_size;
    FENCE GPU_MAIN.METAPAGE == 1;
}

IF gpu_temp > 80 THEN {
    YIELD 1000;
}

SYNC L3;
SIGNAL INFERENCE_COMPLETE;
```

### Minimal Equivalent

The same program as above, using only the instruction list format:

```alka
REQUIRE ivyb_pascal.alkavl;
CLAIM GPU_MAIN;
SHIFT GPU_MAIN.DATA_PLANE @ 0;
FLOW NVME_BOOT[0x1000] GPU_MAIN.DATA_PLANE[0] 256MB;
FENCE GPU_MAIN.METAPAGE == 1;
SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
FLOW NVME_BOOT[0x1100] GPU_MAIN.DATA_PLANE[0] 256MB;
FENCE GPU_MAIN.METAPAGE == 2;
SYNC L3;
SIGNAL 0x40;
```

### Grammar Notes

1. **All instructions are optional** - the language works with just the instruction list format
2. **Semicolons** - optional in simple programs, required in complex contexts
3. **Case sensitivity** - keywords are uppercase, identifiers are case-sensitive
4. **Comments** - `//` for single-line comments

---

## The Substrate (`.alkavl`)

The Vial defines the physical laws that Alka must obey. Every `.alka` program requires a target `.alkavl`.

```alkavl
Vessel GPU_MAIN {
    PCI_ID: 10de:1b82;
    
    Aperture DATA_PLANE {
        BAR: 1;
        MAX_WINDOW: 256MB;
        TYPE: Prefetchable;
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

---

## Complete Instruction Set (51 Unique Commands)

### Op-Code Map

| Op-Code | Name | Category | Description |
|---------|------|----------|-------------|
| 0x01 | CLAIM | CORE | Stake hardware node |
| 0x02 | STAKE | CORE | Claim memory region |
| 0x03 | FLOW | CORE | DMA transfer |
| 0x04 | SHIFT | CORE | Remap BAR window |
| 0x05 | FENCE | CORE | Wait for condition |
| 0x06 | SYNC | CORE | Memory barrier |
| 0x07 | SENSE | CORE | Read sensor |
| 0x08 | PULSE | CORE | Timing signal |
| 0x09 | SIGNAL | CORE | Trigger interrupt |
| 0x0A | YIELD | CORE | Cooperative yield |
| 0x0B | RECAST | FORGING | FPGA reconfigure |
| 0x0C | SNAP | CORE | Serialize state |
| 0x0D | REVERT | CORE | Restore state |
| 0x0E | LIMIT | CORE | Hard contract |
| 0x0F | VEIL | DISSOLUTION | Hide from OS |
| 0x10 | DELEGATE | CORE | CPU bypass |
| 0x11 | RHYTHM | PULSE | Timing constraint |
| 0x12 | DISTILL | CORE | Algorithmic synthesis |
| 0x13 | ENQUEUE | CORE | Command ring |
| 0x14 | MOLT | SOLIDIFICATION | Full state dump |
| 0x15 | VOUCH | CORE | Attestation |
| 0x16 | PROBE_BUS | CORE | Forensic audit |
| 0x17 | ECHO | CORE | Non-intrusive introspection |
| 0x18 | STASIS | PULSE | Bus-level locking |
| 0x19 | TRANSVERSE | CORE | Bit-level swizzling |
| 0x1A | SEARCH | CORE | Physical signature scanning |
| 0x1B | FOSSILIZE | SOLIDIFICATION | Substrate persistence |
| 0x1C | STRIKE | DISSOLUTION | Rowhammer/bit flipping |
| 0x1D | QUENCH | CALCINATION | Emergency power-state reset |
| 0x1E | FORGE | FORGING | Bitstream injection |
| 0x1F | VOID | CALCINATION | Secure substrate erase |
| 0x20 | ABDUCT | TRANSMUTATION | Physical page stealing |
| 0x21 | SNOOP | TRANSMUTATION | Cache-coherent monitoring |
| 0x22 | SCATTER | TRANSMUTATION | Vectored I/O (scatter-gather) |
| 0x23 | WHISPER | DISSOLUTION | Side-channel extraction |
| 0x24 | GHOST | DISSOLUTION | Configuration space masking |
| 0x25 | HIJACK | DISSOLUTION | IRQ stealing |
| 0x26 | DRIFT | PULSE | Cross-device sync |
| 0x27 | CLONE | SOLIDIFICATION | Full silicon snapshot |
| 0x28 | CRYSTALLIZE | FORGING | JIT-to-FPGA |
| 0x29 | OVERCLOCK | CALCINATION | Sub-driver tuning |
| 0x2A | FLUX | TRANSMUTATION | Cache invalidation |
| 0x2B | AUDIT | TESTING | Post-instruction residue check |
| 0x2C | DRY_RUN | TESTING | Simulate without executing |
| 0x2D | MOCK | TESTING | Use mock hardware for testing |
| 0x2E | PROVE | TESTING | Formal verification of invariants |
| 0x2F | WATCH | MONITOR | Real-time hardware state monitoring |
| 0x30 | TRACE | MONITOR | Instruction execution trace |
| 0x31 | GUARD | SAFETY | Runtime safety sentinel |
| 0x32 | ISOLATE | SAFETY | Complete hardware isolation |
| 0x33 | VERIFY | SAFETY | Cryptographic state verification |

---

## Six Alchemical Arts

### I. TRANSMUTATION (Memory & Data Sovereignty)
*The art of moving bits without the CPU "Bouncer" ever touching the payload.*

#### ABDUCT <phys_addr> <len>
Physical Page Stealing. Forces the Linux Kernel to "forget" a piece of RAM exists so it doesn't try to use it, while Alka keeps it pinned for raw DMA.
```alka
ABDUCT 0xe0000000 256MB;
```
*Op-Code: 0x20*

#### SNOOP <bus_addr> -> <vessel>
Cache-Coherent Monitoring. Reads data as it flies across the PCIe bus without triggering a "Read-Completion" that the hardware expects from the CPU.
```alka
SNOOP GPU_MAIN.BAR_0 -> traffic_log;
```
*Op-Code: 0x21*

#### FLUX <vessel>
Non-Maskable Cache Invalidation. Manually invalidates L1/L2 cache lines from the kernel without using slow generic `wbinvd` instructions, ensuring CPU sees "Fresh" DMA weights.
```alka
FLUX GPU_MAIN;
```
*Op-Code: 0x2A*

#### SCATTER <map_vessel> -> <node>
Vectored I/O (Scatter-Gather). Blasts a single model layer into 50 different non-contiguous physical VRAM chunks in one PCIe transaction.
```alka
SCATTER layer_map -> GPU_MAIN.DATA_PLANE;
```
*Op-Code: 0x22*

---

### II. DISSOLUTION (Security & Physical Exploitation)
*The art of breaking the "Virtual Illusion" of the Operating System.*

#### STRIKE <target> [PATTERN] [REPS]
Rowhammer / Bit-Flipping. Performs high-frequency non-cached access pattern on memory rows to induce electrical crosstalk and flip bits in "Locked" kernel page tables.
```alka
STRIKE 0xfffffff 0xAAAAAAAA 10000;
```
*Op-Code: 0x1C*

#### WHISPER <node> [TIMING]
Side-Channel Extraction. Measures nanosecond differences in BAR 0 response to determine if a secret key is being used by the official driver.
```alka
WHISPER GPU_MAIN.CTRL_PLANE 100ns;
```
*Op-Code: 0x23*

#### GHOST <pci_id>
Configuration Space Masking. Modifies PCI Header in real-time so the OS thinks the GPU is "Disconnected" or "Faulted," while Alka maintains a private DMA lane.
```alka
GHOST 10de:1b82;
```
*Op-Code: 0x24*

#### HIJACK <interrupt_vector>
IRQ Stealing. Intercepts a hardware signal (like "DMA Complete") before the Linux Kernel's interrupt handler can see it.
```alka
HIJACK 0x2f; // PCIe MSI-X vector
```
*Op-Code: 0x25*

#### VEIL <vessel>
Substrate Masking. Hides hardware from OS-level probing by manipulating PCIe Configuration Space.
```alka
VEIL GPU_MAIN;
```
*Op-Code: 0x0F*

---

### III. THE PULSE (Hard Real-Time & Timing)
*The art of nanosecond precision for the Cortical Annex.*

#### RHYTHM <node> <freq> [STRICT]
Hard-Clock Alignment. Bypasses CPU's "SpeedStep" and "Turbo Boost" to generate a clock signal that does not waver.
```alka
RHYTHM CORTICAL_ANNEX 1000Hz STRICT;
```
*Op-Code: 0x11*

#### STASIS <bus>
PCIe Bus Locking. Sends "Retry" TLPs to the CPU to freeze all other system traffic while critical operations complete.
```alka
STASIS PCIe_X16;
```
*Op-Code: 0x18*

#### DRIFT <node_a> <node_b>
Cross-Device Sync. Ensures devices are ticking on the exact same crystal oscillator cycle to prevent data tearing.
```alka
DRIFT NVME_BOOT GPU_MAIN;
```
*Op-Code: 0x26*

---

### IV. SOLIDIFICATION (Persistence & Firmware)
*The art of staying in the machine forever.*

#### FOSSILIZE <alka_seq> -> <node>
Shadow-ROM Injection. Writes bytecode to the "Option ROM" of a peripheral so it executes at power-on, before BIOS loads.
```alka
FOSSILIZE init_sequence -> GPU_MAIN.ROM;
```
*Op-Code: 0x1B*

#### CLONE <controller_state> -> <vessel>
Full Silicon Snapshots. Captures the *entire* internal state (registers, buffers, pipelines) of a device for perfect `REVERT`.
```alka
CLONE GPU_MAIN -> gpu_full_backup;
```
*Op-Code: 0x27*

#### MOLT <node> -> <vessel>
State Dump. Captures complete register state of a hardware controller as the "Antidote" foundation.
```alka
MOLT GPU_MAIN -> gpu_backup;
```
*Op-Code: 0x14*

---

### V. FORGING (FPGA & Isomorphic Gates)
*The art of turning Thought into Silicon on the KV260.*

#### FORGE <vessel> INTO <tile>
Partial Reconfiguration. Changes logic gates of *one part* of the FPGA while other parts continue running.
```alka
FORGE IMP_CORE INTO KV260.TILE_0;
```
*Op-Code: 0x1E*

#### CRYSTALLIZE <alka_logic> -> <gate_logic>
JIT-to-FPGA. Compiles high-level logic branch into a temporary hardware circuit.
```alka
CRYSTALLIZE inference_branch -> fpga_gate;
```
*Op-Code: 0x28*

#### RECAST <vessel> <bitstream>
FPGA Reconfigure. Dynamic reconfiguration (simpler version of FORGE).
```alka
RECAST KV260 CORE_METROD;
```
*Op-Code: 0x0B*

---

### VI. CALCINATION (Stress & Power Mastery)
*The art of pushing the silicon to its breaking point safely.*

#### QUENCH <node>
Thermal D3-Cold Cut. Bypasses OS power management to physically cut voltage via PCIe PM registers.
```alka
QUENCH GPU_MAIN;
```
*Op-Code: 0x1D*

#### OVERCLOCK <node> <voltage> <freq>
Sub-Driver Tuning. Pokes VRM controller directly to bypass "Safe" limits set by official driver.
```alka
OVERCLOCK GPU_MAIN 1.1V 2000MHz;
```
*Op-Code: 0x29*

#### VOID <node> [SECURE_LEVEL]
Secure Substrate Obliteration. Issues Sanitize command at block level, bypassing controller's logical maps.
```alka
VOID NVME_BOOT SECURE;
```
*Op-Code: 0x1F*

---

## Core Foundation Instructions

These form the foundation of the language:

#### CLAIM <vessel>
Atomically unbinds existing kernel drivers and stakes the physical registers for Alka.
```alka
CLAIM GPU_MAIN;
```
*Op-Code: 0x01*

#### STAKE <phys_addr> <len>
Claims a region of physical memory, marking it as "Reserved" from OS interference.
```alka
STAKE 0xe0000000 256MB;
```
*Op-Code: 0x02*

#### FLOW <src> -> <dst> [SIZE]
The Moore Stream - DMA transfer bypassing the CPU. If target exceeds aperture, compiler auto-injects SHIFT loop.
```alka
FLOW NVME_BOOT[0x1000] -> GPU_MAIN.DATA_PLANE[0] 256MB;
```
*Op-Code: 0x03*

#### SHIFT <vessel> @ <offset>
Remaps a BAR window to a new offset.
```alka
SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
```
*Op-Code: 0x04*

#### FENCE <vessel> <condition>
Spin-lock on a physical memory-mapped bit until condition is met.
```alka
FENCE GPU_MAIN.METAPAGE == 1;
```
*Op-Code: 0x05*

#### SYNC <level>
Memory barrier (L1=wmb, L2=rmb, L3=mb).
```alka
SYNC L3;
```
*Op-Code: 0x06*

#### SENSE <sensor> AS <vessel>
Maps hardware telemetry to a logic variable.
```alka
SENSE GPU_MAIN.THERMAL AS current_temp;
```
*Op-Code: 0x07*

#### PULSE <pin> <frequency>
Hardware timing signal for time-critical devices.
```alka
PULSE CORTICAL_ANNEX.CLOCK 1000Hz;
```
*Op-Code: 0x08*

#### SIGNAL <irq_vector>
Trigger a hardware interrupt to wake CPU.
```alka
SIGNAL 0x40;
```
*Op-Code: 0x09*

#### YIELD <microseconds>
Cooperative yield to Linux scheduler.
```alka
YIELD 1000;
```
*Op-Code: 0x0A*

#### SNAP <vessel> AS <blob>
State serialization - captures state for restoration.
```alka
SNAP GPU_MAIN.REGISTERS AS gpu_state_blob;
```
*Op-Code: 0x0C*

#### REVERT <vessel> TO <blob>
Restores previously SNAP'd state.
```alka
REVERT GPU_MAIN.REGISTERS TO gpu_state_blob;
```
*Op-Code: 0x0D*

#### LIMIT <vessel> <property> <max>
Hard contract enforcement.
```alka
LIMIT GPU_MAIN.THERMAL MAX 85C;
```
*Op-Code: 0x0E*

#### DELEGATE <controller> <sequence>
Hands control to secondary sequencer (DMA engine, KV260) for CPU-bypassing execution.
```alka
DELEGATE GPU_MAIN.DMA my_sequence;
```
*Op-Code: 0x10*

#### DISTILL <src> VIA <formula_id> -> <dst>
Algorithmic synthesis - triggers hardware ECC/decompressor to "hallucinate" target binary from entropy.
```alka
DISTILL compressed_data VIA ECC_XYZ -> VRAM_PAYLOAD;
```
*Op-Code: 0x12*

#### ENQUEUE <packet> TO <controller_ring>
Atomic descriptors - write directly to hardware command rings (NVMe, XHCI, GPU).
```alka
ENQUEUE my_flow_packet TO NVME_CMD_RING;
```
*Op-Code: 0x13*

#### VOUCH <node> [TPM_KEY]
Cryptographic attestation - signs all packets with sovereign key. Rejects unsigned packets.
```alka
VOUCH GPU_MAIN TPM_OWNER;
```
*Op-Code: 0x15*

#### PROBE_BUS <controller>
Bus-level forensic audit - measures throughput consistency, triggers REVERT on mismatch.
```alka
PROBE_BUS USB_XHCI;
```
*Op-Code: 0x16*

#### ECHO <node> TO <vessel>
Non-intrusive introspection - dual-write status to side-buffer without affecting hardware.
```alka
ECHO GPU_MAIN.REGISTERS -> debug_log;
```
*Op-Code: 0x17*

#### TRANSVERSE <vessel> VIA <pattern>
Bit-level swizzling - zero-CPU-cycle data transformation during FLOW.
```alka
TRANSVERSE payload VIA ENDIAN_SWAP;
```
*Op-Code: 0x19*

#### SEARCH <range> FOR <signature> -> <address_vessel>
Physical signature scanning - offloads brute-force search to GPU cores or KV260.
```alka
SEARCH SYSTEM_RAM FOR 0xDEADBEEF -> found_addr;
```
*Op-Code: 0x1A*

---

## AlkaSol Binary Format (`.alkas`)

Fixed 32-byte instruction packets (expanded to 64 bytes for complex ops):

### Packet Structure (32 bytes)
```
+00: OP_CODE    (1 byte)
+01: FLAGS      (1 byte)
+02: VESSEL_ID  (2 bytes)
+04: SRC_ADDR   (8 bytes)
+12: DST_ADDR   (8 bytes)
+20: SIZE       (4 bytes)
+24: RESERVED   (4 bytes)
+28: CRC        (4 bytes)
```

### Extended Packet Structure (64 bytes)
```
+00: OP_CODE    (1 byte)
+01: INTENSITY  (1 byte)
+02: SAFETY     (2 bytes)
+04: SRC_ADDR   (8 bytes)
+12: DST_ADDR   (8 bytes)
+20: LENGTH     (8 bytes)
+28: PATTERN    (32 bytes)
+58: AUTH_SIG   (4 bytes)
+5C: RESERVED   (4 bytes)
```

---

## Implicit Safety

The compiler automatically enforces:

1. **Automatic Windowing**: FLOW exceeding aperture triggers SHIFT loop injection
2. **Thermal Shadowing**: Heat-generating instructions wrapped with thermal checks
3. **Linear Resource Tracking**: Physical addresses as linear types - cannot be claimed twice

---

## VII. TESTING & VALIDATION (Safe Execution)
*The art of verifying hardware instructions without risking the metal.*

### Testing Architecture

Alka implements a three-tier testing model:
1. **Glass Vial**: Userspace logic mocking
2. **Phantom Substrate**: Kernel dry-run (DRY_RUN flag)
3. **Sacrificial Canary**: QEMU emulation

#### AUDIT <node>
Post-instruction residue check. After any operation, verifies no registers left in illegal state, no stale data in caches.
```alka
AUDIT GPU_MAIN; // Check for leftover state after FLOW
```
*Op-Code: 0x2B*

#### DRY_RUN <packet>
Simulate execution without physical side effects. Performs address calculations and sentinel checks, logs intended action, skips actual hardware poke.
```alka
DRY_RUN FLOW_PAYLOAD;
```
*Op-Code: 0x2C*

#### MOCK <substrate> -> <vessel>
Use mock hardware for testing. Creates virtual hardware representation for safe instruction validation.
```alka
MOCK VIRTUAL_GPU -> test_context;
```
*Op-Code: 0x2D*

#### PROVE <invariant>
Formal verification of invariants. Uses Brief contracts to mathematically prove state constraints before binary emission.
```alka
PROVE offset <= aperture_size;
```
*Op-Code: 0x2E*

---

## VIII. MONITORING & OBSERVABILITY
*The art of watching the machine think.*

#### WATCH <node> [interval]
Real-time hardware state monitoring. Continuous polling of sensor/memory values at specified interval.
```alka
WATCH GPU_MAIN.THERMAL 100ms;
```
*Op-Code: 0x2F*

#### TRACE <sequence>
Instruction execution trace. Logs every instruction execution to flight recorder for post-mortem analysis.
```alka
TRACE full_sequence;
```
*Op-Code: 0x30*

---

## IX. SAFETY & GUARDRAILS
*The art of preventing disaster.*

#### GUARD <vessel> <condition> <action>
Runtime safety sentinel. Monitors condition during execution; triggers action if violated.
```alka
GUARD GPU_MAIN.THERMAL > 85C QUENCH;
```
*Op-Code: 0x31*

#### ISOLATE <node>
Complete hardware isolation. Physically disconnects device from bus, blocks all DMA, IRQs.
```alka
ISOLATE USB_CONTROLLER;
```
*Op-Code: 0x32*

#### VERIFY <node> [TPM_KEY]
Cryptographic state verification. Computes hash of hardware state, compares against known-good value.
```alka
VERIFY GPU_MAIN TPM_ROOT;
```
*Op-Code: 0x33*

---

## Complexity Classification

| Complexity | Instructions |
|------------|--------------|
| **Low** | CLAIM, STAKE, YIELD, SNAP, REVERT, LIMIT, SIGNAL, RECAST, AUDIT, DRY_RUN, PROVE, TRACE |
| **Medium** | FLOW, SHIFT, FENCE, SYNC, SENSE, PULSE, ECHO, VOUCH, STASIS, FLUX, MOLT, CLONE, ENQUEUE, TRANSVERSE, MOCK, WATCH, GUARD, VERIFY |
| **High** | DELEGATE, RHYTHM, VEIL, SEARCH, FOSSILIZE, STRIKE, GHOST, HIJACK, DRIFT, FORGE, QUENCH, OVERCLOCK, VOID, WHISPER, DISTILL, PROBE_BUS, ABDUCT, ISOLATE |
| **Extreme** | STRIKE (Rowhammer), FOSSILIZE (Shadow-ROM), ABDUCT (Page Stealing), SCATTER (Vectored I/O), CRYSTALLIZE (JIT-to-FPGA) |

---

## Compiler Pipeline

```
.alka + .alkavl
      |
      v
[ Zig Compiler ] --> Metrod Packets (.alkab)
      |
      v
[ vitriol.ko ] --> Hardware Execution
```

---

## Safety Guarantees

1. **Compile-Time Verification**: All physical constraints checked at compile time
2. **No Double-Staking**: Linear types prevent resource conflicts
3. **Thermal Throttling**: Automatic yield injection near thermal limits
4. **Aperture Enforcement**: Sliding window generation for oversized transfers

---

## Research Context

Alka operates at the **Hardware-Software Integrity Gap**:

- **Substrate Sovereignty**: The OS is a "virtual reality" over physical reality
- **MMU Bypass**: DMA/P2P transfers don't consult CPU permission bits
- **Data-to-Execution Bridge**: The binary-level distinction between "data" and "instruction" is a convenience of the OS, not a physical truth
- **Physical Topography**: If you control where bits sit in physical memory, you control the machine

These principles apply to both:
- **Optimizing** AI workloads (Moore Stream)
- **Securing** systems against hardware-level threats (Forensic Audit, Attestation)

---

*Alka v2.0 - The Universal Solvent*