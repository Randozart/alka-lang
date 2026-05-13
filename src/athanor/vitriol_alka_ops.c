/*
 * vitriol_alka_ops.c — Opcode Implementations for VITRIOL
 *
 * All 39 implemented opcode handlers. Critical path ops (CLAIM, FLOW,
 * SHIFT, FENCE, SYNC) have real hardware interaction. Others are
 * stubs with proper logging for future implementation.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/pci.h>
#include <linux/delay.h>
#include <linux/io.h>
#include <linux/device.h>
#include <linux/sysfs.h>

#include "vitriol_alka.h"
#include "vitriol_alka_core.h"

/* ============================================================================
 * CLAIM (0x01) — Unbind kernel driver, claim GPU
 *
 * This is the first instruction in any Recipe. It:
 * 1. Finds the GPU by PCI vendor/device ID
 * 2. Unbinds it from the current driver (nouveau/nvidia)
 * 3. Enables bus mastering
 * 4. Maps BAR0 (control) and BAR1 (data/VRAM window)
 *
 * Real driver unbinding uses device_release_driver() via sysfs.
 * ============================================================================ */

int op_claim(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 vendor = pkt->src_addr & 0xFFFF;
    u16 device = (pkt->src_addr >> 16) & 0xFFFF;

    pr_info("VITRIOL: CLAIM vendor=%04x device=%04x\n", vendor, device);

    /* Get PCI device reference for config space access (no unbind needed) */
    if (vendor && device && !vdev->pdev) {
        vdev->pdev = pci_get_device(vendor, device, NULL);
        if (vdev->pdev)
            pr_info("VITRIOL: PCI device found, bound to %s\n",
                    vdev->pdev->driver ? vdev->pdev->driver->name : "none");
    }

    /* Map BAR0 (Control Plane) via ioremap — no unbinding needed.
     * The nvidia driver can keep its binding; we share the silicon.
     * Known addresses from Vial:
     * GTX 960: BAR0=0xf4000000 (16MB), BAR1=0xc0000000 (256MB)
     */
    if (!vdev->bar0_base) {
        resource_size_t bar0_phys, bar0_len;

        if (vendor == 0x10de && device == 0x1401) {
            bar0_phys = 0xf4000000;
            bar0_len = 16 * 1024 * 1024;
        } else if (vdev->pdev) {
            bar0_phys = pci_resource_start(vdev->pdev, 0);
            bar0_len = pci_resource_len(vdev->pdev, 0);
        } else {
            bar0_phys = 0xe0000000;
            bar0_len = 16 * 1024 * 1024;
        }

        request_mem_region(bar0_phys, bar0_len, "vitriol_alka");
        vdev->bar0_base = ioremap(bar0_phys, bar0_len);
        if (!vdev->bar0_base) {
            pr_err("VITRIOL: Failed to ioremap BAR0 at %llx\n", bar0_phys);
            return -ENOMEM;
        }
        vdev->bar0_phys = bar0_phys;
        vdev->bar0_len = bar0_len;
        pr_info("VITRIOL: BAR0 ioremap'd at %px (phys=%llx, len=%llu)\n",
                vdev->bar0_base, bar0_phys, bar0_len);
    }

    /* Map BAR1 (Data Plane — VRAM window).
     * nvidia may have already reserved this range via PAT.
     * For DMA we only need the physical address — the mapping is a bonus.
     */
    if (!vdev->bar1_base) {
        resource_size_t bar1_phys, bar1_len;

        if (vendor == 0x10de && device == 0x1401) {
            bar1_phys = 0xc0000000;
            bar1_len = 256 * 1024 * 1024;
        } else if (vdev->pdev) {
            bar1_phys = pci_resource_start(vdev->pdev, 1);
            bar1_len = pci_resource_len(vdev->pdev, 1);
        } else {
            bar1_phys = 0xea000000;
            bar1_len = 256 * 1024 * 1024;
        }

        vdev->bar1_phys = bar1_phys;
        vdev->bar1_len = bar1_len;

        request_mem_region(bar1_phys, bar1_len, "vitriol_alka");
        vdev->bar1_base = ioremap_wc(bar1_phys, bar1_len);
        if (!vdev->bar1_base && vdev->pdev) {
            pr_warn("VITRIOL: ioremap_wc failed, trying pci_iomap_wc\n");
            vdev->bar1_base = pci_iomap_wc(vdev->pdev, 1, 0);
        }
        if (vdev->bar1_base) {
            pr_info("VITRIOL: BAR1 mapped at %px (phys=%llx, len=%llu)\n",
                    vdev->bar1_base, bar1_phys, bar1_len);
        } else {
            pr_warn("VITRIOL: BAR1 not mappable (nvidia owns WC range), using phys=%llx for DMA\n",
                    bar1_phys);
        }
    }

    vdev->bar1_offset = 0;
    vdev->initialized = true;

    pr_info("VITRIOL: GPU claimed — nvidia untouched, silicon shared\n");
    return 0;
}

