# Alka v3→v4 — Findings & Failings

## What Worked

### Architecture
- **Compiler pipeline**: Source → Parse → Validate → Emit → Refine → Binary. All stages function correctly.
- **Mock executor (`--mock`)**: Fully validates recipes without touching hardware. Caught struct layout mismatch before it could cause kernel issues.
- **Azoth rollback**: Auto-generated inverse operations executed on failure. Every failed kernel ioctl was safely rolled back.

### Hardware Access
- **`ioremap` without unbinding**: Successfully mapped BAR0 on the GTX 960 while nvidia retained ownership. No driver conflict for control registers.
- **Known BAR addresses**: Hardcoding BAR0=0xf4000000, BAR1=0xc0000000 from the Vial worked correctly. PCI config space reads confirmed these addresses.

### Instructions
- **CLAIM (0x01)**: Finds GPU via `pci_get_device()`, maps BARs via `ioremap`, stays alive even with nvidia bound.
- **REFRACT (0x3B)**: Chunks 512MB into 2×256MB drops. DMA transfer loop completes correctly.
- **FENCE (0x05)**: Software metapage polling works at 100μs granularity with 5s timeout.
- **PIPE (0x3C)**: Defined in spec, tool implemented, kernel stub ready.

### nvidia Coexistence
- Module loads with nvidia still bound.
- CLAIM maps BAR0 while nvidia owns the device.
- No kernel panic, no Oops, no driver crash.

## What Failed

### 1. nvidia TEE Mutex Deadlock
**Symptom**: `device_release_driver()` → nvidia's `nv_pci_remove()` calls `os_delay()` → blocks on TEE mutex → kernel thread hangs → `rmmod` stuck with "in use".

**Root Cause**: nvidia's `nv_pci_remove()` acquires a TEE (Trusted Execution Environment) mutex that is held by another thread during driver lifecycle. Calling `device_release_driver()` from an ioctl context creates a mutex inversion that the TEE subsystem cannot resolve.

**Resolution**: Never call `device_release_driver()`. Use `ioremap()` on known physical addresses instead of `pci_iomap()`. The nvidia driver can keep its binding; we access the hardware through the same MMIO windows.

### 2. PAT Memory Type Conflict
**Symptom**: `ioremap_wc(0xc0000000)` fails with `-16` and `x86/PAT: conflicting memory types write-combining<->uncached-minus`.

**Root Cause**: nvidia's driver has already reserved the physical range `[0xc0000000-0xcfffffff]` as Write-Combining via the PAT (Page Attribute Table). The Linux kernel's PAT subsystem enforces exclusive memory type reservations per physical page. Once nvidia claims a range with WC, no other driver can claim the same range — even with an identical WC request.

**Resolution**: Made BAR1 mapping non-fatal. The kernel module stores the physical address for DMA use even when `ioremap` fails. For future work, use `/dev/mem` from userspace for direct VRAM access, or implement a shared mapping protocol with nvidia.

### 3. Metapage Software/Hardware Disconnect
**Symptom**: `vitriol_signal_metapage()` wrote to a DMA buffer pointer (`vdev->metapage[0]`) while `op_fence()` polled a separate `u32` field (`vdev->metapage_value`).

**Root Cause**: The original design had two distinct metapage paths — one for kernel DMA completion signaling (hardware polling) and one for the FENCE instruction (software polling). They were never wired together.

**Resolution**: `vitriol_signal_metapage()` now updates both `vdev->metapage_value` and `vdev->metapage[0]`, bridging the software/hardware fence gap.

### 4. Vial Vessel Name Resolution
**Symptom**: `CLAIM GTX_960` emitted `src_addr=0` instead of the PCI vendor/device ID.

**Root Cause**: `emitPacket()` ignored the Vial parameter and evaluated the vessel name operand as a raw number, which defaulted to 0.

**Resolution**: Added per-instruction vessel name resolution in `emitPacket()` — CLAIM, LIMIT, FENCE, and SIGNAL now look up vessel identifiers in the Vial and encode the correct PCI IDs or hash values.

### 5. Packed vs Extern Struct Layout
**Symptom**: 224-byte binary file (7×32 bytes) rejected with `InvalidBinary` by the executor.

**Root Cause**: The compiler emits `packed struct` (32 bytes, zero padding) while the executor read `extern struct` (40 bytes, C ABI adds 4 bytes of padding after `vessel_id` to align `u64` fields). 224÷40 ≠ integer.

