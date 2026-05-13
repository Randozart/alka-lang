# Alembic Language Specification

> The "Universal Solvent" for physical machine state orchestration

## Overview

Alembic (marketed as **Alka**) is a non-Turing-complete, contract-driven hardware instruction set designed for safe, verifiable manipulation of bare metal resources. It operates on the principle that hardware constraints should be encoded as compile-time contracts, not runtime checks.

### Design Philosophy

- **Contract-First**: The Substrate (`.alkavl`) is the source of truth. The compiler enforces physical limits automatically.
- **Zero Overhead**: Compiles to fixed-size binary packets (Metrod format). No interpreter, no runtime.
- **State-Assertive**: Not imperative ("do this") but declarative ("be in this state").
- **Isomorphic Verification**: The compiler automatically injects required operations (e.g., sliding window loops) based on substrate constraints.

---

## File Types

| Extension | Role | Description |
|-----------|------|-------------|
| `.alka` | The Solvent | High-level intent, instruction sequences |
| `.alkavl` | The Vial | Physical hardware topology and constraints |
| `.alkab` | The Precipitate | Compiled Metrod binary packets |

---

## The Substrate (`.alkavl`)

The Vial defines the physical laws that Alka must obey. Every `.alka` program requires a target `.alkavl`.

### Syntax

```alkavl
// Example: randy_pc_1070ti.alkavl
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
        POLL: nvidia-smi;
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

### Vessel Definition

A **Vessel** represents a physical hardware node with:
- **PCI_ID**: Vendor:Device identification
- **Aperture**: Memory-mapped I/O windows (BARs)
- **Thermal**: Temperature limits and sensors
- **Clock**: Timing specifications
- **DMA**: Direct memory access capabilities

---

## The Instruction Set

### Core Instructions

#### 1. CLAIM <vessel>
Atomically unbinds existing kernel drivers and stakes the physical registers for Alka.

```alka
CLAIM GPU_MAIN;
```

*Compiler Action*: Looks up the driver in the Substrate, performs safe unbind, locks registers.

---

#### 2. FLOW <src> -> <dst> [SIZE]
The Moore Stream - DMA transfer bypassing the CPU.

```alka
FLOW NVME_BOOT[0x1000] -> GPU_MAIN.DATA_PLANE[0] 256MB;
```

*Compiler Action*: Checks destination aperture size. If source exceeds window, automatically injects SHIFT loop.

---

#### 3. SHIFT <vessel> @ <offset>
Remaps a BAR window to a new offset.

```alka
SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
```

*Compiler Action*: Emits PCIe aperture remap sequence.

---

#### 4. FENCE <vessel> <condition>
Spin-lock on a physical memory-mapped bit until condition is met.

```alka
FENCE GPU_MAIN.METAPAGE == 1;
```

*Compiler Action*: Generates polled wait-state with timeout.

---

#### 5. SYNC <level>
Memory barrier instruction.

| Level | Effect |
|-------|--------|
| L1 | `wmb()` - Write barrier |
| L2 | `rmb()` - Read barrier |
| L3 | `mb()` - Full memory barrier |

```alka
SYNC L3;
```

---

#### 6. PULSE <pin> <frequency>
Hardware timing signal for time-critical devices (ADC, FPGA).

```alka
PULSE CORTICAL_ANNEX.CLOCK 1000Hz;
```

*Compiler Action*: Locks a CPU core for real-time toggling if specified.

---

#### 7. STAKE <phys_addr> <len>
Claims a region of physical memory, marking it as "Reserved" from OS interference.

```alka
STAKE 0xe0000000 256MB;
```

*Compiler Action*: Validates against Substrate. If region is "Kernel-Owned", compile fails.

---

#### 8. SENSE <sensor> AS <vessel>
Maps hardware telemetry to a logic variable.

```alka
SENSE GPU_MAIN.THERMAL AS current_temp;
```

---

#### 9. YIELD <microseconds>
Cooperative yield to Linux scheduler.

```alka
YIELD 1000; // Yield for 1000 microseconds
```

---

#### 10. SIGNAL <irq_vector>
Trigger a hardware interrupt to wake CPU.

```alka
SIGNAL 0x40; // Wake vector
```

---

#### 11. RECAST <vessel> <bitstream>
Dynamic FPGA reconfiguration (KV260).

```alka
RECAST KV260 CORE_METROD;
```

---

#### 12. SNAP / REVERT
Bit-level state serialization.

```alka
SNAP GPU_MAIN.REGISTERS AS gpu_state_blob;
REVERT GPU_MAIN.REGISTERS TO gpu_state_blob;
```

---

## Implicit Safety

The compiler automatically enforces:

### 1. Automatic Windowing
If `FLOW` target exceeds aperture:
```alka
// User writes:
FLOW model.weights -> GPU_MAIN.DATA_PLANE; // 5.5GB

