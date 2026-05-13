# Alka Roadmap — 2026-05-13

> Based on SPECv4 for Alka. Extends it with the embed architecture, atomic binary output,
> declarative syntax, proof automation, and CLI overhaul defined in this document.
>
> This roadmap was written on 2026-05-13 against SPECv4 and supersedes any earlier planning.

## Overview

Alka is lightweight SPARK — syntactic sugar for formal verification. The language is non-Turing
complete, inheriting SPARK's determinism, and compiles to atomic 32-byte Drops that the VITRIOL
kernel module executes. Each Drop is a single hardware operation (CLAIM, FLOW, SHIFT, FENCE, REFRACT,
SIGNAL, etc.) constrained by a `.alkavl` Vial file that encodes the target hardware's limits.

The roadmap has 8 phases. Phases 0–2 are prerequisites. Phases 3–5 can run in parallel.
Phases 6–7 are polish and distribution.

```
Phase 0 (Rename Metrod → Drop) ──────────┐
                                          ├──→ Phase 1 (SPARK tool completion)
                                          │         │
                                          │         └──→ Phase 6 (Proof automation)
                                          │
                                          ├──→ Phase 2 (Atomic binary output)
                                          │         │
                                          │         ├──→ Phase 3 (Embed/.alkar)
                                          │         │         │
                                          │         │         └──→ Phase 5 (Declarative syntax)
                                          │         │
                                          │         └──→ Phase 4 (CLI overhaul)
                                          │
                                          └──→ Phase 7 (Install target)
```

---

## Phase 0: Rename — Metrod → Drop

### Why

The term "Metrod" refers to a separate project (language cross-communication). Alka's 32-byte
packet has nothing to do with that project. The packet is the atomic execution unit of the VITRIOL
pipeline — a single hardware operation packed into 32 bytes. The `.alkas` file (Alka Sol) is an
array of these units.

The new name is **Drop** — the smallest unit of the Alka Sol. When VITRIOL processes the Sol,
it precipitates individual Drops. This is theologically consistent with the Alchemical Mirror
theme (see ALKA_REPL_THE_ALCHEMICAL_MIRROR.md).

### Rename mapping

| Current | New | Scope |
|---------|-----|-------|
| `MetrodPacket` | `Drop` | All Zig structs |
| `MetrodPacketExt` | `DropExt` | 64-byte extended variant |
| `METROD_PACKET_SIZE` | `DROP_SIZE` | C macros + Zig constants |
| `emitMetrod()` | `emitDrops()` | Codegen functions |
| `struct metrod_packet` | `struct alka_drop` | Kernel C headers |
| `Metrod_Packet` | `Drop_Type` | SPARK Ada spec |

### Files to modify (18 source files)

| File | Type | Approx. occurrences |
|------|------|---------------------|
| `src/codegen/alka_bin.zig` | Zig struct defs + functions | 11 |
| `src/codegen/codegen.zig` | Codegen emit functions | 18 |
| `src/codegen/welder.zig` | Weld engine references | 8 |
| `src/compiler/alkac.zig` | Compiler returns Drop | 2 |
| `src/executor/alka_run.zig` | Executor packed struct | 12 |
| `src/executor/mock_executor.zig` | Mock simulator refs | 3 |
| `src/main.zig` | CLI `@sizeOf` refs | 4 |
| `tests/all.zig` | Unit test refs | 4 |
| `src/athanor/vitriol_alka.h` | Kernel header struct + macro | 7 |
| `src/athanor/vitriol_alka_core.h` | Core header extern decls | 41 |
| `src/athanor/vitriol_alka_ops.c` | Op handlers function sigs | 41 |
| `src/athanor/vitriol_alka_ioctls.c` | IOCTL dispatch locals | 15 |
| `src/athanor/vitriol_alka_legacy.c` | Legacy handlers (largest file) | 90 |
| `src/tools/vitriol_alka.h` | Tools copy of kernel header | 7 |
| `src/spark/vitriol_tool_ffi.h` | FFI bridge typedef | 8 |
| `src/spark/vitriol-tool.ads` | SPARK spec type def | 4 |
| `src/spark/tool-shift.adb` | SHIFT tool param type | 2 |
| `src/spark/tool-refract.adb` | REFRACT tool param type | 2 |

~309 occurrences total. No ABI change — the 32-byte packed struct is identical under the new name.

