# The Alka Practitioner's Handbook

> How to command real hardware with Alka — a practical guide.
> 
> **Companion to**: SPECv5.md
> **Purpose**: What the SPEC does not cover — the art of applying Alka to physical devices.

---

## 1. The Domain Boundary

Alka is a language for **coordinating hardware states across the PCIe bus**. It is not a device driver, not a firmware interface, and not a general-purpose programming language. Understanding where Alka stops and you begin is essential.

### Alka Owns

| Responsibility | Examples |
|---------------|----------|
| PCIe bus access | MMIO reads/writes, BAR window mapping |
| DMA orchestration | SHIFT windows, FLOW transfers, PIPE rings |
| Ordering & barriers | SYNC (memory visibility), FENCE (completion wait) |
| State snapshots | SNAP (capture), REVERT (restore), Azoth rollback |
| Chain validation | pre/post-state tracking, side-effect accumulation |
| Formal safety | SPARK-verified tools (FLOW, SHIFT, FENCE, SIGNAL, SLICE) |

### The Programmer Owns

| Responsibility | Examples |
|---------------|----------|
| Register maps | BAR0 offset layouts, control register bitfields |
| Firmware protocols | GPU command FIFO formats, NVMe admin queue entries |
| Sequencing logic | "Write A then B then read C" for device initialization |
| Generation knowledge | Maxwell vs. Turing GPU firmware differences |
| Vial authoring | PCI IDs, BAR sizes, thermal limits, DMA capabilities |

### The Contract

The Vial (`.alkavl`) is the **boundary document**. It describes what the hardware *physically is*. You write it. Alka trusts it. The compiler validates against it. If the Vial says BAR1 is 256MB, the compiler enforces it — but only you know what the register at BAR1+0x1000 actually controls.

---

## 2. Commanding Common Hardware

### GPU (Nvidia, AMD, Intel)

GPUs expose two key MMIO regions via PCIe BARs:

**BAR0** — Control plane (16–64MB). Contains firmware interfaces, command queues, doorbell registers, and power management. This is where you trigger computation.

**BAR1** — VRAM window (typically 256MB). A sliding aperture into the GPU's full VRAM. You SHIFT this window to access different regions of VRAM, then FLOW data through it.

```
BIND GPU              // Seize from OS
SHIFT .BAR0           // Map control registers

// Load weights into VRAM via sliding window
SHIFT .BAR1 0 256MB
FLOW NVME => .VRAM 0 256MB     // First chunk
SHIFT .BAR1 256MB 256MB
FLOW NVME => .VRAM 256MB 256MB  // Second chunk

// Trigger compute via firmware channel in BAR0
POKE .BAR0 0x1000 <command_fifo_entry> 1
FENCE .BAR0.STATUS == 0          // Wait for completion
FLUX                                // Flush caches
```

**Known issue**: Nvidia GPUs resist BIND because the proprietary driver fights for control. Use `BIND!` (force flag) to override. If the driver re-attaches, `CLAIM!` reclaims.

### CPU (x86 via Chipset)

Modern x86 CPUs expose control interfaces through the chipset's PCIe endpoints:

- **APIC** — Interrupt controller MMIO. POKE the APIC's ICR register to send inter-processor interrupts (IPIs) between cores.
- **MSI** — Message Signaled Interrupts. Configure MSI addresses via POKE to BAR0 of PCIe devices.
- **IOAPIC** — I/O APIC redirection table. Route hardware interrupts to specific cores.
- **PCIE_ROOT_COMPLEX** — Root port configuration. Control link speed, ASPM, and lane widths.

```
// Send IPI to core 3 via APIC
POKE 0xFEE00000 0x00000300 1     // ICR low: destination core 3
POKE 0xFEE00310 0x00004000 1     // ICR high: fixed delivery, assert

// Configure MSI for a device
POKE .BAR0 0x100 <msi_address> 1 // MSI capability: address
POKE .BAR0 0x104 <msi_data> 1    // MSI capability: data
```