// Compiler generates:
SHIFT GPU_MAIN.DATA_PLANE @ 0;
FLOW ... 256MB;
FENCE ...;
SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
FLOW ... 256MB;
// ... repeat 22 times
```

### 2. Thermal Shadowing
Every heat-generating instruction wrapped with implicit thermal check.

### 3. Linear Resource Tracking
Physical addresses are linear types - cannot be claimed twice.

---

## Metrod Binary Format (`.alkab`)

Fixed 32-byte instruction packets sent directly to kernel module.

### Packet Structure

```
+00: OP_CODE    (1 byte)  - Instruction identifier
+01: FLAGS      (1 byte)  - Execution flags
+02: VESSEL_ID  (2 bytes) - Target vessel index
+04: SRC_ADDR   (8 bytes) - Physical source address
+12: DST_ADDR   (8 bytes) - Physical destination address
+20: SIZE       (4 bytes) - Transfer size
+24: RESERVED   (4 bytes) - Alignment padding
+28: CRC        (4 bytes) - Integrity check
```

### Op-Code Table

| Op-Code | Name | Description |
|---------|------|-------------|
| 0x01 | CLAIM | Stake hardware node |
| 0x02 | STAKE | Claim memory region |
| 0x03 | FLOW | DMA transfer |
| 0x04 | SHIFT | Remap BAR window |
| 0x05 | FENCE | Wait for condition |
| 0x06 | SYNC | Memory barrier |
| 0x07 | SENSE | Read sensor |
| 0x08 | PULSE | Timing signal |
| 0x09 | SIGNAL | Trigger interrupt |
| 0x0A | YIELD | Cooperative yield |
| 0x0B | RECAST | FPGA reconfigure |
| 0x0C | SNAP | Serialize state |
| 0x0D | REVERT | Restore state |

---

## Example Program

```alka
// alka: Purify_1070Ti
// vial: randy_pc_1070ti.alkavl

REQUIRE substrate.GPU.THERMAL.MAX < 85C;

CLAIM GPU_MAIN;
CLAIM NVME_BOOT;

LIMIT GPU_MAIN.THERMAL MAX 85C;

SHIFT GPU_MAIN.DATA_PLANE @ 0;
FLOW NVME_BOOT[0x1000] GPU_MAIN.DATA_PLANE[0] 256MB;
FENCE GPU_MAIN.METAPAGE == 1;

SHIFT GPU_MAIN.DATA_PLANE @ 256MB;
FLOW NVME_BOOT[0x1100] GPU_MAIN.DATA_PLANE[0] 144MB;
FENCE GPU_MAIN.METAPAGE == 2;

SYNC L3;
SIGNAL 0x40;
```

Compiles to a sequence of `.alkab` packets executed by `vitriol.ko`.

---

## Compiler Pipeline

```
.alka + .alkavl
      |
      v
[ Zig Compiler ] --comptime validation--> Metrod Packets (.alkab)
      |
      v