---

## Phase 1: SPARK Tool Completion

### Rationale

The Tier 1 tools (FLOW, SHIFT, FENCE, SIGNAL) must be verifiably 100% functional on every
proposed architecture. SPARK Ada provides parametric proofs that hold for *all* valid inputs,
not just the specific values in a given `.alkavl`. This is the core of the "Lightweight SPARK"
philosophy: the developer writes Alka, the SPARK tools enforce mathematical guarantees underneath.

### Existing tools

| Tool | File | Status |
|------|------|--------|
| SHIFT (0x04) | `tool-shift.adb` | Written, verified with Z3 |
| REFRACT (0x3B) | `tool-refract.adb` | Written, verified with Z3 |

### New tools required

**FLOW (0x03) — NVMe→GPU DMA Transfer**

SPARK spec (in `tool-flow.ads`):
```
Pre:  Vial.DMA_Capable = True
      Op.Size > 0
      Op.Size <= Vial.Aperture_Max
      Op.Src_Addr + Op.Size <= NVMe_capacity
      Op.Dst_Addr + Op.Size <= VRAM_capacity
Post: Result.Bytes_Transferred = Op.Size
      Metapage incremented on completion
```

SPARK body (in `tool-flow.adb`):
- Validate function checks all pre-conditions
- Execute function performs the DMA transfer
- Loop invariant for chunked transfers (when size > MAX_WINDOW)

**FENCE (0x05) — Metapage Completion Poll**

SPARK spec (in `tool-fence.ads`):
```
Pre:  Timeout > 0
Post: (if SUCCESS) Metapage reached expected value
      Cycles_Spent <= Timeout
```

SPARK body (in `tool-fence.adb`):
- Validate checks timeout is positive
- Execute polls metapage register with bounded loop
- Loop variant ensures termination (counts down from timeout)

**SIGNAL (0x09) — GPU Compute Trigger**

SPARK spec (in `tool-signal.ads`):
```
Pre:  All prior FLOWs completed (FENCE'd)
      GPU is in ready state
Post: GPU acknowledged the signal
      Compute kernel launched on GPU
```

SPARK body (in `tool-signal.adb`):
- Validate checks GPU readiness
- Execute writes doorbell register
- Post-condition verified by metapage response

### Existing tool updates

- `tool-shift.adb`, `tool-refract.adb` — rename `Metrod_Packet` → `Drop_Type`
- Add chunk-count loop invariants to REFRACT if missing
- Verify all tools with Z3 via `verify_spark_tools.py`

### Build integration

```
zig build --prove-tools
  ├── gnatprove -P src/spark/vitriol_tools.gpr   (parametric — all valid inputs)
  └── python3 src/spark/verify_spark_tools.py     (concrete — against Vial)
```

Output: `src/spark/obj/*.o` ready for linking by Zig compiler.

---

## Phase 2: Atomic Binary Output

### Rationale

Alka recipes compile to `.alkas` (Drop array) + `.azoth` (rollback). But other languages
cannot call these directly. By emitting shared libraries (`.so`/`.dll`) with a C-ABI surface,
any language — Python, Rust, C#, Go, Node.js — can invoke Alka hardware operations as if they
were standard library calls.

This is the "Hardware Microservice" pattern: developers get a folder of pre-compiled `.so` files
(`tensor_stream.so`, `nvme_to_ram.so`, `bvh_accelerator.so`) and call them without understanding
VFIO, PCIe BARs, or DMA allocation.

### CLI flags

```
alka build <recipe>.alka                  # → .alkas + .azoth (current)
alka build --shared <recipe>.alka         # → + .so (Linux) / .dll (Windows)
alka build --object <recipe>.alka         # → + .o (static link)
alka build --static <recipe>.alka         # → + .a (static library)
```

### Exported C-ABI surface

```c
// Each recipe's .so exports these symbols:

int  drop_init(const char *vial_path);             // CLAIM + LIMIT from Vial
int  drop_flow(uint64_t src, uint64_t dst,          // single DMA transfer
               uint32_t size);
int  drop_fence(uint64_t timeout_ms);               // poll metapage
int  drop_shift(uint64_t offset);                   // remap BAR window
int  drop_signal(uint64_t signal_id);               // trigger GPU compute
void drop_shutdown(void);                           // cleanup + Azoth rollback
int  drop_execute_recipe(const char *path);          // run a full .alka file
int  drop_execute_drops(const uint8_t *drops,        // run raw Drops array
                        uint32_t count);
```