**Note**: CPU MMIO addresses are platform-specific. Your Vial must document the chipset's MMIO base addresses.

### Fans (via Super I/O / Embedded Controller)

Motherboard fan controllers are typically behind the LPC bus, exposed through the Super I/O chip's PCI interface. The chipset's LPC bridge provides MMIO windows to the Super I/O's register space.

```
// Find LPC bridge in Vial
SHIFT .LPC_BRIDGE 0 64           // Map LPC bridge MMIO

// Write to Super I/O PWM register through bridge
POKE .LPC_BRIDGE.PWM 0x40 1      // 40% duty cycle on fan header 0
```

**Known caveat**: Super I/O chips vary wildly between motherboards. Some require unlocking sequences (write 0x87 0x87 to 0x2E) before accepting configuration. This sequence can be expressed as POKE instructions in your recipe.

### Audio (USB via xHCI Controller)

USB audio devices are controlled through the xHCI (USB 3.0) host controller, which appears as a PCI device. Audio data flows through USB transfer descriptors that you write to the xHCI's MMIO register ring.

```
// Access xHCI controller
CLAIM XHCI
SHIFT .XHCI_BAR0 0 4096

// Prepare USB transfer descriptor for audio playback
POKE .XHCI.TR_RING <td_buffer_addr> 1  // Transfer data buffer
POKE .XHCI.TR_RING+8 <td_size_cycle> 1  // Size + cycle bit
POKE .XHCI.DOORBELL <endpoint_id> 1     // Ring doorbell to submit
FENCE .XHCI.PORTSC == <completed>        // Wait for completion
```

**Practical reality**: USB audio is complex — you need to understand xHCI transfer rings, endpoint contexts, and isochronous scheduling. For most use cases, VITRIOL handles this. Write Alka recipes that POKE the high-level patterns VITRIOL exposes.

### NVMe SSD

NVMe drives expose a simplified register set through PCIe BAR0. The submission and completion queues are memory-based (not MMIO). You POKE the doorbell register to notify the drive of new submissions.

```
CLAIM NVME
SHIFT .BAR0 0 8192

// Write to submission queue in host memory
POKE .SQ0_ENTRY <command_dword0> 1
POKE .SQ0_ENTRY+4 <command_dword1> 1
// ... 14 more dwords for a full NVMe command

// Ring the doorbell to submit
POKE .BAR0.SQ0_DB <new_tail> 1

// Poll completion queue head pointer
FENCE .BAR0.CQ0_HEAD == <expected_value>
```

### NIC (Network Interface Card)

NICs typically use descriptor ring DMA. The host writes packet descriptors into host memory, then POKEs a doorbell register to notify the NIC. The NIC DMAs the packet data directly.

```
CLAIM NIC
SHIFT .BAR0 0 4096

// Set up TX descriptor in host/pinned memory
POKE .TX_RING_TAIL <descriptor_addr> 1
FLOW HOST_MEM => .NIC_DMA 0 <packet_size>
POKE .BAR0.TX_DOORBELL 1 1

// Wait for TX completion
FENCE .BAR0.TX_COMPLETE == 1
```

### FPGA (via PCIe)

FPGAs with PCIe endpoints expose configuration space (usually BAR0) and data channels (BAR1+). Dynamic reconfiguration uses INJECT:

```
CLAIM FPGA

// Configure partial reconfiguration region
INJECT .CONFIG_TILE <bitstream_addr> 1

// Map data channel for runtime communication
SHIFT .DATA_CHANNEL 0 1MB

// Stream data through the AXI bridge
FLOW HOST => .DATA_CHANNEL 0 1MB
FENCE .DATA_CHANNEL.DONE == 1
```

---

## 3. Traversal Patterns

### I2C / SPI Behind a PCI Bridge

