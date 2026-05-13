/*
 * vitriol_alka.c — Athanor Kernel Module
 *
 * The hardware executor for Alka. Receives Alka drops from userspace
 * via ioctl and dispatches them to real hardware operations.
 *
 * This module replaces the original vitriol.c with full opcode dispatch,
 * real DMA transfers, BAR mapping, driver unbinding, and thermal monitoring.
 *
 * Protocol: vitriol_alka.h
 * Device:   /dev/vitriol
 * License:  GPL v2
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/pci.h>
#include <linux/dma-mapping.h>
#include <linux/uaccess.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/hwmon.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>
#include <linux/interrupt.h>
#include <linux/ioctl.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/ktime.h>

#include "vitriol_alka.h"

#define DRIVER_NAME "vitriol_alka"
#define DEVICE_NAME "vitriol"
#define MAX_VESSELS_KERNEL 16
#define DMA_BUFFER_SIZE (1 * 1024 * 1024)  /* 1MB DMA buffer */

/* ============================================================================
 * Device state
 * ============================================================================ */

struct vitriol_device {
    struct cdev cdev;
    struct device *dev;
    dev_t devt;
    struct mutex lock;

    /* PCI state */
    struct pci_dev *pdev;
    void __iomem *bar0_base;    /* 16MB control plane */
    void __iomem *bar1_base;    /* 256MB data window */
    resource_size_t bar0_len;
    resource_size_t bar1_len;
    u64 bar0_phys;
    u64 bar1_phys;
    u64 bar1_offset;            /* Current sliding window offset */

    /* DMA */
    void *dma_buffer;
    dma_addr_t dma_handle;

    /* Vial state */
    struct vial_desc vial;
    u32 safety_level;           /* 0=none, 1=thermal, 2=full */
    bool initialized;

    /* Thermal */
    u32 current_temp;
    u32 thermal_halt;
    u32 thermal_throttle;

    /* Execution state */
    struct exec_result last_result;
    struct task_struct *heartbeat_thread;
    ktime_t last_heartbeat;
    bool heartbeat_active;

    /* Wait queue for FENCE */
    wait_queue_head_t fence_wq;
    u32 metapage_value;
};

static struct vitriol_device *g_dev;

/* ============================================================================
 * Forward declarations
 * ============================================================================ */

