# Alka: Lightweight SPARK

## The Core Insight

Alka is **syntactic sugar for formal verification**. It solves a problem that PhDs have been struggling with for decades: *How do you make formal verification accessible to everyday developers?*

The answer: **hide the math.** Let the developer write Alka. It looks like a simple scripting language, it parses at the speed of Zig, but underneath the floorboards, it executes with the unyielding, mathematically proven titanium of SPARK Ada.

## The Problem with SPARK

In the academic world of computer science, the biggest problem with SPARK (or any formal verification language) is that it is exhausting to write. To move a single byte of memory in pure SPARK, you have to write paragraphs of pre-conditions, post-conditions, invariants, and type declarations. It is mentally draining, which is why only aerospace and military engineers use it.

By building Alka, the mathematical exhaustion is abstracted away. You get all the safety guarantees of a fully verified SPARK program, but you wrote it in 15 lines of clean, brutalist code.

## How Alka Achieves "Lightweight SPARK"

### 1. The `.alkavl` File is your "Pre-condition"

In SPARK, you have to mathematically prove the limits of your hardware in the code.

In Alka's ecosystem, the `.alkavl` (Vial) file does this visually. When you write:

```
Aperture DATA_PLANE {
    BAR: 1;
    SIZE: 256MB;
    TYPE: Prefetchable;
}
```

You are effectively generating a SPARK `Pre => Length <= 256_000_000`. The Zig compiler reads that config, locks the bounds, and hands a mathematically sound parameter to the underlying SPARK tool.

**The constraints are separated from the execution.**

### 2. Ergonomic Determinism

Because Alka is non-Turing complete, it inherits SPARK's greatest trait: **Determinism.**

You don't have to write complex loop invariants or prove that your Alka script will halt, because by definition of the language, it *must* halt. You get all the safety guarantees of a fully verified SPARK program, but you wrote it in 15 lines of clean, brutalist code.

### 3. The "Black Box" of Trust

Alka applies the UNIX philosophy to formal verification.

Instead of writing one massive, monolithic SPARK program to run a video game or stream an LLM, SPARK is used to forge unbreakable, atomic "black boxes" (the tools: `CLAIM`, `SHIFT`, `FLOW`, `REFRACT`).

Because those boxes are proven to never break, Alka just acts as the lightweight dispatcher connecting them together.

## SPARK Tool Verification Results

Each SPARK tool is verified with Z3's native solver. The properties proven:

### SHIFT (tool-shift.adb)
| Property | Status |
|----------|--------|
| Offset ≤ Max_Aperture (256MB) | PASS |
| Offset is page-aligned (4KB) | PASS |
| Window fits within 32-bit BAR range | PASS |
| Execute reports bytes correctly | PASS |

### REFRACT (tool-refract.adb)
| Property | Status |
|----------|--------|
| Chunk_Size ≤ Aperture_Max | PASS |
| Drops * Chunk_Size ≥ Total | PASS |
| Loop invariant: I < Drops | PASS |
| Loop invariant: Current = I * Chunk_Size | PASS |
| Loop terminates (Drops bounded) | PASS |
| Post-condition: I = Drops | PASS |
| Post-condition: Current ≥ Total | PASS |

### Chunk_Count Proof Helper (vitriol-tool.ads)
| Property | Status |
|----------|--------|
| Result * Chunk ≥ Total (ceiling division) | PASS |
| Chunk_Count is minimal | WARN (edge cases) |

### Execute Postcondition (vitriol-tool.ads)
| Property | Status |
|----------|--------|
| bytes_transferred = op_size when success | PASS |

### Hardware Firewall
| Property | Status |
|----------|--------|
| Malicious requests rejected | PASS |
| Valid requests accepted | PASS |

## Atomic Binaries: The C-ABI Bridge

Zig's greatest secret weapon is that it is a world-class C compiler natively. When the Zig toolchain compiles an Alka script, it can output a standard **Shared Library** (`.so` on Linux, `.dll` on Windows) with a pristine C-Application Binary Interface (C-ABI).