/* ============================================================================
 * FLOW (0x03) — DMA transfer (the Moore Stream workhorse)
 *
 * Transfers data from source to destination. For NVMe→GPU streaming:
 * - src = file offset on NVMe (handled by userspace opening the file)
 * - dst = GPU VRAM offset
 * - size = transfer size
 *
 * Uses the 4MB bounce buffer with sliding window for transfers > 256MB.
 * ============================================================================ */

int op_flow(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 src = pkt->src_addr;
    u64 dst = pkt->dst_addr;
    u32 size = pkt->size;
    int ret;

    pr_info("VITRIOL: FLOW src=%llx dst=%llx size=%u\n", src, dst, size);

    ret = vitriol_check_thermal(vdev);
    if (ret)
        return ret;

    if (!vdev->initialized) {
        pr_err("VITRIOL: FLOW before CLAIM\n");
        return -ENODEV;
    }

    /* Perform the DMA transfer via bounce buffer */
    ret = vitriol_dma_transfer(vdev, src, dst, size);
    if (ret) {
        pr_err("VITRIOL: FLOW failed: %d\n", ret);
        return ret;
    }

    /* Signal completion via metapage */
    vitriol_signal_metapage(vdev, pkt->vessel_id);

    return 0;
}

/* ============================================================================
 * SHIFT (0x04) — Remap BAR1 sliding window
 *
 * The GTX 1070 Ti BAR1 is only 256MB. To access all 8GB of VRAM,
 * we must shift the window. src_addr = new VRAM offset.
 * ============================================================================ */

int op_shift(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 offset = pkt->src_addr;
    int ret;

    pr_info("VITRIOL: SHIFT offset=%llx\n", offset);

    if (!vdev->initialized)
        return -ENODEV;

    ret = shift_bar1_window(vdev, offset);
    if (ret)
        return ret;

    /* Memory barrier */
    wmb();
    return 0;
}

/* ============================================================================
 * FENCE (0x05) — Wait for condition (metapage polling)
 *
 * Blocks execution until the metapage value matches expected.
 * This is the completion synchronization mechanism.
 * ============================================================================ */

int op_fence(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 expected = pkt->dst_addr;
    int timeout_ms = 5000;
    int elapsed = 0;

    pr_info("VITRIOL: FENCE expected=%llx\n", expected);

    if (!vdev->initialized)
        return -ENODEV;

    /* Poll metapage with timeout */
    while (elapsed < timeout_ms) {
        if (vdev->metapage_value == (u32)expected) {
            pr_info("VITRIOL: FENCE passed (value=%u)\n", vdev->metapage_value);
            return 0;
        }

        usleep_range(100, 200);
        elapsed++;

        if (vitriol_check_thermal(vdev))
            return -EHWPOISON;
    }

    pr_err("VITRIOL: FENCE timeout (value=%u, expected=%llu)\n",
           vdev->metapage_value, expected);
    return -ETIMEDOUT;
}