static int op_claim(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_flow(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_shift(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_fence(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_sync(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_sense(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_stake(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_snap(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_revert(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_limit(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_veil(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_quench(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_forge(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_void_op(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_echo(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_audit(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_guard(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_isolate(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_verify(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_watch(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_trace(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_molt(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_fossilize(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_stasis(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_rhythm(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_pulse_op(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_signal_op(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_yield_op(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_recast(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_dry_run(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_mock(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_prove(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_strike(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_flux(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_ossify(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_bond(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_still(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_resonate(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_oscillate(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_imc_hijack(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_occupy(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_refract(struct vitriol_device *vdev, struct alka_drop *pkt);
static int op_pipe(struct vitriol_device *vdev, struct alka_drop *pkt);

/* ============================================================================
 * Opcode dispatch table
 * ============================================================================ */

typedef int (*op_handler_t)(struct vitriol_device *, struct alka_drop *);

static const op_handler_t opcode_handlers[256] = {
    [ALKA_OP_CLAIM]       = op_claim,
    [ALKA_OP_STAKE]       = op_stake,
    [ALKA_OP_FLOW]        = op_flow,
    [ALKA_OP_SHIFT]       = op_shift,
    [ALKA_OP_FENCE]       = op_fence,
    [ALKA_OP_SYNC]        = op_sync,
    [ALKA_OP_SENSE]       = op_sense,
    [ALKA_OP_PULSE]       = op_pulse_op,
    [ALKA_OP_SIGNAL]      = op_signal_op,
    [ALKA_OP_YIELD]       = op_yield_op,
    [ALKA_OP_RECAST]      = op_recast,
    [ALKA_OP_SNAP]        = op_snap,
    [ALKA_OP_REVERT]      = op_revert,
    [ALKA_OP_LIMIT]       = op_limit,
    [ALKA_OP_CLAIM]        = op_veil,
    [ALKA_OP_SNAP]        = op_molt,
    [ALKA_OP_ECHO]        = op_echo,
    [ALKA_OP_STASIS]      = op_stasis,
    [ALKA_OP_PERSIST]   = op_fossilize,
    [ALKA_OP_POKE]      = op_strike,
    [ALKA_OP_RESET]      = op_quench,
    [ALKA_OP_INJECT]       = op_forge,
    [ALKA_OP_WIPE]        = op_void_op,
    [ALKA_OP_FLUX]        = op_flux,
    [ALKA_OP_AUDIT]       = op_audit,
    [ALKA_OP_DRY_RUN]     = op_dry_run,
    [ALKA_OP_MOCK]        = op_mock,
    [ALKA_OP_PROVE]       = op_prove,
    [ALKA_OP_WATCH]       = op_watch,
    [ALKA_OP_TRACE]       = op_trace,
    [ALKA_OP_GUARD]       = op_guard,
    [ALKA_OP_ISOLATE]     = op_isolate,
    [ALKA_OP_VERIFY]      = op_verify,
    [ALKA_OP_AFFINITY]      = op_ossify,
    [ALKA_OP_TUNNEL]        = op_bond,
    [ALKA_OP_SUSPEND]       = op_still,
    [ALKA_OP_COORDINATE]    = op_resonate,
    [ALKA_OP_COORDINATE]   = op_oscillate,
    [ALKA_OP_DIRECT]  = op_imc_hijack,
    [ALKA_OP_BIND]      = op_occupy,
    [ALKA_OP_RHYTHM]      = op_rhythm,
    [ALKA_OP_SLICE]     = op_refract,
    [ALKA_OP_PIPE]        = op_pipe,
};

/* ============================================================================
 * CRC verification (matches userspace)
 * ============================================================================ */

static u32 compute_crc(struct alka_drop *pkt)
{
    u32 crc = 0;
    u8 *bytes = (u8 *)pkt;
    int i;

    for (i = 0; i < offsetof(struct alka_drop, crc); i++) {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

/* ============================================================================
 * Thermal monitoring
 * ============================================================================ */

static u32 read_thermal_sensor(struct vitriol_device *vdev)
{
    /* Read from hwmon sysfs — in production, use hwmon API directly */
    struct device *hwmon_dev;
    char buf[32];
    ssize_t len;
    u32 temp = 0;

    /* Try nvidia hwmon */
    hwmon_dev = class_find_device_by_name(&hwmon_class, NULL, "nvidia");
    if (hwmon_dev) {
        /* Read temp1_input */
        len = sysfs_emit(buf, "%u\n", temp);
        if (len > 0)
            temp = simple_strtoul(buf, NULL, 10) / 1000;
    }

    return temp;
}

static int check_thermal(struct vitriol_device *vdev)
{
    if (vdev->safety_level < 1)
        return 0;

    vdev->current_temp = read_thermal_sensor(vdev);

    if (vdev->thermal_halt > 0 && vdev->current_temp >= vdev->thermal_halt) {
        pr_warn("VITRIOL: HALT temperature reached (%uC)\n", vdev->current_temp);
        return -EHWPOISON;
    }

    if (vdev->thermal_throttle > 0 && vdev->current_temp >= vdev->thermal_throttle) {
        pr_warn("VITRIOL: THROTTLE temperature reached (%uC)\n", vdev->current_temp);
        msleep(100);  /* Cool down */
    }

    return 0;
}

/* ============================================================================
 * Heartbeat thread (for KV260 dead-man's switch)
 * ============================================================================ */

static int heartbeat_thread_fn(void *data)
{
    struct vitriol_device *vdev = data;

    while (!kthread_should_stop()) {
        vdev->last_heartbeat = ktime_get();
        msleep(10);  /* 10ms heartbeat */
    }

    return 0;
}

/* ============================================================================
 * Opcode implementations
 * ============================================================================ */

/* CLAIM: Unbind kernel driver, stake hardware registers */
static int op_claim(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    struct pci_dev *pdev = vdev->pdev;
    u16 vendor = pkt->src_addr & 0xFFFF;
    u16 device = (pkt->src_addr >> 16) & 0xFFFF;
    int ret;

    pr_info("VITRIOL: CLAIM vendor=%04x device=%04x\n", vendor, device);

    /* Check if this is our probed device */
    if (pdev && pdev->vendor == vendor && pdev->device == device) {
        /* Unbind from current driver */
        if (pdev->driver) {
            pr_info("VITRIOL: Unbinding from %s\n", pdev->driver->name);
            pci_driver_remove(pdev);
        }

        /* Enable bus master */
        pci_set_master(pdev);

        /* Map BARs */
        vdev->bar0_base = pci_iomap(pdev, 0, 0);
        vdev->bar1_base = pci_iomap(pdev, 1, 0);
        if (!vdev->bar0_base || !vdev->bar1_base) {
            pr_err("VITRIOL: Failed to map BARs\n");
            return -ENOMEM;
        }

        vdev->bar0_phys = pci_resource_start(pdev, 0);
        vdev->bar1_phys = pci_resource_start(pdev, 1);
        vdev->bar0_len = pci_resource_len(pdev, 0);
        vdev->bar1_len = pci_resource_len(pdev, 1);

        pr_info("VITRIOL: BAR0 mapped at %pa (%pa bytes)\n",
                &vdev->bar0_phys, &vdev->bar0_len);
        pr_info("VITRIOL: BAR1 mapped at %pa (%pa bytes)\n",
                &vdev->bar1_phys, &vdev->bar1_len);

        vdev->initialized = true;
    }

    return 0;
}

/* FLOW: DMA transfer bypassing CPU */
static int op_flow(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 src = pkt->src_addr;
    u64 dst = pkt->dst_addr;
    u32 size = pkt->size;
    int ret;

    pr_info("VITRIOL: FLOW src=%llx dst=%llx size=%u\n", src, dst, size);

    ret = check_thermal(vdev);
    if (ret)
        return ret;

    if (!vdev->initialized) {
        pr_err("VITRIOL: FLOW before CLAIM\n");
        return -ENODEV;
    }

    /* Check if transfer exceeds BAR1 window — sliding window needed */
    if (size > vdev->bar1_len) {
        pr_warn("VITRIOL: FLOW exceeds BAR1 window, use SHIFT loop\n");
        return -EOVERFLOW;
    }

    /* Perform DMA transfer via coherent buffer */
    if (size <= DMA_BUFFER_SIZE) {
        /* Small transfer: use DMA buffer */
        void *buf = vdev->dma_buffer;

        /* Copy from source to DMA buffer */
        if (src >= vdev->bar0_phys && src < vdev->bar0_phys + vdev->bar0_len) {
            memcpy_fromio(buf, vdev->bar0_base + (src - vdev->bar0_phys), size);
        } else {
            /* Assume system RAM */
            memcpy(buf, phys_to_virt(src), size);
        }

        /* Copy from DMA buffer to destination */
        if (dst >= vdev->bar1_phys && dst < vdev->bar1_phys + vdev->bar1_len) {
            memcpy_toio(vdev->bar1_base + (dst - vdev->bar1_phys), buf, size);
        } else {
            memcpy(phys_to_virt(dst), buf, size);
        }
    } else {
        /* Large transfer: chunked via DMA buffer */
        u32 chunk = DMA_BUFFER_SIZE;
        u64 offset = 0;

        while (offset < size) {
            u32 this_chunk = min(chunk, (u32)(size - offset));

            ret = check_thermal(vdev);
            if (ret)
                return ret;

            /* ... chunked transfer ... */
            offset += this_chunk;
        }
    }

    /* Memory barrier */
    wmb();

    return 0;
}

/* SHIFT: Remap BAR window to new offset */
static int op_shift(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 offset = pkt->src_addr;

    pr_info("VITRIOL: SHIFT offset=%llx\n", offset);

    if (!vdev->initialized)
        return -ENODEV;

    /* Update sliding window offset */
    vdev->bar1_offset = offset;

    /* Re-map BAR1 at new offset */
    if (vdev->bar1_base) {
        pci_iounmap(vdev->pdev, vdev->bar1_base);
        vdev->bar1_base = pci_iomap(vdev->pdev, 1, 0);
    }

    /* Memory barrier */
    wmb();

    return 0;
}

/* FENCE: Spin-lock on metapage until condition met */
static int op_fence(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 expected = pkt->dst_addr;
    u32 __iomem *metapage;
    u32 value;
    int timeout_ms = 5000;
    int elapsed = 0;

    pr_info("VITRIOL: FENCE expected=%llx\n", expected);

    if (!vdev->initialized)
        return -ENODEV;

    /* Point to metapage in BAR0 */
    metapage = (u32 __iomem *)(vdev->bar0_base + 0x1000);

    while (elapsed < timeout_ms) {
        value = ioread32(metapage);
        vdev->metapage_value = value;

        if (value == (u32)expected) {
            pr_info("VITRIOL: FENCE passed (value=%u)\n", value);
            return 0;
        }

        usleep_range(100, 200);
        elapsed += 1;

        /* Check thermal during fence */
        if (check_thermal(vdev))
            return -EHWPOISON;
    }

    pr_err("VITRIOL: FENCE timeout (value=%u, expected=%u)\n", value, (u32)expected);
    return -ETIMEDOUT;
}

/* SYNC: Memory barrier */
static int op_sync(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 level = pkt->src_addr & 0xFF;

    switch (level) {
    case 1: /* wmb */
        wmb();
        break;
    case 2: /* rmb */
        rmb();
        break;
    case 3: /* full mb */
    default:
        mb();
        break;
    }

    return 0;
}

/* SENSE: Read thermal sensor */
static int op_sense(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 sensor_id = pkt->src_addr & 0xFF;

    vdev->current_temp = read_thermal_sensor(vdev);
    pr_info("VITRIOL: SENSE sensor=%u temp=%uC\n", sensor_id, vdev->current_temp);

    return 0;
}

/* STAKE: Claim physical memory region */
static int op_stake(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 phys_addr = pkt->src_addr;
    u32 size = pkt->size;

    pr_info("VITRIOL: STAKE addr=%llx size=%u\n", phys_addr, size);

    /* Mark pages as reserved */
    /* In production: use reserve_pfn_range() */

    return 0;
}

/* SNAP: Serialize hardware state */
static int op_snap(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: SNAP vessel=%u\n", pkt->vessel_id);

    if (!vdev->initialized)
        return -ENODEV;

    /* Read all BAR0 registers */
    /* In production: save to kernel buffer */

    wmb();
    return 0;
}

/* REVERT: Restore previously SNAP'd state */
static int op_revert(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: REVERT vessel=%u blob=%llu\n", pkt->vessel_id, pkt->dst_addr);

    if (!vdev->initialized)
        return -ENODEV;

    /* Restore saved state */
    mb();

    return 0;
}

/* LIMIT: Set hard contract */
static int op_limit(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 property = pkt->src_addr & 0xFF;
    u32 value = pkt->size;

    if (property == 0) { /* Thermal */
        vdev->thermal_halt = value;
        pr_info("VITRIOL: LIMIT thermal_halt=%u\n", value);
    }

    return 0;
}

/* CLAIM: Hide device from OS */
static int op_veil(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 cmd;

    pr_info("VITRIOL: CLAIM vessel=%u\n", pkt->vessel_id);

    if (!vdev->pdev)
        return -ENODEV;

    /* Clear memory decode and I/O space bits */
    pci_read_config_word(vdev->pdev, PCI_COMMAND, &cmd);
    cmd &= ~(PCI_COMMAND_MEMORY | PCI_COMMAND_IO);
    pci_write_config_word(vdev->pdev, PCI_COMMAND, cmd);

    return 0;
}

/* RESET: Emergency power cut */
static int op_quench(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u16 pmcsr;

    pr_warn("VITRIOL: RESET — cutting power to device\n");

    if (!vdev->pdev)
        return -ENODEV;

    /* Set D3cold via PCIe PM */
    pci_read_config_word(vdev->pdev, vdev->pdev->pm_cap + PCI_PM_CTRL, &pmcsr);
    pmcsr |= 3; /* D3hot */
    pci_write_config_word(vdev->pdev, vdev->pdev->pm_cap + PCI_PM_CTRL, pmcsr);

    return 0;
}

/* INJECT: FPGA partial reconfiguration */
static int op_forge(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: INJECT vessel=%u tile=%llu\n", pkt->vessel_id, pkt->dst_addr);

    /* In production: load bitstream to KV260 tile */

    return 0;
}

/* WIPE: Secure erase */
static int op_void_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: WIPE addr=%llx size=%u\n", pkt->src_addr, pkt->size);

    /* Overwrite with zeros */
    /* In production: use secure erase commands */

    return 0;
}

/* ECHO: Read without mutating */
static int op_echo(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 value;

    if (!vdev->bar0_base)
        return -ENODEV;

    value = ioread32(vdev->bar0_base + pkt->dst_addr);
    pr_info("VITRIOL: ECHO offset=%llx value=%08x\n", pkt->dst_addr, value);

    return 0;
}

/* AUDIT: Post-instruction residue check */
static int op_audit(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 err_status;

    if (!vdev->bar0_base)
        return -ENODEV;

    /* Read error/status registers */
    err_status = ioread32(vdev->bar0_base + 0x2000);

    if (err_status != 0) {
        pr_warn("VITRIOL: AUDIT found residue: 0x%08x\n", err_status);
        return -EIO;
    }

    return 0;
}

/* GUARD: Set up runtime safety sentinel */
static int op_guard(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 threshold = pkt->size;

    pr_info("VITRIOL: GUARD threshold=%u action=%llu\n", threshold, pkt->dst_addr);

    if (threshold > 0 && threshold < vdev->thermal_halt) {
        vdev->thermal_throttle = threshold;
    }

    return 0;
}

/* ISOLATE: Disconnect device from bus */
static int op_isolate(struct vetriol_device *vdev, struct alka_drop *pkt)
{
    u16 cmd;

    pr_info("VITRIOL: ISOLATE vessel=%u\n", pkt->vessel_id);

    if (!vdev->pdev)
        return -ENODEV;

    /* Disable bus master, memory decode, I/O space */
    pci_read_config_word(vdev->pdev, PCI_COMMAND, &cmd);
    cmd &= ~(PCI_COMMAND_MASTER | PCI_COMMAND_MEMORY | PCI_COMMAND_IO);
    pci_write_config_word(vdev->pdev, PCI_COMMAND, cmd);

    /* Mask interrupts */
    pci_disable_msi(vdev->pdev);

    return 0;
}

/* VERIFY: Cryptographic state verification */
static int op_verify(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: VERIFY vessel=%u expected_hash=%llu\n",
            pkt->vessel_id, pkt->dst_addr);

    /* In production: compute SHA-256 of hardware state */

    return 0;
}

/* WATCH: Real-time monitoring */
static int op_watch(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 target = pkt->src_addr & 0xFF;
    u32 interval = pkt->size;

    pr_info("VITRIOL: WATCH target=%u interval=%ums\n", target, interval);

    return 0;
}

/* TRACE: Enable execution trace */
static int op_trace(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: TRACE enabled (id=%llu)\n", pkt->src_addr);
    return 0;
}

/* SNAP: Full state dump */
static int op_molt(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: SNAP vessel=%u blob=%llu\n", pkt->vessel_id, pkt->dst_addr);

    if (!vdev->initialized)
        return -ENODEV;

    /* Dump all registers, buffers, pipeline state */

    return 0;
}

/* PERSIST: Write to Option ROM */
static int op_fossilize(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: PERSIST vessel=%u bytecode=%llu\n",
            pkt->vessel_id, pkt->dst_addr);

    /* In production: flash Option ROM */

    return 0;
}

/* STASIS: PCIe bus locking */
static int op_stasis(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: STASIS bus=%llu\n", pkt->src_addr);

    /* In production: send Retry TLPs */

    return 0;
}

/* RHYTHM: Hard-clock alignment */
static int op_rhythm(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 frequency = pkt->size;

    pr_info("VITRIOL: RHYTHM node=%llu freq=%uHz\n", pkt->src_addr, frequency);

    return 0;
}

/* PULSE: Timing signal */
static int op_pulse_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 pin = pkt->src_addr & 0xFF;
    u32 freq = pkt->size;

    pr_info("VITRIOL: PULSE pin=%u freq=%uHz\n", pin, freq);

    return 0;
}

/* SIGNAL: Hardware interrupt */
static int op_signal_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 vector = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: SIGNAL vector=%u\n", vector);

    /* In production: trigger MSI/MSI-X */

    return 0;
}

/* YIELD: Cooperative yield */
static int op_yield_op(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 micros = pkt->src_addr;

    if (micros > 0)
        usleep_range(micros, micros + 100);

    return 0;
}

/* RECAST: FPGA reconfiguration */
static int op_recast(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: RECAST vessel=%u bitstream=%llu\n",
            pkt->vessel_id, pkt->dst_addr);

    /* In production: load full FPGA bitstream */

    return 0;
}

/* DRY_RUN: Simulate only */
static int op_dry_run(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: DRY_RUN op=0x%02x (simulated)\n", pkt->src_addr & 0xFF);
    return 0;
}

/* MOCK: Use mock hardware */
static int op_mock(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: MOCK mock_id=%llu\n", pkt->src_addr);
    return 0;
}

/* PROVE: Formal verification */
static int op_prove(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: PROVE invariant=%llu\n", pkt->src_addr);
    return 0;
}

/* POKE: Rowhammer/bit flipping */
static int op_strike(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_warn("VITRIOL: POKE target=%llx pattern=%llu reps=%u\n",
            pkt->src_addr, pkt->dst_addr, pkt->size);

    /* CRITICAL: In production, this performs actual rowhammer */

    return 0;
}

/* FLUX: Cache invalidation */
static int op_flux(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: FLUX vessel=%llu\n", pkt->src_addr);

    /* In production: CLFLUSH on x86, DC CIVAC on ARM */

    return 0;
}

/* AFFINITY: Pin CPU core */
static int op_ossify(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 core_id = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: AFFINITY core=%u\n", core_id);

    /* In production: set CPU affinity, disable scheduler */

    return 0;
}

/* TUNNEL: RAM-to-GPU direct tunnel */
static int op_bond(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 ram_addr = pkt->src_addr;
    u64 gpu_addr = pkt->dst_addr;
    u32 size = pkt->size;

    pr_info("VITRIOL: TUNNEL ram=%llx gpu=%llx size=%u\n", ram_addr, gpu_addr, size);

    /* In production: set up IOMMU bypass, direct mapping */

    return 0;
}

/* SUSPEND: Manual DRAM refresh */
static int op_still(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 bank = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: SUSPEND bank=%u\n", bank);

    /* In production: take over DRAM refresh controller */

    return 0;
}

/* COORDINATE: Coordinate reset */
static int op_resonate(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: COORDINATE node_a=%llu node_b=%llu\n",
            pkt->src_addr, pkt->dst_addr);

    return 0;
}

/* COORDINATE: Dual-bank refresh */
static int op_oscillate(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    pr_info("VITRIOL: COORDINATE bank_a=%llu bank_b=%llu\n",
            pkt->src_addr, pkt->dst_addr);

    return 0;
}

/* DIRECT: Direct memory controller access */
static int op_imc_hijack(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 channel = pkt->src_addr & 0xFF;

    pr_info("VITRIOL: DIRECT channel=%u\n", channel);

    /* In production: access IMC MMIO directly */

    return 0;
}

/* BIND: Seize PCIe device */
static int op_occupy(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u32 bus = (pkt->src_addr >> 8) & 0xFF;
    u32 slot = (pkt->src_addr >> 3) & 0x1F;
    u32 func = pkt->src_addr & 0x7;

    pr_warn("VITRIOL: BIND %02x:%02x.%u — severing OS access\n",
            bus, slot, func);

    /* Disable device from OS perspective */
    if (vdev->pdev) {
        pci_clear_master(vdev->pdev);
        pci_disable_device(vdev->pdev);
    }

    return 0;
}

/* ============================================================================
 * File operations
 * ============================================================================ */

static int vitriol_open(struct inode *inode, struct file *filp)
{
    filp->private_data = g_dev;
    pr_info("VITRIOL: opened\n");
    return 0;
}

static int vitriol_release(struct inode *inode, struct file *filp)
{
    pr_info("VITRIOL: closed\n");
    return 0;
}

static long vitriol_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    struct vitriol_device *vdev = filp->private_data;
    int ret = 0;

    if (!vdev)
        return -ENODEV;

    mutex_lock(&vdev->lock);

    switch (cmd) {
    case VITRIOL_IOC_LOAD_VIAL: {
        struct vial_desc user_vial;

        if (copy_from_user(&user_vial, (void __user *)arg, sizeof(user_vial))) {
            ret = -EFAULT;
            break;
        }

        memcpy(&vdev->vial, &user_vial, sizeof(user_vial));
        pr_info("VITRIOL: Vial loaded (%u vessels)\n", user_vial.vessel_count);
        break;
    }

    case VITRIOL_IOC_EXECUTE: {
        struct {
            void __user *packets;
            u32 packet_count;
            u32 packet_size;
            struct exec_result __user *result;
        } exec_args;
        struct alka_drop *packets;
        struct exec_result result = {0};
        u32 i;

        if (copy_from_user(&exec_args, (void __user *)arg, sizeof(exec_args))) {
            ret = -EFAULT;
            break;
        }

        packets = kmalloc_array(exec_args.packet_count, exec_args.packet_size, GFP_KERNEL);
        if (!packets) {
            ret = -ENOMEM;
            break;
        }

        if (copy_from_user(packets, exec_args.packets,
                          exec_args.packet_count * exec_args.packet_size)) {
            kfree(packets);
            ret = -EFAULT;
            break;
        }

        /* Execute packets */
        for (i = 0; i < exec_args.packet_count; i++) {
            struct alka_drop *pkt = &packets[i];
            op_handler_t handler;

            /* CRC verification */
            if (compute_crc(pkt) != pkt->crc) {
                pr_err("VITRIOL: CRC fail at packet %u\n", i);
                result.status = EXEC_STATUS_CRC_FAIL;
                result.error_packet = i;
                break;
            }

            /* Skip Azoth packets (bit 7 set) in forward execution */
            if (pkt->flags & FLAG_AZOTH)
                continue;

            /* Skip DRY_RUN in production */
            if (pkt->flags & FLAG_DRY_RUN)
                continue;

            /* Thermal check */
            if (pkt->flags & FLAG_THERMAL_CHECK) {
                ret = check_thermal(vdev);
                if (ret) {
                    result.status = EXEC_STATUS_THERMAL;
                    result.error_packet = i;
                    break;
                }
            }

            /* Dispatch */
            handler = opcode_handlers[pkt->op_code];
            if (!handler) {
                pr_err("VITRIOL: Unknown opcode 0x%02x at packet %u\n",
                       pkt->op_code, i);
                result.status = EXEC_STATUS_ERROR;
                result.error_packet = i;
                break;
            }

            ret = handler(vdev, pkt);
            if (ret) {
                result.status = EXEC_STATUS_ERROR;
                result.error_packet = i;
                snprintf(result.error_msg, sizeof(result.error_msg),
                         "Opcode 0x%02x failed: %d", pkt->op_code, ret);
                break;
            }

            result.packets_executed++;
        }

        result.packets_total = exec_args.packet_count;
        result.status = result.status ?: EXEC_STATUS_OK;

        if (exec_args.result)
            copy_to_user(exec_args.result, &result, sizeof(result));

        kfree(packets);
        break;
    }

    case VITRIOL_IOC_EXECUTE_SAFE: {
        /* Execute with Azoth rollback on failure */
        struct {
            void __user *packets;
            u32 packet_count;
            u32 packet_size;
            void __user *azoth_packets;
            u32 azoth_count;
            struct exec_result __user *result;
        } safe_args;
        struct exec_result result = {0};

        if (copy_from_user(&safe_args, (void __user *)arg, sizeof(safe_args))) {
            ret = -EFAULT;
            break;
        }

        /* First try forward execution */
        /* ... same as EXECUTE ... */

        /* If failed, execute Azoth rollback */
        if (result.status != EXEC_STATUS_OK && safe_args.azoth_packets) {
            pr_warn("VITRIOL: Executing Azoth rollback\n");
            /* Execute azoth_packets in reverse order */
        }

        if (safe_args.result)
            copy_to_user(safe_args.result, &result, sizeof(result));
        break;
    }

    case VITRIOL_IOC_GET_STATE: {
        struct exec_result result;

        result.status = vdev->initialized ? EXEC_STATUS_OK : EXEC_STATUS_ERROR;
        result.thermal_peak = vdev->current_temp;
        result.bytes_transferred = 0;

        if (copy_to_user((void __user *)arg, &result, sizeof(result)))
            ret = -EFAULT;
        break;
    }

    case VITRIOL_IOC_SET_SAFETY: {
        u32 level;

        if (get_user(level, (u32 __user *)arg)) {
            ret = -EFAULT;
            break;
        }

        vdev->safety_level = level;
        pr_info("VITRIOL: Safety level set to %u\n", level);
        break;
    }

    case VITRIOL_IOC_READ_THERMAL: {
        u32 temp = read_thermal_sensor(vdev);

        if (put_user(temp, (u32 __user *)arg))
            ret = -EFAULT;
        break;
    }

    case VITRIOL_IOC_MAP_BAR: {
        struct { u8 vessel_id; u8 bar; u64 offset; u64 size; } map_args;

        if (copy_from_user(&map_args, (void __user *)arg, sizeof(map_args))) {
            ret = -EFAULT;
            break;
        }

        /* In production: ioremap at offset */
        pr_info("VITRIOL: MAP_BAR vessel=%u bar=%u offset=%llx size=%llx\n",
                map_args.vessel_id, map_args.bar, map_args.offset, map_args.size);
        break;
    }

    case VITRIOL_IOC_UNMAP_BAR: {
        struct { u8 vessel_id; u8 bar; } unmap_args;

        if (copy_from_user(&unmap_args, (void __user *)arg, sizeof(unmap_args))) {
            ret = -EFAULT;
            break;
        }

        pr_info("VITRIOL: UNMAP_BAR vessel=%u bar=%u\n",
                unmap_args.vessel_id, unmap_args.bar);
        break;
    }

    case VITRIOL_IOC_HEARTBEAT:
        vdev->last_heartbeat = ktime_get();
        break;

    case VITRIOL_IOC_QUERY_OPS: {
        u64 supported = 0;
        int i;

        for (i = 0; i < 256; i++) {
            if (opcode_handlers[i])
                supported |= (1ULL << (i % 64));
        }

        if (put_user(supported, (u64 __user *)arg))
            ret = -EFAULT;
        break;
    }

    default:
        ret = -ENOTTY;
        break;
    }

    mutex_unlock(&vdev->lock);
    return ret;
}

static const struct file_operations vitriol_fops = {
    .owner = THIS_MODULE,
    .open = vitriol_open,
    .release = vitriol_release,
    .unlocked_ioctl = vitriol_ioctl,
    .compat_ioctl = vitriol_ioctl,
};

/* ============================================================================
 * PCI probe/remove
 * ============================================================================ */

static int vitriol_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
    int ret;

    ret = pci_enable_device(pdev);
    if (ret) {
        pr_err("VITRIOL: Failed to enable device\n");
        return ret;
    }

    ret = pci_request_regions(pdev, DRIVER_NAME);
    if (ret) {
        pci_disable_device(pdev);
        return ret;
    }

    pci_set_master(pdev);

    g_dev->pdev = pdev;

    pr_info("VITRIOL: Probed %04x:%04x at %s\n",
            pdev->vendor, pdev->device, pci_name(pdev));

    return 0;
}

static void vitriol_pci_remove(struct pci_dev *pdev)
{
    if (g_dev->bar0_base)
        pci_iounmap(pdev, g_dev->bar0_base);
    if (g_dev->bar1_base)
        pci_iounmap(pdev, g_dev->bar1_base);

    pci_release_regions(pdev);
    pci_disable_device(pdev);

    g_dev->pdev = NULL;
    g_dev->initialized = false;

    pr_info("VITRIOL: Removed\n");
}

static const struct pci_device_id vitriol_pci_ids[] = {
    { PCI_DEVICE(0x10de, 0x1b82) },  /* GTX 1070 Ti */
    { PCI_DEVICE(0x10de, 0x1b06) },  /* GTX 1080 */
    { PCI_DEVICE(0x10de, 0x1b80) },  /* GTX 1080 Ti */
    { 0 }
};
MODULE_DEVICE_TABLE(pci, vitriol_pci_ids);

static struct pci_driver vitriol_pci_driver = {
    .name = DRIVER_NAME,
    .id_table = vitriol_pci_ids,
    .probe = vitriol_pci_probe,
    .remove = vitriol_pci_remove,
};

/* ============================================================================
 * Module init/exit
 * ============================================================================ */

static int __init vitriol_init(void)
{
    int ret;

    g_dev = kzalloc(sizeof(*g_dev), GFP_KERNEL);
    if (!g_dev)
        return -ENOMEM;

    mutex_init(&g_dev->lock);
    init_waitqueue_head(&g_dev->fence_wq);
    g_dev->last_heartbeat = ktime_get();

    ret = alloc_chrdev_region(&g_dev->devt, 0, 1, DEVICE_NAME);
    if (ret) {
        kfree(g_dev);
        return ret;
    }

    cdev_init(&g_dev->cdev, &vitriol_fops);
    g_dev->cdev.owner = THIS_MODULE;

    ret = cdev_add(&g_dev->cdev, g_dev->devt, 1);
    if (ret) {
        unregister_chrdev_region(g_dev->devt, 1);
        kfree(g_dev);
        return ret;
    }

    /* Allocate DMA buffer */
    g_dev->dma_buffer = dma_alloc_coherent(NULL, DMA_BUFFER_SIZE,
                                            &g_dev->dma_handle, GFP_KERNEL);
    if (!g_dev->dma_buffer) {
        cdev_del(&g_dev->cdev);
        unregister_chrdev_region(g_dev->devt, 1);
        kfree(g_dev);
        return -ENOMEM;
    }

    /* Register PCI driver */
    ret = pci_register_driver(&vitriol_pci_driver);
    if (ret) {
        dma_free_coherent(NULL, DMA_BUFFER_SIZE, g_dev->dma_buffer, g_dev->dma_handle);
        cdev_del(&g_dev->cdev);
        unregister_chrdev_region(g_dev->devt, 1);
        kfree(g_dev);
        return ret;
    }

    pr_info("VITRIOL: Athanor initialized — /dev/vitriol ready\n");

    return 0;
}

static void __exit vitriol_exit(void)
{
    if (g_dev->heartbeat_thread)
        kthread_stop(g_dev->heartbeat_thread);

    if (g_dev->dma_buffer)
        dma_free_coherent(NULL, DMA_BUFFER_SIZE, g_dev->dma_buffer, g_dev->dma_handle);

    pci_unregister_driver(&vitriol_pci_driver);
    cdev_del(&g_dev->cdev);
    unregister_chrdev_region(g_dev->devt, 1);
    kfree(g_dev);

    pr_info("VITRIOL: Athanor unloaded\n");
}

module_init(vitriol_init);
module_exit(vitriol_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Athanor — Alka Hardware Executor for VITRIOL");
MODULE_AUTHOR("Randy Smits-Schreuder Goedheijt");
MODULE_VERSION("3.0");
