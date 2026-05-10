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