/* ============================================================================
 * SYNC (0x06) — Memory barrier
 * ============================================================================ */

int op_sync(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 level = pkt->src_addr & 0xFF;

    switch (level) {
    case 1: wmb(); break;
    case 2: rmb(); break;
    default: mb(); break;
    }

    return 0;
}

/* ============================================================================
 * SENSE (0x07) — Read sensor (thermal, power, etc.)
 * ============================================================================ */

int op_sense(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 sensor_id = pkt->src_addr & 0xFF;

    vdev->current_temp = vitriol_read_thermal(vdev);
    pr_info("VITRIOL: SENSE sensor=%u temp=%u mC (%u C)\n",
            sensor_id, vdev->current_temp, vdev->current_temp / 1000);

    return 0;
}

/* ============================================================================
 * STAKE (0x02) — Claim physical memory region
 * ============================================================================ */

int op_stake(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 phys_addr = pkt->src_addr;
    u32 size = pkt->size;

    pr_info("VITRIOL: STAKE addr=%llx size=%u\n", phys_addr, size);
    return 0;
}

/* ============================================================================
 * SNAP (0x0C) — Serialize hardware state
 * ============================================================================ */

int op_snap(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: SNAP vessel=%u\n", pkt->vessel_id);

    if (!vdev->initialized)
        return -ENODEV;

    wmb();
    return 0;
}

/* ============================================================================
 * REVERT (0x0D) — Restore previously SNAP'd state
 * ============================================================================ */

int op_revert(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: REVERT vessel=%u blob=%llu\n", pkt->vessel_id, pkt->dst_addr);

    if (!vdev->initialized)
        return -ENODEV;

    mb();
    return 0;
}

/* ============================================================================
 * LIMIT (0x0E) — Set hard contract (thermal, power)
 * ============================================================================ */

int op_limit(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 property = pkt->src_addr & 0xFF;
    u32 value = pkt->size;

    if (property == 0) {
        vdev->thermal_halt = value;
        pr_info("VITRIOL: LIMIT thermal_halt=%u mC (%u C)\n", value, value / 1000);
    }

    return 0;
}

/* ============================================================================
 * VEIL (0x0F) — Hide device from OS
 * ============================================================================ */

int op_veil(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 cmd;

    pr_info("VITRIOL: VEIL vessel=%u\n", pkt->vessel_id);

    if (!vdev->pdev)
        return -ENODEV;

    pci_read_config_word(vdev->pdev, PCI_COMMAND, &cmd);
    cmd &= ~(PCI_COMMAND_MEMORY | PCI_COMMAND_IO);
    pci_write_config_word(vdev->pdev, PCI_COMMAND, cmd);

    return 0;
}

/* ============================================================================
 * QUENCH (0x1D) — Emergency power cut
 * ============================================================================ */

int op_quench(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 pmcsr;

    pr_warn("VITRIOL: QUENCH — cutting power to device\n");

    if (!vdev->pdev)
        return -ENODEV;

    pci_read_config_word(vdev->pdev, vdev->pdev->pm_cap + PCI_PM_CTRL, &pmcsr);
    pmcsr |= 3; /* D3hot */
    pci_write_config_word(vdev->pdev, vdev->pdev->pm_cap + PCI_PM_CTRL, pmcsr);

    return 0;
}

/* ============================================================================
 * FORGE (0x1E) — FPGA partial reconfiguration
 * ============================================================================ */

int op_forge(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: FORGE vessel=%u tile=%llu\n", pkt->vessel_id, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * VOID (0x1F) — Secure erase
 * ============================================================================ */

int op_void_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: VOID addr=%llx size=%u\n", pkt->src_addr, pkt->size);
    return 0;
}

/* ============================================================================
 * ECHO (0x17) — Read without mutating
 * ============================================================================ */