Many sensors and embedded controllers sit behind I2C or SPI buses that are connected through a PCIe-to-I2C/SPI bridge (common on server motherboards). You cannot talk to these devices directly — you must POKE the bridge's MMIO registers to bit-bang the bus protocol.

```
// Map the bridge's MMIO window
SHIFT .I2C_BRIDGE 0 256

// Write I2C start condition + device address to bridge registers
POKE .I2C_BRIDGE.CONTROL 0x01 1        // Start bit
POKE .I2C_BRIDGE.DATA <dev_addr << 1> 1 // 7-bit address + write bit
POKE .I2C_BRIDGE.CONTROL 0x03 1        // Execute transaction
FENCE .I2C_BRIDGE.STATUS == 0x02       // ACK received

// Read response
POKE .I2C_BRIDGE.CONTROL 0x05 1        // Repeated start + read
POKE .I2C_BRIDGE.DATA <dev_addr << 1 | 1> 1  // Address + read bit
POKE .I2C_BRIDGE.CONTROL 0x03 1
FENCE .I2C_BRIDGE.STATUS == 0x02
ECHO .I2C_BRIDGE.DATA                 // Read data
```

### Legacy Device (LPC / ISA)

Older hardware (serial ports, parallel ports, PS/2 controllers) sits on the LPC bus, which is typically bridged through the PCH (Platform Controller Hub) or chipset. The PCH exposes LPC MMIO windows through its PCI configuration space.

```
// Enable LPC bridge MMIO
SHIFT .LPC_BRIDGE 0 4096

// Access legacy serial port behind LPC
POKE .LPC_BRIDGE.UART_BASE 0x3F8 1    // COM1 base address
POKE 0x3F8 0x41 1                      // Write 'A' to UART data register
```

**Crucial**: The LPC bridge must have its MMIO decoding enabled in PCI config space. This is typically done during boot by the BIOS/firmware. If not, you may need to POKE the bridge's PCI config registers first — but this can conflict with the OS.

### PCIe Switch

If your system has a PCIe switch (common with multiple GPUs), you may need to configure its upstream/downstream ports. Switch configuration registers are accessed through the switch's PCI configuration space.

```
// Enumerate downstream ports via switch config
POKE .SWITCH.CAP 0x01 1                // Access port capabilities
ECHO .SWITCH.LINK_STATUS               // Read link status
POKE .SWITCH.LINK_CONTROL 0x01 1       // Enable extended tags
```

---

## 4. Safety Patterns

### The Thermal Interlock

Before any heat-generating operation (POKE, FLOW, SLICE), check temperature:

```
// Safe POKE pattern
SENSE .GPU.THERMAL
GUARD .GPU.THERMAL > 85 RESET          // Auto-reset if overheating
POKE 0x1000 0xAAAAAAAA 10000           // The actual operation
AUDIT                                    // Verify no damage
```

### The SNAP-REVERT Rollback

Before any destructive operation, snapshot the current state:

```
// Destructive op with rollback
SNAP .GPU.REGISTERS                     // Save current register state
POKE 0x2000 0x0 1                       // Dangerous write
FENCE .GPU.STATUS == OK ? REVERT : SYNC // Rollback on failure
```

### The `!!` Override

Use `!!` when you have externally validated a sequence that the compiler cannot verify. This is common when:

- **Sequencing hardware init** — the datasheet says "write A, wait 10ms, write B" but the Vial doesn't encode timing dependencies
- **Bypassing aperture limits** — you know the hardware supports larger windows despite the Vial's reported MAX_WINDOW
- **Pre-configured hardware** — firmware or UEFI already set up the state

```
BIND GPU
SHIFT .BAR1 0 256MB
!!  // Hardware pre-configured by VBIOS, skip chain validation
SLICE .VRAM 0 512MB 256MB
```

### DMA Direction Convention

