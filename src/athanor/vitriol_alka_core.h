/*
 * vitriol_alka_core.h — Athanor internal header
 */

#ifndef VITRIOL_ALKA_CORE_H
#define VITRIOL_ALKA_CORE_H

#include "vitriol_alka.h"

#define DMA_BUFFER_SIZE (4 * 1024 * 1024)  /* 4MB DMA bounce buffer */

struct vitriol_device {
    struct mutex lock;

    /* PCI state */
    struct pci_dev *pdev;
    void __iomem *bar0_base;
    void __iomem *bar1_base;
    resource_size_t bar0_phys;
    resource_size_t bar1_phys;
    resource_size_t bar0_len;
    resource_size_t bar1_len;
    u64 bar1_offset;

    /* DMA */
    void *dma_buffer;
    dma_addr_t dma_handle;

    /* Metapage (GDS-style completion signaling) */
    volatile u64 *metapage;
    dma_addr_t metapage_dma;
    u32 metapage_value;

    /* Vial state */
    struct vial_desc vial;
    u32 safety_level;
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
};

extern struct vitriol_device *g_dev;

u32 vitriol_read_thermal(struct vitriol_device *vdev);
int vitriol_check_thermal(struct vitriol_device *vdev);

/* DMA engine */
int shift_bar1_window(struct vitriol_device *vdev, u64 vram_offset);
int vitriol_dma_transfer(struct vitriol_device *vdev, u64 src, u64 dst, u32 size);
int vitriol_nvme_to_gpu(struct vitriol_device *vdev, struct file *nvme_file,
                        loff_t file_offset, u64 gpu_offset, u32 size);
void vitriol_signal_metapage(struct vitriol_device *vdev, u64 fence_value);

/* Opcode handlers */
extern int op_claim(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_flow(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_shift(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_fence(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_sync(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_sense(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_stake(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_snap(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_revert(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_limit(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_veil(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_quench(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_forge(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_void_op(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_echo(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_audit(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_guard(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_isolate(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_verify(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_watch(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_trace(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_molt(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_fossilize(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_stasis(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_rhythm(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_pulse_op(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_signal_op(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_yield_op(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_recast(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_dry_run(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_mock(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_prove(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_strike(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_flux(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_ossify(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_bond(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_still(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_resonate(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_oscillate(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_imc_hijack(struct vitriol_device *vdev, struct alka_drop *pkt);
extern int op_occupy(struct vitriol_device *vdev, struct alka_drop *pkt);

/* IOCTL handlers */
extern long vitriol_ioctl_load_vial(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_execute(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_execute_safe(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_get_state(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_set_safety(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_read_thermal(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_map_bar(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_unmap_bar(struct vitriol_device *vdev, void __user *arg);
extern long vitriol_ioctl_heartbeat(struct vitriol_device *vdev);
extern long vitriol_ioctl_query_ops(struct vitriol_device *vdev, void __user *arg);

#endif /* VITRIOL_ALKA_CORE_H */