[ vitriol.ko ] --IOCTL--> Hardware Execution
```

---

## Safety Guarantees

1. **Compile-Time Verification**: All physical constraints checked at compile time
2. **No Double-Staking**: Linear types prevent resource conflicts
3. **Thermal Throttling**: Automatic yield injection near thermal limits
4. **Aperture Enforcement**: Sliding window generation for oversized transfers

---

## Implementation Targets

- **Compiler**: Zig (comptime for validation)
- **Executor**: C/Zig kernel module (`vitriol.ko`)
- **High-Level**: Brief transpiler to Alka

---

## Extended Instruction Set (Research Features)

### 13. VEIL <vessel>
Substrate masking - hides hardware from OS-level probing.

```alka
VEIL GPU_MAIN;  // GPU disappears from lspci, continues running
```

*Compiler Action*: Manipulates PCIe Configuration Space to report zero/error to OS probes while maintaining private physical link.

---

### 14. DELEGATE <controller> <sequence>
Hands control to a secondary sequencer (DMA engine, KV260) for CPU-bypassing execution.

```alka
DELEGATE GPU_MAIN.DMA my_alka_sequence;
```

*Compiler Action*: Pre-compiles Metrod packet chain and hands to hardware controller. CPU returns to idle - execution happens entirely on PCIe fabric.

---

### 15. RHYTHM <node> [JITTER_MAX]
Temporal guardrails - defines timing budget for real-time operations.

```alka
RHYTHM CORTICAL_ANNEX 100us;  // Max 100 microsecond jitter
```

*Compiler Action*: Injects TLP priority packets to "shove" traffic, or triggers safe-halt on bus congestion.

---

### 16. DISTILL <src> VIA <formula_id> -> <dst>
Algorithmic synthesis - triggers hardware ECC/decompressor to "hallucinate" target binary from entropy.

```alka
DISTILL compressed_data VIA ECC_XYZ -> VRAM_PAYLOAD;
```

*Compiler Action*: Bounded by ECC polynomial limits. Used for "Vector 2" reconstruction attacks/defense.

---

### 17. ENQUEUE <packet> TO <controller_ring>
Atomic descriptors - write directly to hardware command rings (NVMe, XHCI, GPU).

```alka
ENQUEUE my_flow_packet TO NVME_CMD_RING;
```

*Compiler Action*: Stakes memory location of controller ring. Hardware reads commands directly from GPU memory - CPU never woken.

---

### 18. MOLT <node> -> <vessel>
Full controller state dump - captures complete register state of a hardware controller.

```alka
MOLT USB_XHCI -> usb_backup_blob;
```

*Compiler Action*: Creates the "Antidote" - stores complete silicon state for restoration.

---

### 19. VOUCH <node> [TPM_KEY]
Cryptographic attestation - signs all packets with sovereign key.

```alka
VOUCH GPU_MAIN TPM_OWNER;
```

*Compiler Action*: Rejects any unsigned packet. Prevents hijacking by foreign Alka payloads.

---

### 20. PROBE_BUS <controller>
Bus-level forensic audit - measures throughput consistency.

```alka
PROBE_BUS USB_XHCI;
```

*Compiler Action*: Compares physical TLP count vs OS filesystem bytes. Triggers REVERT on mismatch (sub-kernel leak detection).

---

### 21. LIMIT <vessel> <property> <max>
Hard contract enforcement (already in core, enhanced here).

```alka
LIMIT GPU_MAIN.THERMAL MAX 80C;
LIMIT USB_XHCI.MAX_RATE 5Gbps;
```

---

## Remote Execution Architecture

### Net-Poll Shim
For remote control without SSH bottleneck:
- UDP-based packet injection
- Kernel module intercepts at interrupt handler level
- Bypasses Linux networking stack entirely

### Metrod Network Packet (48 bytes)
```
+00: Standard Alka Instruction (32 bytes)
+20: Sequence_ID (8 bytes)      // Prevents replay attacks
+28: Auth_HMAC (16 bytes)       // Cryptographic proof of sovereignty
+38: Timing_Constraint (8 bytes) // Max execution delay (nanoseconds)
+40: Reserved (8 bytes)
```

### Staged Execution Model
1. **Email 1 (Payload)**: PNG/PDF with stenographed Alka fragments
2. **Email 2 (Trigger)**: Exploit triggers bootstrap to assemble fragments
3. **Execution**: Bootstrap hands to vitriol module via IOCTL

---

## USB Exfiltration ("Double Agent")

### XHCI Controller Mapping
```alkavl
Vessel USB_CONTROLLER {
    PCI_ID: 1b36:000d;  // Standard XHCI
    DMA_RING_ADDR: 0x...;
    SLACK_SPACE: 4KB;   // Hidden sectors outside partition table
}
```

### Shadow FLOW
```alka
CLAIM USB_CONTROLLER;
// User copies "benign" file...
FLOW target.secrets_ram -> USB_CONTROLLER.DMA_BUFFER;
// ...interleaved with legitimate transfer
```

### Detection Counter
PROBE_BUS detects mismatch between OS file operations and physical TLP traffic.

---

## BYOVD (Bring Your Own Vulnerable Driver)

### Exploitation Vectors
1. **WebGPU/Vulkan Escape**: Browser shader OOB access to BAR registers
2. **ROP Gadget Heist**: Chain existing kernel code (nvidia.ko, xhci-hcd.ko) as primitives
3. **Signed Driver Proxy**: Use legitimate but over-privileged driver as Alka runner

### Gadget Finder
Tool to scan binary for sequences matching Alka opcodes:
- Scan existing drivers for FLOW/SHIFT/CLAIM equivalent sequences
- Emit "Address Lists" instead of raw bytecode

---

## Antidote System

### State Restoration Workflow
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

### MOLT-based Restoration
```alka
MOLT USB_XHCI -> backup;
REVERT backup -> USB_XHCI;
```

---

## Defense Research Applications

### Hardware- Assisted Zero Trust
1. **CDR (Content Disarm)**: Strip all metadata, re-render pixels - destroys stenographic payloads
2. **Remote Browser Isolation**: Execute web content in cloud container - GPU exploits hit disposable server
3. **Control Flow Guarding**: Intel CET detects illegal RIP jumps from ROP chains

### Physical Firewall
- IOMMU (VT-d) enforces static memory partitioning
- KV260 monitors PCIe bus for anomalous TLP patterns
- TPM-based attestation of critical memory regions

---

## Research Context

Alka operates at the **Hardware-Software Integrity Gap**. This research explores:

- **Substrate Sovereignty**: The OS is a "virtual reality" over physical reality
- **MMU Bypass**: DMA/P2P transfers don't consult CPU permission bits
- **Data-to-Execution Bridge**: The binary-level distinction between "data" and "instruction" is a convenience of the OS, not a physical truth
- **Physical Topography**: If you control where bits sit in physical memory, you control the machine

These principles apply to both:
- **Optimizing** AI workloads (Moore Stream)
- **Securing** systems against hardware-level threats (Forensic Audit, Attestation)

---

## Op-Code Table (Extended)

| Op-Code | Name | Description |
|---------|------|-------------|
| 0x01 | CLAIM | Stake hardware node |
| 0x02 | STAKE | Claim memory region |
| 0x03 | FLOW | DMA transfer |
| 0x04 | SHIFT | Remap BAR window |
| 0x05 | FENCE | Wait for condition |
| 0x06 | SYNC | Memory barrier |
| 0x07 | SENSE | Read sensor |
| 0x08 | PULSE | Timing signal |
| 0x09 | SIGNAL | Trigger interrupt |
| 0x0A | YIELD | Cooperative yield |
| 0x0B | RECAST | FPGA reconfigure |
| 0x0C | SNAP | Serialize state |
| 0x0D | REVERT | Restore state |
| 0x0E | LIMIT | Hard contract |
| 0x0F | VEIL | Hide from OS |
| 0x10 | DELEGATE | CPU bypass |
| 0x11 | RHYTHM | Timing constraint |
| 0x12 | DISTILL | Algorithmic synthesis |
| 0x13 | ENQUEUE | Command ring |
| 0x14 | MOLT | Full state dump |
| 0x15 | VOUCH | Attestation |
| 0x16 | PROBE_BUS | Forensic audit |
| 0x17 | ECHO | Non-intrusive introspection |
| 0x18 | STASIS | Bus-level locking |
| 0x19 | TRANSVERSE | Bit-level swizzling |
| 0x1A | SEARCH | Physical signature scanning |
| 0x1B | FOSSILIZE | Substrate persistence |
| 0x1C | STRIKE | Rowhammer/bit flipping |
| 0x1D | QUENCH | Emergency power-state reset |
| 0x1E | FORGE | Bitstream injection |
| 0x1F | VOID | Secure substrate erase |
| 0x20 | ABDUCT | Physical page stealing |
| 0x21 | SNOOP | Cache-coherent monitoring |
| 0x22 | SCATTER | Vectored I/O (scatter-gather) |
| 0x23 | WHISPER | Side-channel extraction |
| 0x24 | GHOST | Configuration space masking |
| 0x25 | HIJACK | IRQ stealing |
| 0x26 | DRIFT | Cross-device sync |
| 0x27 | CLONE | Full silicon snapshot |
| 0x28 | CRYSTALLIZE | JIT-to-FPGA |
| 0x29 | OVERCLOCK | Sub-driver tuning |

---

## Complete Instruction Reference (Six Alchemical Arts)

### I. TRANSMUTATION (Memory & Data Sovereignty)
*The art of moving bits without the CPU "Bouncer" ever touching the payload.*

#### ABDUCT <phys_addr> <len>
Physical Page Stealing. Forces the Linux Kernel to "forget" a piece of RAM exists so it doesn't try to use it, while Alka keeps it pinned for raw DMA.
```alka
ABDUCT 0xe0000000 256MB;
```

#### SNOOP <bus_addr> -> <vessel>
Cache-Coherent Monitoring. Reads data as it flies across the PCIe bus without triggering a "Read-Completion" that the hardware expects from the CPU.
```alka
SNOOP GPU_MAIN.BAR_0 -> traffic_log;
```

#### FLUX <vessel>
Non-Maskable Cache Invalidation. Manually invalidates L1/L2 cache lines from the kernel without using slow generic `wbinvd` instructions, ensuring CPU sees "Fresh" DMA weights.
```alka
FLUX GPU_MAIN;
```

#### SCATTER <map_vessel> -> <node>
Vectored I/O (Scatter-Gather). Blasts a single model layer into 50 different non-contiguous physical VRAM chunks in one PCIe transaction.
```alka
SCATTER layer_map -> GPU_MAIN.DATA_PLANE;
```

---

### II. DISSOLUTION (Security & Physical Exploitation)
*The art of breaking the "Virtual Illusion" of the Operating System.*

#### STRIKE <target> [PATTERN] [REPS]
Rowhammer / Bit-Flipping. Performs high-frequency non-cached access pattern on memory rows to induce electrical crosstalk and flip bits in "Locked" kernel page tables.
```alka
STRIKE 0xfffffff 0xAAAAAAAA 10000;
```

#### WHISPER <node> [TIMING]
Side-Channel Extraction. Measures nanosecond differences in BAR 0 response to determine if a secret key is being used by the official driver.
```alka
WHISPER GPU_MAIN.CTRL_PLANE 100ns;
```

#### GHOST <pci_id>
Configuration Space Masking. Modifies PCI Header in real-time so the OS thinks the GPU is "Disconnected" or "Faulted," while Alka maintains a private DMA lane.
```alka
GHOST 10de:1b82;
```

#### HIJACK <interrupt_vector>
IRQ Stealing. Intercepts a hardware signal (like "DMA Complete") before the Linux Kernel's interrupt handler can see it.
```alka
HIJACK 0x2f; // PCIe MSI-X vector
```

---

### III. THE PULSE (Hard Real-Time & Timing)
*The art of nanosecond precision for the Cortical Annex.*

#### RHYTHM <node> <freq> [STRICT]
Hard-Clock Alignment. Bypasses CPU's "SpeedStep" and "Turbo Boost" to generate a clock signal that does not waver by a single picosecond.
```alka
RHYTHM CORTICAL_ANNEX 1000Hz STRICT;
```

#### STASIS <bus>
PCIe Bus Locking. Sends "Retry" TLPs to the CPU to freeze all other system traffic while a critical sEMG signal is being processed.
```alka
STASIS PCIe_X16;
```

#### DRIFT <node_a> <node_b>
Cross-Device Sync. Ensures NVMe drive and GPU are ticking on the exact same crystal oscillator cycle to prevent data tearing.
```alka
DRIFT NVME_BOOT GPU_MAIN;
```

---

### IV. SOLIDIFICATION (Persistence & Firmware)
*The art of staying in the machine forever.*

#### FOSSILIZE <alka_seq> -> <node>
Shadow-ROM Injection. Writes bytecode to the "Option ROM" of a peripheral (NIC or GPU) so it executes at power-on, before the BIOS loads.
```alka
FOSSILIZE init_sequence -> GPU_MAIN.ROM;
```

#### CLONE <controller_state> -> <vessel>
Full Silicon Snapshots. Captures the *entire* internal state (registers, buffers, pipelines) of a device to allow for perfect `REVERT`.
```alka
CLONE GPU_MAIN -> gpu_full_backup;
```

---

### V. FORGING (FPGA & Isomorphic Gates)
*The art of turning Thought into Silicon on the KV260.*

#### FORGE <vessel> INTO <tile>
Partial Reconfiguration. Changes the logic gates of *one part* of the FPGA to run a new LLM kernel while the *other part* handles the Cortical Annex.
```alka
FORGE IMP_CORE INTO KV260.TILE_0;
```

#### CRYSTALLIZE <alka_logic> -> <gate_logic>
JIT-to-FPGA. Takes a high-level logic branch and compiles it into a temporary hardware circuit instead of running it on the ARM core.
```alka
CRYSTALLIZE inference_branch -> fpga_gate;
```

---

### VI. CALCINATION (Stress & Power Mastery)
*The art of pushing the silicon to its breaking point safely.*

#### QUENCH <node>
Thermal D3-Cold Cut. Bypasses OS power management to physically cut voltage to a component via PCIe PM (Power Management) registers.
```alka
QUENCH GPU_MAIN;
```

#### OVERCLOCK <node> <voltage> <freq>
Sub-Driver Tuning. Pokes the VRM (Voltage Regulator Module) controller on the GPU directly to bypass "Safe" limits set by the official driver.
```alka
OVERCLOCK GPU_MAIN 1.1V 2000MHz;
```

#### VOID <node>
Secure Substrate Obliteration. Issues a **Sanitize** command to NVMe at block level, bypassing controller's "Logical" maps to ensure every electron is cleared.
```alka
VOID NVME_BOOT SECURE;
```

---

## Additional Core Instructions (Already Defined)

These instructions were defined in earlier sections and form the foundation:

- **CLAIM** - Stake hardware node
- **STAKE** - Claim memory region  
- **FLOW** - DMA transfer
- **SHIFT** - Remap BAR window
- **FENCE** - Wait for condition
- **SYNC** - Memory barrier
- **SENSE** - Read sensor
- **PULSE** - Timing signal
- **SIGNAL** - Trigger interrupt
- **YIELD** - Cooperative yield
- **RECAST** - FPGA reconfigure
- **SNAP** / **REVERT** - State serialization
- **LIMIT** - Hard contract
- **VEIL** - Hide from OS
- **DELEGATE** - CPU bypass
- **DISTILL** - Algorithmic synthesis
- **ENQUEUE** - Command ring
- **MOLT** - Full state dump
- **VOUCH** - Attestation
- **PROBE_BUS** - Forensic audit
- **ECHO** - Non-intrusive introspection
- **TRANSVERSE** - Bit-level swizzling
- **SEARCH** - Physical signature scanning

---

## Complexity Classification

| Complexity | Instructions |
|------------|--------------|
| **Low** | CLAIM, STAKE, YIELD, SNAP, REVERT, LIMIT, SIGNAL |
| **Medium** | FLOW, SHIFT, FENCE, SYNC, SENSE, PULSE, ECHO, VOUCH, STASIS, FLUX, MOLT, CLONE |
| **High** | DELEGATE, RHYTHM, VEIL, ENQUEUE, SEARCH, TRANSVERSE, FOSSILIZE, STRIKE, GHOST, HIJACK, DRIFT, FORGE, QUENCH, OVERCLOCK, VOID, WHISPER |
| **Extreme** | STRIKE (Rowhammer), FOSSILIZE (Shadow-ROM), ABDUCT, SCATTER, CRYSTALLIZE |