### Consumer examples

**Python:**
```python
import ctypes, numpy as np
dma = ctypes.CDLL("./nvme_to_vram.so")
dma.drop_init("gtx960_2gb.alkavl")
dma.drop_flow(ssd_offset, vram_addr, 256_000_000)
dma.drop_fence(5000)
dma.drop_shutdown()
```

**Rust:**
```rust
#[link(name = "nvme_to_vram")]
extern "C" {
    fn drop_init(vial: *const c_char) -> i32;
    fn drop_flow(src: u64, dst: u64, size: u32) -> i32;
    fn drop_fence(timeout_ms: u64) -> i32;
    fn drop_shutdown();
}
```

**C#:**
```csharp
[DllImport("nvme_to_vram.so")]
static extern int drop_init(string vial);
[DllImport("nvme_to_vram.so")]
static extern int drop_flow(ulong src, ulong dst, uint size);
[DllImport("nvme_to_vram.so")]
static extern int drop_fence(ulong timeout_ms);
```

**Implementation:** Zig's `build.zig` uses `b.addSharedLibrary()` instead of `b.addExecutable()`.
The Drops array is compiled into `.rodata`, and C-ABI wrappers call the existing
`emitDrops()` + executor path. No new kernel code needed — the `.so` communicates with
the VITRIOL kernel module via the same ioctl interface.

---

## Phase 3: Embed Architecture (.alkar)

### Rationale

For cybersec applications, an Alka recipe should be embeddable inside a host binary (`.exe`,
`.dll`, `.png`, ELF binary, etc.) such that its presence is invisible to casual inspection.
The host binary looks mundane — sentinel software scans its imports and sees nothing suspicious
because the actual hardware operations are encrypted Drops hidden in padding sections.

The architecture produces three artifacts:

```
alka embed producer.alka game.exe
  ├── game.exe                  (host binary — encrypted Drops in padding)
  ├── game.exe.alkar            (residue file — map + keys + Vial)
  └── loader.alkas              (optional — compiled Drop executor)
```

The residfe file (.alkar) is always separate from the host. This creates a two-binary
architecture: one binary carries the payload invisibly, the other knows how to find
and decrypt it.

### The .alkar format

The residue file is an extended Vial that describes not just the hardware but also
where the encrypted Drops live inside the host:

```
Vial RESIDUE {
    HOST_HASH: "sha256:abcd1234";

    // Hardware constraints (same as standard .alkavl)
    Aperture DATA_PLANE {
        BAR: 1;  BASE: 0xc0000000;
        SIZE: 256MB;  MAX_WINDOW: 256MB;
        TYPE: Prefetchable;
    }
    Thermal LIMIT {
        HALT_AT: 98000;  THROTTLE_AT: 90000;
    }

    // Embed regions — where the encrypted Drops are in the host
    Embed ALKAS {
        OFFSET: 0x4C00;  SIZE: 32768;
        CIPHER: "aes-256-gcm";  IV: "base64...";
    }
    Embed AZOTH {
        OFFSET: 0x8E00;  SIZE: 1024;
        CIPHER: "aes-256-gcm";  IV: "base64...";
    }

    // Decryption key
    KEY: "base64...";
}
```

### Embed methods by host format

| Method | Host file | How Drops are hidden |
|--------|-----------|----------------------|
| PE slack | `.exe`, `.dll` | Written into DOS stub + section alignment gaps (512B–4KB per section). Undetectable by tools like `dumpbin`. |
| ELF overlay | Linux binaries | Appended after `e_shoff`. Invisible to `strip`, `readelf -S`, `objcopy`. Parsed via `e_shnum`. |
| PNG chunk | `.png` images | Stored in a custom ancillary chunk (`idAT` padding or `tEXt`). Survives image resize/re-encode. |
| .moore fat binary | LLVM IR | Standard section alongside FPGA bitstream. The endgame — all assets in one file. |

### New instruction: UNPACK

`UNPACK` reads an `.alkar`, loads the encrypted Drops from the host binary, decrypts them,
and executes them. It is the glue between the two-binary architecture:

```alka
// loader.alka
REQUIRE game.exe.alkar;

CLAIM GPU;
LIMIT GPU 98000;
UNPACK game.exe;           // compiler expands to:
                           //   1. LOAD from game.exe at Embed.ALKAS.OFFSET
                           //   2. DECRYPT using Embed.ALKAS.CIPHER + KEY
                           //   3. LOAD from game.exe at Embed.AZOTH.OFFSET
                           //   4. DECRYPT using Embed.AZOTH.CIPHER + KEY
                           //   5. EXECUTE the decrypted Drops
FENCE GPU.METAPAGE 1;
SIGNAL COMPLETE;
```

The loader is a standalone Alka program that compiles to its own `.alkas`. It is not
embedded — it lives on disk freely. Only the *payload* recipe (the actual hardware ops)
is encrypted inside the host.

### Security model

- Without `game.exe.alkar`, the encrypted Drops in `game.exe` are unrecoverable.
- AES-256-GCM with a fresh key per embed. The IV and key live in `.alkar`.
- The residue file can itself be encrypted with a passphrase for additional protection.
- If the key is present in `.alkar`, the flow is: possessing both files allows extraction.
- If the key is derived from a passphrase (not stored), the `.alkar` is useless without it.

### CLI commands

```
alka embed  producer.alka game.exe                  # embed + generate .alkar
alka embed  producer.alka game.exe --loader          # + generate loader.alkas
alka embed  producer.alka game.exe --passphrase      # key derived from passphrase
alka run    game.exe                                 # find .alkar, extract, execute
alka extract game.exe                                # extract Drops from host
alka build  loader.alka --with game.exe.alkar         # build loader against residue
```

---

## Phase 4: CLI Overhaul

### Rationale

The current CLI requires a long, error-prone command:
```
sudo ./zig-out/bin/alka --safe examples/stream_960.alka.alkas examples/stream_960.alka.azoth
```

Problems:
- Full path to binary (should be on PATH)
- `--safe` flag is redundant (safe execution is the default)
- Extension soup (`.alka.alkas .alka.azoth`)
- Manual `sudo` wrapper
- `.alkavl` path inferred from `REQUIRE` but not checked

### New command tree

```
alka

  prove   <recipe>.alka              # Z3 proof against Vial
          --dump                     # print SMT-LIB2 and exit

  build   <recipe>.alka              # compile → .alkas + .azoth
          --shared                   #   + .so
          --object                   #   + .o
          --static                   #   + .a
          --dump                     # print disassembly of Drops

  run     <recipe>.alka              # prove + build + execute
  run     <host_binary>              # find .alkar, extract + execute
          --unsafe                   # skip Azoth rollback (dangerous)

  embed   <recipe>.alka <host>       # embed Drops into host
          --loader                   # also generate loader.alkas
          --passphrase               # key derived from passphrase
          --method {pe,elf,png}      # target format (auto-detect)

  extract <host_binary>              # extract embedded Drops

  scan    [pci_bdf]                  # probe hardware, show capabilities
  scan    --vial [pci_bdf]           # generate .alkavl from live hardware

  gguf    <model.gguf>               # parse GGUF header, show tensors

  tools   verify                     # run SPARK tool proof suite
```

### Implicit behaviors

- `.alkavl` path: resolved from `REQUIRE` directive in the recipe; searched in:
  1. Current directory
  2. Recipe's directory
  3. `/etc/alka/vials/` (system-wide database)
- Privilege escalation: automatic via polkit rule (installed by `make install`)
- Azoth rollback: always used in `run` unless `--unsafe` explicitly passed
- Output path: derived from recipe name (e.g., `stream_960.alka` → `stream_960.alkas`)

---

## Phase 5: Declarative Recipe Syntax

### Rationale

The current recipe syntax requires users to specify raw addresses:

```alka
REFRACT 0x0 0x20000000 0x10000000;
```

Every one of these values is deterministic from:
- The GGUF model file (tensor sizes, offsets)
- The `.alkavl` Vial (MAX_WINDOW, BAR addresses)
- The PCI bus scan (actual BAR base addresses)

The compiler should derive these automatically, so the user writes intent, not addresses.

### Syntax

**Declarative (new — compiler derives everything):**

```alka
// Minimal form — infers Vial, model, and layer
STREAM "mistral-7b.gguf" LAYER 3;

// Explicit Vial override
STREAM "mistral-7b.gguf" LAYER 3 WITH Vial GTX_960;

// Named tensor (not all layers)
STREAM "mistral-7b.gguf" TENSOR "model.layers.3.mlp.gate_proj.weight";
```