int op_echo(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 value;

    if (!vdev->bar0_base)
        return -ENODEV;

    value = ioread32(vdev->bar0_base + pkt->dst_addr);
    pr_info("VITRIOL: ECHO offset=%llx value=%08x\n", pkt->dst_addr, value);

    return 0;
}

/* ============================================================================
 * AUDIT (0x2B) — Post-instruction residue check
 * ============================================================================ */

int op_audit(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 err_status;

    if (!vdev->bar0_base)
        return -ENODEV;

    err_status = ioread32(vdev->bar0_base + 0x2000);

    if (err_status != 0) {
        pr_warn("VITRIOL: AUDIT found residue: 0x%08x\n", err_status);
        return -EIO;
    }

    return 0;
}

/* ============================================================================
 * GUARD (0x31) — Runtime safety sentinel
 * ============================================================================ */

int op_guard(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 threshold = pkt->size;

    pr_info("VITRIOL: GUARD threshold=%u action=%llu\n", threshold, pkt->dst_addr);

    if (threshold > 0 && threshold < vdev->thermal_halt) {
        vdev->thermal_throttle = threshold;
    }

    return 0;
}

/* ============================================================================
 * ISOLATE (0x32) — Disconnect device from bus
 * ============================================================================ */

int op_isolate(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 cmd;

    pr_info("VITRIOL: ISOLATE vessel=%u\n", pkt->vessel_id);

    if (!vdev->pdev)
        return -ENODEV;

    pci_read_config_word(vdev->pdev, PCI_COMMAND, &cmd);
    cmd &= ~(PCI_COMMAND_MASTER | PCI_COMMAND_MEMORY | PCI_COMMAND_IO);
    pci_write_config_word(vdev->pdev, PCI_COMMAND, cmd);

    return 0;
}

/* ============================================================================
 * VERIFY (0x33) — Cryptographic state verification
 * ============================================================================ */

int op_verify(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: VERIFY vessel=%u expected_hash=%llu\n",
            pkt->vessel_id, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * WATCH (0x2F) — Real-time monitoring
 * ============================================================================ */

int op_watch(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 target = pkt->src_addr & 0xFF;
    u32 interval = pkt->size;

    pr_info("VITRIOL: WATCH target=%u interval=%ums\n", target, interval);
    return 0;
}

/* ============================================================================
 * TRACE (0x30) — Enable execution trace
 * ============================================================================ */

int op_trace(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: TRACE enabled (id=%llu)\n", pkt->src_addr);
    return 0;
}

/* ============================================================================
 * MOLT (0x14) — Full state dump
 * ============================================================================ */

int op_molt(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: MOLT vessel=%u blob=%llu\n", pkt->vessel_id, pkt->dst_addr);

    if (!vdev->initialized)
        return -ENODEV;

    return 0;
}

/* ============================================================================
 * FOSSILIZE (0x1B) — Write to Option ROM
 * ============================================================================ */

int op_fossilize(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: FOSSILIZE vessel=%u bytecode=%llu\n",
            pkt->vessel_id, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * STASIS (0x18) — PCIe bus locking
 * ============================================================================ */

int op_stasis(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: STASIS bus=%llu\n", pkt->src_addr);
    return 0;
}

/* ============================================================================
 * RHYTHM (0x11) — Hard-clock alignment
 * ============================================================================ */

int op_rhythm(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 frequency = pkt->size;

    pr_info("VITRIOL: RHYTHM node=%llu freq=%uHz\n", pkt->src_addr, frequency);
    return 0;
}

/* ============================================================================
 * PULSE (0x08) — Timing signal
 * ============================================================================ */

int op_pulse_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 pin = pkt->src_addr & 0xFF;
    u32 freq = pkt->size;

    pr_info("VITRIOL: PULSE pin=%u freq=%uHz\n", pin, freq);
    return 0;
}

/* ============================================================================
 * SIGNAL (0x09) — Hardware interrupt
 * ============================================================================ */

int op_signal_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 vector = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: SIGNAL vector=%u\n", vector);
    return 0;
}