FLOW takes `source => destination`. This is always from the perspective of the **initiating vessel** (the one that was CLAIM'd):

```
// From GPU's perspective, pull from NVMe
BIND GPU
FLOW NVME => .VRAM 0 256MB    // GPU pulls data from NVMe into VRAM

// From NVMe's perspective, push to GPU
BIND NVME
FLOW NVME => GPU 0 256MB      // NVMe pushes data to GPU VRAM
```

---

## 5. Common Pitfalls

### BAR Window Misalignment

**Problem**: SHIFT with an unaligned offset fails silently — the hardware rounds down to the nearest page boundary, corrupting adjacent data.

**Fix**: Always align to the Vial's page size:
```
SHIFT .BAR1 0x001000 256MB    // Wrong: 0x001000 may not be page-aligned
SHIFT .BAR1 0 256MB            // Correct: start at page boundary
SHIFT .BAR1 0x100000 256MB     // Correct: 1MB = page-aligned
```

### MMIO Reordering

**Problem**: POKE writes may be reordered by the CPU/PCIe fabric. The write might not reach the device before the next instruction executes.

**Fix**: Insert SYNC between dependent POKE writes, or use FENCE to wait for a device-side acknowledgment:
```
POKE .CTRL 0x01 1               // Set init bit
SYNC                              // Ensure write reaches device
POKE .DATA 0xFF 1                // Now safe to write data
```

### Dead Device After Failed Operation

**Problem**: A POKE or FLOW hung the device. The OS reports the device as "dead" and you can't recover.

**Fix**: Force re-claim + reset:
```
CLAIM! GPU                        // Force reclaim despite stale state
RESET GPU                         // Reset subsystem to known state
VERIFY GPU.STATUS == OK           // Verify recovery
```

### Device Doesn't Appear in PCI Scan

**Problem**: You ran `alka --probe-all` and the device isn't listed. It may be behind an I2C/SPI bridge, or disabled in firmware.

**Fix**: Check if `lspci` shows it. If yes, verify the Vial has the correct PCI ID. If no, the device may need:
- A PCIe hotplug reset
- Firmware reconfiguration
- I2C/SPI bridge traversal (see §3)

### GPU Rejects BIND

**Problem**: BIND GPU fails because the Nvidia driver re-asserts control.

**Fix**: Use `BIND!` force flag, which signals VITRIOL to be more aggressive with the unbind sequence:
```
BIND! GPU                         // Force unbind: retry + ACS override
```

If BIND still fails, the system may need:
- The Nvidia driver unloaded (`rmmod nvidia_uvm nvidia_drm nvidia_modeset nvidia`)
- Or the module blacklisted before startup

---

## A. Quick Reference

### Tool Selection by Goal

| Goal | Tool Chain | Why |
|------|------------|-----|
| Move data | `CLAIM → SHIFT → FLOW → FENCE` | DMA with aperture management |
| Trigger compute | `CLAIM → POKE → FENCE` | Write firmware command, wait for completion |
| Save state | `CLAIM → SNAP` | Snapshot for later rollback |
| Restore state | `CLAIM → REVERT → VERIFY` | Rollback on failure |
| Reset device | `CLAIM → SNAP → RESET → VERIFY` | Safe reset with recovery |
| Isolate device | `BIND → CLAIM → ISOLATE → GUARD` | Full OS access revocation |
| Multi-device | `CLAIM A → CLAIM B → COORDINATE` | Synchronize two devices |
| Ring buffer | `CLAIM → SHIFT → PIPE → WATCH` | Continuous autonomous DMA |

### Vial-Aware Operand Reference

| Syntax | Resolves To | Example |
|--------|-------------|---------|
| `VESSEL_NAME` | Vessel by name from Vial | `GTX_960`, `NVME_SSD` |
| `.MEMBER` | Active vessel's member | `.BAR1`, `.VRAM`, `.STATUS` |
| `VESSEL.MEMBER` | Specific vessel's member | `GPU.BAR0`, `NVME.SQ0` |
| `0x...` | Hex literal | `0x10000000` |
| `NUMBER` | Decimal literal | `256MB`, `512MB`, `10000` |