**What the compiler does at build time:**

1. Reads `REQUIRE` (or `WITH Vial`) → loads `.alkavl`
2. Probes PCI bus or uses Vial's BDF → confirms device present
3. Reads GGUF header → tensor sizes, quantization metadata, file offsets
4. For `LAYER N`: looks up the layer's weight tensors in GGUF metadata
5. Calculates chunk count → `ceil(tensor_size / MAX_WINDOW)`
6. Emits the full Drop sequence automatically

**Compiled example (what the user would have written imperatively):**

```
; Auto-generated from: STREAM "mistral-7b.gguf" LAYER 3
; Target: GTX_960 (MAX_WINDOW = 256MB)
; Tensor: model.layers.3.mlp.gate_proj.weight (488MB)

CLAIM GTX_960;
LIMIT GTX_960 98000;
REFRACT 0xA3F800 0x1E800000 0x10000000;  ; chunk 1/2
SYNC;
SHIFT 0x10000000;                         ; slide BAR window
REFRACT 0x1E03F800 0x1E800000 0x0E800000; ; chunk 2/2
SYNC;
FENCE GTX_960.METAPAGE 1;
SIGNAL LAYER_3_READY;
```

### Backwards compatibility

The imperative syntax (REFRACT, FLOW, SHIFT, etc.) continues to work exactly as before.
Declarative STREAM is syntactic sugar that the compiler expands to imperative instructions
at build time. The `--dump` flag shows the expanded form for debugging.

---

## Phase 6: Proof Automation

### Rationale

Currently, proofs are manual:
- `alka --prove` runs Z3 on recipe-level constraints (must be invoked separately)
- SPARK tool proofs via `gnatprove` are not integrated into the build
- `verify_spark_tools.py` is a manual Python invocation

They should be automatic and integrated into the build pipeline.

### Build-time proof pipeline

```
zig build --prove
  │
  ├── Phase 1: Parametric SPARK proofs
  │   ├── gnatprove -P src/spark/vitriol_tools.gpr
  │   ├── Verifies all tools for ALL valid inputs
  │   ├── Cached — only re-runs when tool source changes
  │   └── Warnings → build continues; Errors → build fails
  │
  ├── Phase 2: Concrete Z3 proofs (new tools)
  │   ├── python3 src/spark/verify_spark_tools.py
  │   ├── Verifies tool post-conditions against concrete constraints
  │   └── Same caching strategy
  │
  └── Phase 3: Build Alka compiler
      └── zig build-exe alka
```

### Recipe-time proof pipeline

```
alka prove recipe.alka
  │
  ├── Parse .alka + resolve .alkavl from REQUIRE
  ├── Generate SMT-LIB2 from recipe constraints
  │   ├── CLAIM order (no double-claim)
  │   ├── Aperture bounds (FLOW/REFRACT ≤ MAX_WINDOW)
  │   ├── Thermal (LIMIT before heat-generating ops)
  │   └── FENCE/SIGNAL pairing
  ├── Run Z3 on generated SMT-LIB2
  ├── Report:
  │   ├── PASSED — all constraints satisfied
  │   └── FAILED — counterexample with instruction index
  └── Exit code: 0 if proven, 1 if failed
```

### `alka run` pipeline

```
alka run recipe.alka
  │
  ├── prove recipe.alka (silently, unless --verbose)
  │   └── FAILED → abort with "Recipe violates safety constraints"
  │
  ├── build recipe.alka → .alkas + .azoth
  │
  ├── escalate privileges (polkit / setuid)
  │
  ├── load VITRIOL kernel module (if not loaded)
  │
  ├── execute Drops via ioctl
  │
  ├── on success: report status, exit 0
  │
  └── on failure: execute Azoth rollback, report error, exit 1
```

### Proof caching

| What is cached | Cache key | Invalidated when |
|----------------|-----------|------------------|
| SPARK tool proofs | Tool source hash | Tool source file changes |
| Z3 tool proofs | Tool source hash | Tool source file changes |
| Recipe proof | Recipe + Vial hash | Recipe or Vial changes |