/* ============================================================================
 * YIELD (0x0A) — Cooperative yield
 * ============================================================================ */

int op_yield_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 micros = pkt->src_addr;

    if (micros > 0)
        usleep_range(micros, micros + 100);

    return 0;
}

/* ============================================================================
 * RECAST (0x0B) — FPGA reconfiguration
 * ============================================================================ */

int op_recast(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: RECAST vessel=%u bitstream=%llu\n",
            pkt->vessel_id, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * DRY_RUN (0x2C) — Simulate only
 * ============================================================================ */

int op_dry_run(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: DRY_RUN op=0x%02x (simulated)\n", pkt->op_code);
    return 0;
}

/* ============================================================================
 * MOCK (0x2D) — Use mock hardware
 * ============================================================================ */

int op_mock(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: MOCK mock_id=%llu\n", pkt->src_addr);
    return 0;
}

/* ============================================================================
 * PROVE (0x2E) — Formal verification
 * ============================================================================ */

int op_prove(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: PROVE invariant=%llu\n", pkt->src_addr);
    return 0;
}

/* ============================================================================
 * STRIKE (0x1C) — Rowhammer/bit flipping
 * ============================================================================ */

int op_strike(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_warn("VITRIOL: STRIKE target=%llx pattern=%llu reps=%u\n",
            pkt->src_addr, pkt->dst_addr, pkt->size);
    return 0;
}

/* ============================================================================
 * FLUX (0x2A) — Cache invalidation
 * ============================================================================ */

int op_flux(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: FLUX vessel=%llu\n", pkt->src_addr);
    return 0;
}

/* ============================================================================
 * OSSIFY (0x34) — Pin CPU core
 * ============================================================================ */

int op_ossify(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 core_id = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: OSSIFY core=%u\n", core_id);
    return 0;
}

/* ============================================================================
 * BOND (0x35) — RAM-to-GPU direct tunnel
 * ============================================================================ */

int op_bond(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 ram_addr = pkt->src_addr;
    u64 gpu_addr = pkt->dst_addr;
    u32 size = pkt->size;

    pr_info("VITRIOL: BOND ram=%llx gpu=%llx size=%u\n", ram_addr, gpu_addr, size);
    return 0;
}

/* ============================================================================
 * STILL (0x36) — Manual DRAM refresh
 * ============================================================================ */

int op_still(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 bank = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: STILL bank=%u\n", bank);
    return 0;
}

/* ============================================================================
 * RESONATE (0x37) — Coordinate reset
 * ============================================================================ */

int op_resonate(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: RESONATE node_a=%llu node_b=%llu\n",
            pkt->src_addr, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * OSCILLATE (0x38) — Dual-bank refresh
 * ============================================================================ */

int op_oscillate(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: OSCILLATE bank_a=%llu bank_b=%llu\n",
            pkt->src_addr, pkt->dst_addr);
    return 0;
}

/* ============================================================================
 * IMC_HIJACK (0x39) — Direct memory controller access
 * ============================================================================ */

int op_imc_hijack(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 channel = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: IMC_HIJACK channel=%u\n", channel);
    return 0;
}

/* ============================================================================
 * OCCUPY (0x3A) — Seize PCIe device
 * ============================================================================ */

int op_occupy(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 bus = (pkt->src_addr >> 8) & 0xFF;
    u32 slot = (pkt->src_addr >> 3) & 0x1F;
    u32 func = pkt->src_addr & 0x7;

    pr_warn("VITRIOL: OCCUPY %02x:%02x.%u — severing OS access\n",
            bus, slot, func);

    if (vdev->pdev) {
        pci_clear_master(vdev->pdev);
        pci_disable_device(vdev->pdev);
    }

    return 0;
}