**Resolution**: Changed executor's `MetrodPacket` to `packed struct` to match the compiler and kernel header's `__attribute__((packed))`.

### 6. Legacy File Build Conflict
**Symptom**: Kernel module link errors: `op_refract` and `op_pipe` undefined.

**Root Cause**: The old monolithic `vitriol_alka.c` still existed alongside the split files. The Kbuild found the `.c` file matching the module name and compiled it alone, ignoring the `vitriol_alka-y` multi-file declaration.

**Resolution**: Renamed `vitriol_alka.c` → `vitriol_alka_legacy.c`. The Kbuild now correctly compiles the five split source files.

### 7. Kernel Module Unload Blocked
**Symptom**: After a failed ioctl (e.g., nvidia deadlock), `rmmod vitriol_alka` returns "Module is in use" even after killing all user processes.

**Root Cause**: The kernel's module reference count was incremented by the open file descriptor or a pending ioctl that never completed. The nvidia TEE deadlock left the ioctl in `D` state, holding the reference.

**Resolution**: Only fixable via reboot when nvidia TEE is involved. For non-TEE failures: `fuser -k /dev/vitriol` + `rmmod`.

## Key Insights

1. **nvidia is hostile to co-ownership**: The TEE mutex deadlock and PAT exclusivity are not bugs — they are architectural decisions that prevent any other driver from touching "their" hardware. Alka's approach of `ioremap`-ing over nvidia is fragile on BAR1 but works for BAR0.

2. **PAT is the real gatekeeper**: Even without unbinding, the PAT prevents shared WC mappings. The kernel allows only one driver to map a physical range with a given caching type. This is a fundamental Linux MM limitation.

3. **Metapage design must unify**: Having separate software and hardware fence paths created a bug that took hours to debug. Any future metapage implementation must use a single value.

4. **The Vial must be the source of truth for addresses**: Hardcoding BAR addresses per GPU model is a short-term hack. The Vial already stores these addresses; the compiler must fully resolve them.

5. **Mock execution saves hardware**: The struct layout bug was caught by mock before hitting the kernel. The REFRACT logic was validated by mock before the first hardware test. `--mock` should always be run first.

---

## Phase 0 — Metrod → Drop Rename — 2026-05-13

### Successes
- **Complete rename across 27 source files**, ~309 occurrences
- **Zero ABI breakage** — same 32-byte packed struct under a new name
- **Build passes cleanly** with `zig build` — zero warnings
- **Proof engine unaffected** — `alka --prove stream_960.alka gtx960_2gb.alkavl` still passes
- **Version control clean** — 4 incremental commits with clear boundaries

### Failures (None)
The rename was purely cosmetic with no functional changes. No regressions introduced.

### Struggles
1. **sed pattern ordering** — The C files required careful pattern ordering to avoid over-matching.
   - `METROD_PACKET_SIZE` had to be replaced before `METROD_PACKET_EXT_SIZE` to prevent the shorter pattern from matching a substring of the longer one.
   - `s/METROD/Alka/g` was too aggressive for the last pass (risked renaming unrelated macros), so it was limited to comment-only files.

2. **`error` is a Zig 0.14 keyword** — The `ProofResult` union had a variant named `.error` which is a reserved keyword in Zig 0.14's error set system. Had to rename to `.err_msg`. This was discovered during the proof engine debug, not the rename itself, but it's a related compatibility finding.

3. **C struct name collision** — The kernel's `struct metrod_packet` used `metrod_packet` as both the struct tag and the type name (via typedef). Had to ensure both were caught by separate sed patterns.

### Insights
1. **Mapping table approach is essential** — For bulk renames, a declarative old→new mapping table is much safer than ad-hoc sed. Protects against over-matching and missing edge cases.

2. **Incremental commits with build verification** — Committing after each logical group of files (Zig core, executor, C kernel, SPARK) with a build test in between caught one issue (test file still used `emitMetrod`) before it became a problem.

3. **The rename surfaced terminology debt** — "Metrod" was never the right name for this concept. The term was inherited from an early prototype where the packet format was borrowed or inspired by the user's separate Metrod project (language cross-communication). The new name "Drop" is theologically consistent with the Alchemical Mirror theme (.alkas = Alka Sol, each packet = a Drop of the Sol).