The SPARK + Z3 tool proofs are parametric — they prove the tool is correct for all hardware
targets. They only need re-proving when the tool source code changes. The recipe-level proof
is fast (~100ms) and runs on every `alka run`.

---

## Phase 7: Install Target

### Rationale

The compiler should be a system tool, not a `./zig-out/bin` binary. Users should type
`alka run recipe.alka` without a path prefix.

### make install

```
make install
  ├── cp zig-out/bin/alka → /usr/local/bin/alka
  ├── mkdir -p /usr/local/lib/alka/
  ├── cp src/spark/obj/*.o → /usr/local/lib/alka/tools/
  ├── cp src/spark/*.h → /usr/local/include/alka/
  ├── cp src/athanor/vitriol_alka.ko → /lib/modules/$(uname -r)/extra/
  ├── depmod -a
  ├── mkdir -p /etc/alka/vials/
  ├── cp share/vials/*.alkavl → /etc/alka/vials/
  ├── cp share/polkit/alka.rules → /usr/share/polkit-1/rules.d/
  └── groupadd -r alka && echo "allow anyone in alka group to use /dev/vitriol*"
```

### System Vial database

Common GPUs get pre-built `.alkavl` files distributed with Alka:

```
/etc/alka/vials/
  ├── gtx960_2gb.alkavl        (PCI 10de:1401)
  ├── gtx960_4gb.alkavl        (PCI 10de:1401, 4GB variant)
  ├── gtx1070ti_8gb.alkavl     (PCI 10de:1b82)
  ├── rtx4090_24gb.alkavl      (PCI 10de:2684)
  └── default.alkavl           (generic — user fills in)
```

`REQUIRE gtx960_2gb.alkavl` searches:
1. Current directory
2. Recipe's directory
3. `/etc/alka/vials/`

### Privilege escalation

The VITRIOL kernel module creates `/dev/vitriol*` with `0660` and group `alka`.
A polkit rule allows members of the `alka` group to open the device.
`alka run` detects missing permissions and offers to escalate via `pkexec`.

No `sudo` wrapper needed in normal operation. The kernel module handles ioctl access
control.

---

## SPECv4 Compliance

This roadmap extends SPECv4 (Alka version 4) as of 2026-05-13. The following SPECv4
sections are directly referenced:

| SPECv4 Section | Roadmap Phase | Alignment |
|----------------|---------------|-----------|
| §12 Metrod Binary Format (.alkas) | Phase 0 | Renamed to Drop format |
| §13 Azoth Rollback (.azoth) | Phase 3 | Encrypted and embedded in host |
| §14 Vial Constraints (.alkavl) | Phase 1, 5 | SPARK proof source + declarative expansion |
| §15 VITRIOL Kernel Module | Phase 2, 6 | .so exports ioctl interface; proofs verify preconditions |
| §16 Proof Engine | Phase 6 | Automatic in build + run pipeline |
| §17 Tool Pipeline | Phase 1 | SPARK completion for all Tier 1 tools |
| §20 Moore Annex | Phase 3 | Embed/.alkar as delivery mechanism |
| §22 Dual-GPU Coordination | Phase 5 | Declarative STREAM targets specific Vial |

The embed architecture (.alkar, UNPACK, residue files) and atomic binary output (.so/.dll)
are new additions not present in SPECv4. They will be incorporated into SPECv5.

---

## Implementation Order

```
Now → Phase 0 (Rename — 18 source files, ~309 occurrences)
          │
          ▼
Week 1 → Phase 1 (SPARK: FLOW, FENCE, SIGNAL specs + bodies)
          │
          ▼
Week 2 → Phase 2 (Atomic binaries: .so/.dll/.o emission)
          │
          ├────────────────────┬────────────────────┐
          ▼                    ▼                    ▼
Week 3  Phase 3 (Embed        Phase 4 (CLI         Phase 5 (Declarative
         architecture:         overhaul:            syntax: STREAM,
         .alkar, UNPACK,       new command          auto-address
         embed/extract CLI)    tree)                derivation)
          │                    │                    │
          └────────────────────┴────────────────────┘
                              │
                              ▼
Week 4 → Phase 6 (Proof automation: build-time + recipe-time)
          │
          ▼
Week 5 → Phase 7 (Install target: system vials, polkit, PATH)
```

Total estimated effort: 5 weeks for complete implementation.

---

*End of roadmap. Written 2026-05-13. Based on SPECv4.*
