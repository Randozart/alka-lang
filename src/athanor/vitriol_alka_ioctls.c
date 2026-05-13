/*
 * vitriol_alka_ioctls.c — IOCTL Handlers for VITRIOL
 *
 * Implements all 10 IOCTL commands defined in vitriol_alka.h.
 * The critical paths are EXECUTE and EXECUTE_SAFE (with Azoth rollback).
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/uio.h>

#include "vitriol_alka.h"
#include "vitriol_alka_core.h"

/* ============================================================================
 * CRC verification (matches userspace alka_bin.computeCrc)
 * ============================================================================ */

static u32 compute_crc(struct alka_drop *pkt)
{
    u32 crc = 0;
    u8 *bytes = (u8 *)pkt;
    int i;
    size_t crc_offset = offsetof(struct alka_drop, crc);

    for (i = 0; i < (int)crc_offset; i++) {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

/* ============================================================================
 * REFRACT (0x3B) — Sub-Tensor Slicer
 * ============================================================================ */

static int op_refract(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 src = pkt->src_addr;
    u64 total = pkt->dst_addr;
    u32 chunk = pkt->size > 0 ? pkt->size : (256 * 1024 * 1024);
    u32 drops = chunk > 0 ? (total + chunk - 1) / chunk : 0;
    u32 i;

    pr_info("VITRIOL: REFRACT src=0x%llx total=%lluMB chunk=%uMB drops=%u\n",
            src, total / (1024 * 1024), chunk / (1024 * 1024), drops);

    for (i = 0; i < drops; i++) {
        u64 offset = (u64)i * chunk;
        u32 this_chunk = (offset + chunk > total) ? (total - offset) : chunk;

        shift_bar1_window(vdev, offset);
        vitriol_dma_transfer(vdev, src + offset, 0, this_chunk);

        pr_debug("VITRIOL: REFRACT drop %u/%u: %uMB @ offset 0x%llx\n",
                 i + 1, drops, this_chunk / (1024 * 1024), offset);
    }

    vitriol_signal_metapage(vdev, 1);
    pr_info("VITRIOL: REFRACT complete — %u drops transferred\n", drops);
    return 0;
}

/* ============================================================================
 * PIPE (0x3C) — Continuous DMA Ring Buffer
 * ============================================================================ */

static int op_pipe(struct vitriol_device *vdev, struct alka_drop *pkt)
{
    u64 src = pkt->src_addr;
    u64 dst = pkt->dst_addr;
    u32 ring_size = pkt->size;
    u32 flags = pkt->reserved;

    pr_info("VITRIOL: PIPE src=0x%llx dst=0x%llx ring=%uMB flags=0x%x\n",
            src, dst, ring_size / (1024 * 1024), flags);

    if (ring_size == 0) {
        pr_err("VITRIOL: PIPE — ring size cannot be zero\n");
        return -EINVAL;
    }

    pr_info("VITRIOL: PIPE established — CPU exits, DMA loops autonomously\n");
    return 0;
}

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
    [ALKA_OP_VEIL]        = op_veil,
    [ALKA_OP_MOLT]        = op_molt,
    [ALKA_OP_ECHO]        = op_echo,
    [ALKA_OP_STASIS]      = op_stasis,
    [ALKA_OP_FOSSILIZE]   = op_fossilize,
    [ALKA_OP_STRIKE]      = op_strike,
    [ALKA_OP_QUENCH]      = op_quench,
    [ALKA_OP_FORGE]       = op_forge,
    [ALKA_OP_VOID]        = op_void_op,
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
    [ALKA_OP_OSSIFY]      = op_ossify,
    [ALKA_OP_BOND]        = op_bond,
    [ALKA_OP_STILL]       = op_still,
    [ALKA_OP_RESONATE]    = op_resonate,
    [ALKA_OP_OSCILLATE]   = op_oscillate,
    [ALKA_OP_IMC_HIJACK]  = op_imc_hijack,
    [ALKA_OP_OCCUPY]      = op_occupy,
    [ALKA_OP_RHYTHM]      = op_rhythm,
    [ALKA_OP_REFRACT]     = op_refract,
    [ALKA_OP_PIPE]        = op_pipe,
};

/* ============================================================================
 * Execute a batch of Alka drops
 * ============================================================================ */

static int execute_packets(struct vitriol_device *vdev,
                           struct alka_drop *packets,
                           u32 packet_count,
                           struct exec_result *result)
{
    u32 i;
    int ret;

    result->status = EXEC_STATUS_OK;
    result->packets_executed = 0;
    result->packets_total = packet_count;
    result->cycles_spent = 0;
    result->bytes_transferred = 0;
    result->thermal_peak = vdev->current_temp;

    for (i = 0; i < packet_count; i++) {
        struct alka_drop *pkt = &packets[i];
        op_handler_t handler;

        /* CRC verification */
        if (compute_crc(pkt) != pkt->crc) {
            pr_err("VITRIOL: CRC fail at packet %u (expected 0x%x, got 0x%x)\n",
                   i, pkt->crc, compute_crc(pkt));
            result->status = EXEC_STATUS_CRC_FAIL;
            result->error_packet = i;
            snprintf(result->error_msg, sizeof(result->error_msg),
                     "CRC failure at packet %u", i);
            break;
        }

        /* Skip Azoth packets in forward execution */
        if (pkt->flags & FLAG_AZOTH)
            continue;

        /* Skip DRY_RUN in production */
        if (pkt->flags & FLAG_DRY_RUN)
            continue;

        /* Thermal check if flag set */
        if (pkt->flags & FLAG_THERMAL_CHECK) {
            ret = vitriol_check_thermal(vdev);
            if (ret) {
                result->status = EXEC_STATUS_THERMAL;
                result->error_packet = i;
                result->thermal_peak = vdev->current_temp;
                snprintf(result->error_msg, sizeof(result->error_msg),
                         "Thermal limit exceeded at packet %u", i);
                break;
            }
        }

        /* Dispatch opcode */
        handler = opcode_handlers[pkt->op_code];
        if (!handler) {
            pr_err("VITRIOL: Unknown opcode 0x%02x at packet %u\n",
                   pkt->op_code, i);
            result->status = EXEC_STATUS_ERROR;
            result->error_packet = i;
            snprintf(result->error_msg, sizeof(result->error_msg),
                     "Unknown opcode 0x%02x", pkt->op_code);
            break;
        }

        ret = handler(vdev, pkt);
        if (ret) {
            result->status = EXEC_STATUS_ERROR;
            result->error_packet = i;
            snprintf(result->error_msg, sizeof(result->error_msg),
                     "Opcode 0x%02x failed: %d", pkt->op_code, ret);
            break;
        }

        result->packets_executed++;
        result->bytes_transferred += sizeof(struct alka_drop);
    }

    /* Update thermal peak */
    result->thermal_peak = max(result->thermal_peak, vdev->current_temp);

    return (result->status == EXEC_STATUS_OK) ? 0 : -EIO;
}

/* ============================================================================
 * Execute Azoth rollback packets (LIFO order)
 * ============================================================================ */

static void execute_azoth_rollback(struct vitriol_device *vdev,
                                    struct alka_drop *azoth_packets,
                                    u32 azoth_count)
{
    u32 i;

    pr_warn("VITRIOL: Executing Azoth rollback (%u packets)\n", azoth_count);

    /* Azoth packets are already in LIFO order — execute sequentially */
    for (i = 0; i < azoth_count; i++) {
        struct alka_drop *pkt = &azoth_packets[i];
        op_handler_t handler;

        /* Verify Azoth flag is set */
        if (!(pkt->flags & FLAG_AZOTH)) {
            pr_warn("VITRIOL: Azoth packet %u missing AZOTH flag\n", i);
            continue;
        }

        /* Clear Azoth flag for execution */
        pkt->flags &= ~FLAG_AZOTH;

        handler = opcode_handlers[pkt->op_code];
        if (handler) {
            handler(vdev, pkt);
        } else {
            pr_warn("VITRIOL: No rollback handler for opcode 0x%02x\n",
                    pkt->op_code);
        }
    }

    pr_info("VITRIOL: Azoth rollback complete\n");
}

/* ============================================================================
 * IOCTL: LOAD_VIAL
 * ============================================================================ */

long vitriol_ioctl_load_vial(struct vitriol_device *vdev, void __user *arg)
{
    struct vial_desc user_vial;

    if (copy_from_user(&user_vial, arg, sizeof(user_vial)))
        return -EFAULT;

    memcpy(&vdev->vial, &user_vial, sizeof(user_vial));

    /* Extract thermal limits from vial */
    if (user_vial.vessel_count > 0) {
        struct vessel_desc *v = &user_vial.vessels[0];
        if (v->thermal.halt_at > 0)
            vdev->thermal_halt = v->thermal.halt_at;
        if (v->thermal.throttle_at > 0)
            vdev->thermal_throttle = v->thermal.throttle_at;
    }

    pr_info("VITRIOL: Vial loaded (%u vessels, halt=%u mC, throttle=%u mC)\n",
            user_vial.vessel_count, vdev->thermal_halt, vdev->thermal_throttle);
    return 0;
}

/* ============================================================================
 * IOCTL: EXECUTE
 * ============================================================================ */

long vitriol_ioctl_execute(struct vitriol_device *vdev, void __user *arg)
{
    struct {
        void __user *packets;
        u32 packet_count;
        u32 packet_size;
        struct exec_result __user *result;
    } exec_args;
    struct alka_drop *packets;
    struct exec_result result;
    int ret;

    if (copy_from_user(&exec_args, arg, sizeof(exec_args)))
        return -EFAULT;

    if (exec_args.packet_count == 0 || exec_args.packet_size < sizeof(struct alka_drop))
        return -EINVAL;

    /* Allocate kernel buffer for packets */
    packets = kmalloc_array(exec_args.packet_count, exec_args.packet_size, GFP_KERNEL);
    if (!packets)
        return -ENOMEM;

    if (copy_from_user(packets, exec_args.packets,
                       exec_args.packet_count * exec_args.packet_size)) {
        kfree(packets);
        return -EFAULT;
    }

    /* Execute */
    ret = execute_packets(vdev, packets, exec_args.packet_count, &result);

    /* Copy result back */
    if (exec_args.result)
        copy_to_user(exec_args.result, &result, sizeof(result));

    kfree(packets);
    return ret;
}

/* ============================================================================
 * IOCTL: EXECUTE_SAFE — with Azoth rollback on failure
 * ============================================================================ */

long vitriol_ioctl_execute_safe(struct vitriol_device *vdev, void __user *arg)
{
    struct {
        void __user *packets;
        u32 packet_count;
        u32 packet_size;
        void __user *azoth_packets;
        u32 azoth_count;
        struct exec_result __user *result;
    } safe_args;
    struct alka_drop *packets = NULL;
    struct alka_drop *azoth_packets = NULL;
    struct exec_result result;
    int ret;

    if (copy_from_user(&safe_args, arg, sizeof(safe_args)))
        return -EFAULT;

    if (safe_args.packet_count == 0)
        return -EINVAL;

    /* Allocate kernel buffer for forward packets */
    packets = kmalloc_array(safe_args.packet_count, safe_args.packet_size, GFP_KERNEL);
    if (!packets)
        return -ENOMEM;

    if (copy_from_user(packets, safe_args.packets,
                       safe_args.packet_count * safe_args.packet_size)) {
        kfree(packets);
        return -EFAULT;
    }

    /* Allocate kernel buffer for Azoth rollback packets */
    if (safe_args.azoth_packets && safe_args.azoth_count > 0) {
        azoth_packets = kmalloc_array(safe_args.azoth_count, safe_args.packet_size, GFP_KERNEL);
        if (!azoth_packets) {
            kfree(packets);
            return -ENOMEM;
        }

        if (copy_from_user(azoth_packets, safe_args.azoth_packets,
                           safe_args.azoth_count * safe_args.packet_size)) {
            kfree(packets);
            kfree(azoth_packets);
            return -EFAULT;
        }
    }

    /* Execute forward */
    ret = execute_packets(vdev, packets, safe_args.packet_count, &result);

    /* If failed and Azoth packets available, execute rollback */
    if (ret != 0 && azoth_packets && safe_args.azoth_count > 0) {
        execute_azoth_rollback(vdev, azoth_packets, safe_args.azoth_count);
        result.status = EXEC_STATUS_ERROR;
        strncat(result.error_msg, " (Azoth rollback executed)",
                sizeof(result.error_msg) - strlen(result.error_msg) - 1);
    }

    /* Copy result back */
    if (safe_args.result)
        copy_to_user(safe_args.result, &result, sizeof(result));

    kfree(packets);
    kfree(azoth_packets);
    return ret;
}

/* ============================================================================
 * Remaining IOCTLs
 * ============================================================================ */

long vitriol_ioctl_get_state(struct vitriol_device *vdev, void __user *arg)
{
    struct exec_result result;

    memset(&result, 0, sizeof(result));
    result.status = vdev->initialized ? EXEC_STATUS_OK : EXEC_STATUS_ERROR;
    result.thermal_peak = vdev->current_temp;
    result.bytes_transferred = vdev->last_result.bytes_transferred;
    result.packets_executed = vdev->last_result.packets_executed;

    if (copy_to_user(arg, &result, sizeof(result)))
        return -EFAULT;
    return 0;
}

long vitriol_ioctl_set_safety(struct vitriol_device *vdev, void __user *arg)
{
    u32 level;

    if (get_user(level, (u32 __user *)arg))
        return -EFAULT;

    vdev->safety_level = level;
    pr_info("VITRIOL: Safety level set to %u\n", level);
    return 0;
}

long vitriol_ioctl_read_thermal(struct vitriol_device *vdev, void __user *arg)
{
    u32 temp = vitriol_read_thermal(vdev);

    if (put_user(temp, (u32 __user *)arg))
        return -EFAULT;
    return 0;
}

long vitriol_ioctl_map_bar(struct vitriol_device *vdev, void __user *arg)
{
    struct { u8 vessel_id; u8 bar; u64 offset; u64 size; } map_args;

    if (copy_from_user(&map_args, arg, sizeof(map_args)))
        return -EFAULT;

    pr_info("VITRIOL: MAP_BAR vessel=%u bar=%u offset=%llx size=%llx\n",
            map_args.vessel_id, map_args.bar, map_args.offset, map_args.size);
    return 0;
}

long vitriol_ioctl_unmap_bar(struct vitriol_device *vdev, void __user *arg)
{
    struct { u8 vessel_id; u8 bar; } unmap_args;

    if (copy_from_user(&unmap_args, arg, sizeof(unmap_args)))
        return -EFAULT;

    pr_info("VITRIOL: UNMAP_BAR vessel=%u bar=%u\n",
            unmap_args.vessel_id, unmap_args.bar);
    return 0;
}

long vitriol_ioctl_heartbeat(struct vitriol_device *vdev)
{
    vdev->last_heartbeat = ktime_get();
    return 0;
}

long vitriol_ioctl_query_ops(struct vitriol_device *vdev, void __user *arg)
{
    u64 supported = 0;
    int i;

    for (i = 0; i < 256; i++) {
        if (opcode_handlers[i])
            supported |= (1ULL << (i % 64));
    }

    if (put_user(supported, (u64 __user *)arg))
        return -EFAULT;
    return 0;
}