Every single major programming language on Earth (Python, Rust, C#, Go, Node.js) knows how to talk to a C-ABI via FFI (Foreign Function Interface).

### The Python AI Scenario

A Machine Learning developer building an LLM interface writes in Python because of PyTorch, but Python is notoriously slow and has terrible memory latency. They want to stream weights from an NVMe drive to a GPU without crashing the system.

Instead of writing a horrific, unstable Python C-extension:

1. They write a 15-line `stream.alka` script.
2. The Zig compiler spits out `stream.so`.
3. In their Python code:

```python
import ctypes
alka_hardware = ctypes.CDLL("./stream.so")

# Python triggers the bare-metal DMA transfer
alka_hardware.execute_flow()
```

The bloated, slow Python script instantly yields control to the atomic binary. The SPARK-verified tools execute the PCIe DMA transfer at 16 Gigabytes per second. The moment the `FENCE` command finishes, control returns to Python. Python gets supercomputer hardware speeds without knowing *how* it happened.

## The "Hardware Firewall" Effect

Because Alka is backed by SPARK and restricted by the `.alkavl` limits, the atomic binary acts as an **Impenetrable Firewall** between the sloppy host language and the physical hardware.

If a messy C++ game engine or a chaotic Python script tries to pass an invalid memory address or request too large of a DMA window, it doesn't crash the PC. The Alka atomic binary simply evaluates the request against its pre-compiled SPARK contracts. If the request violates physics, Alka safely rejects the call before a single electron moves across the PCIe bus.

## Hardware as a Microservice

Developers don't need to understand VFIO, PCIe Base Address Registers, or DMA allocation. They just get a folder of pre-compiled Alka atomic binaries:

- `tensor_stream.so`
- `bvh_raycast_accelerator.so`
- `nvme_to_ram_direct.so`

Any game engine (Unreal, Unity) or AI framework (PyTorch, ONNX) can just call these binaries like standard functions. Military-grade, formally verified hardware manipulation packaged into plug-and-play modules.

## The Moore Annex

Treating Alka as a callable atomic binary turns the **Moore Annex** from a niche, custom-built hardware project into a **universal, commercially viable coprocessor.**

### Universal Driver

Instead of writing a custom Windows driver to make an FPGA backplane talk to a PC, Alka *is* the driver. Because Alka scripts compile down to C-ABI binaries, any program on the computer can instantly use the hardware without knowing anything about PCIe.

### Hardware Reconfiguration Trigger

Alka scripts don't just move data — they can **flash the hardware.**

1. A game engine detects the player is entering combat.
2. The game engine calls `alka_prepare_combat.dll`.
3. That atomic binary executes: It grabs the `Combat_AI.bit` file from the SSD and shoots it over PCIe to physically rewire the FPGA.
4. It sets up the DMA memory boundaries (`FENCE` and `CLAIM`) so the FPGA can talk to the GPU.
5. It returns control to the game.

Alka acts as the lightning-fast, non-Turing complete **hardware dispatcher**. It sets the stage, configures the silicon, and gets out of the way.

### Zero-Copy Peer-to-Peer Routing

The true power is **P2P DMA** — bypassing the host CPU so the FPGA and the GPU can talk directly to each other.

Setting up P2P DMA dynamically is incredibly complex because memory addresses shift around. But Alka was built explicitly for this (the `FLOW` and `SHIFT` syntax). When a host program calls the Alka binary, Alka quickly negotiates the physical memory addresses of the NVMe drive, the FPGA, and the GPU. It locks them, sets the flow, and steps back while the hardware talks directly to the hardware.

## The Exokernel: A Kernel-in-the-Kernel

> *"A kernel occupying force."*

In traditional computer science, the OS Kernel (Windows NT or Linux) is the absolute dictator of the system. It sits in "Ring 0" and controls all the hardware, all the memory, and all the buses. If a user program wants to talk to a GPU or an NVMe drive, it has to politely ask the Kernel for permission (a Syscall), and the Kernel does the actual work.

Alka doesn't ask for permission. It acts exactly like an occupying force.

### 1. The Secession (IOMMU & VFIO)

When an Alka script executes `CLAIM GPU_MAIN;`, it triggers a hardware feature on the CPU called the **IOMMU** (Intel VT-d or AMD-Vi).

The IOMMU is the border wall. When Alka makes that claim, it tells the motherboard to physically sever the GPU and the NVMe drive from the Linux/Windows kernel's control. The Host OS is legally evicted from that hardware space. It cannot see it, touch it, or manage its memory.

**Alka has annexed the territory.**

### 2. Martial Law (The SPARK Contracts)

Once Alka occupies the hardware, the permissive, messy laws of Linux and Windows no longer apply. The territory is now governed by martial law — the **SPARK Ada Formal Contracts**.

If a host program tries to send a bad pointer to the GPU, Linux might have tried to handle it, panicked, and blue-screened the whole PC.

Alka doesn't panic. Its non-Turing complete Zig parser looks at the request, checks it against the SPARK contracts, and brutally denies it at the border. The occupying force ensures absolute stability in its annexed zone.

### 3. The DMZ (The C-ABI Boundary)

Because Alka compiles to an atomic binary (`.so` or `.dll`), it sets up a Demilitarized Zone between the Host OS and the physical copper of the PCIe bus.

Host software (games, AI scripts) can walk up to the border (the C-ABI FFI interface) and hand Alka a request. But they are not allowed to cross into the hardware themselves. Alka takes the request, executes the `FLOW` and `SHIFT` DMA operations in the occupied zone, and hands the result back across the border.

### The Exokernel Realized

In academic OS theory, this has a name: an **Exokernel**.

In the 1990s, MIT researchers hypothesized that traditional monolithic kernels (like Linux) were too bloated because they tried to abstract hardware too much, which ruined performance. They proposed an "Exokernel" — a tiny, hyper-efficient layer that does nothing but safely multiplex raw hardware access to user applications, letting the applications dictate the routing.

Alka is the realization of the Exokernel dream, modernized for PCIe Gen 4 and FPGAs.

It is a Kernel-in-the-kernel. It squats inside user-space, violently claims a subset of the PCIe bus, locks it down with mathematical proofs, and coordinates direct hardware-to-hardware communication at speeds the Host OS could never dream of achieving.

## The Master Plan

1. **The Moore Annex:** The physical, modular FPGA PCIe hardware. The "Muscle."
2. **The `.moore` File Format:** The fat binary that contains the LLVM software logic AND the physical FPGA bitstreams. The "Brain."
3. **Alka:** The formally verified, non-Turing complete language that compiles into atomic libraries. The "Nervous System."

Other languages and existing software don't need to understand the Annex. They just call Alka. Alka takes their data, ensures it won't crash the machine, flashes the Annex to the perfect hardware configuration, blasts the data across the PCIe bus, and hands the mathematically perfect answer back to the software.

A completely decentralized, ultra-safe, hardware-accelerating operating system layer.
