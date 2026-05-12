/*
 * vitriol_alka_dma.c — DMA Engine for VITRIOL
 *
 * Implements:
 * 1. Bounce buffer DMA (CPU-mediated copy via coherent buffer)
 * 2. NVMe→GPU direct streaming via kernel VFS + metapage signaling
 * 3. NVIDIA BAR sliding window management
 *
 * Based on NVIDIA GDS patterns from nvfs-core.c:
 * - kiocb completion callbacks for async IO
 * - Metapage (4KB shared memory) for fence signaling
 * - wmb() before signaling completion
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/pci.h>
#include <linux/dma-mapping.h>
#include <linux/fs.h>
#include <linux/uio.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/delay.h>
#include <linux/version.h>

#include "vitriol_alka.h"
#include "vitriol_alka_core.h"

/* ============================================================================
 * NVIDIA BAR sliding window
 *
 * The GTX 1070 Ti BAR1 is 256MB. To access VRAM beyond this window,
 * we must reprogram the GPU's aperture registers. NVIDIA GPUs use
 * the BAR1 base register at offset 0x619F00 (PFB BAR1 base) to
 * control the VRAM mapping.
 * ============================================================================ */

int shift_bar1_window(struct vitriol_device *vdev, u64 vram_offset)
{
    u64 aligned_offset;

    if (!vdev->bar1_base)
        return -ENODEV;

    /* Align to BAR1 size */
    aligned_offset = vram_offset & ~(vdev->bar1_len - 1);

    if (aligned_offset == vdev->bar1_offset)
        return 0; /* Already at correct offset */

    pr_debug("VITRIOL: SHIFT BAR1 window from %llx to %llx\n",
             vdev->bar1_offset, aligned_offset);

    /* NVIDIA Pascal BAR1 aperture control:
     * The actual VRAM offset is controlled by the GPU's memory controller.
     * In production, you'd write to PFB registers. For now, we track
     * the offset and adjust DMA addresses accordingly.
     */
    vdev->bar1_offset = aligned_offset;

    /* Memory barrier before any access through new window */
    wmb();

    return 0;
}

/* ============================================================================
 * Bounce buffer DMA transfer
 *
 * Uses the 4MB coherent DMA buffer to shuttle data between:
 * - System RAM / NVMe page cache → DMA buffer → GPU BAR1 (VRAM)
 *
 * This is the CPU-mediated path. For true P2P DMA, you'd need
 * IOMMU bypass and PCIe peer-to-peer support.
 * ============================================================================ */

int vitriol_dma_transfer(struct vitriol_device *vdev, u64 src, u64 dst, u32 size)
{
    u32 chunk_size = DMA_BUFFER_SIZE;
    u64 offset = 0;
    int ret;

    if (!vdev->initialized || !vdev->dma_buffer)
        return -ENODEV;

    if (!size)
        return 0;

    pr_debug("VITRIOL: DMA transfer src=%llx dst=%llx size=%u\n", src, dst, size);

    while (offset < size) {
        u32 this_chunk = min(chunk_size, (u32)(size - offset));

        ret = vitriol_check_thermal(vdev);
        if (ret)
            return ret;

        /* Step 1: Read source into DMA buffer */
        if (src >= vdev->bar0_phys && src < vdev->bar0_phys + vdev->bar0_len) {
            /* Source is BAR0 (control registers) */
            memcpy_fromio(vdev->dma_buffer,
                         vdev->bar0_base + (src + offset - vdev->bar0_phys),
                         this_chunk);
        } else if (src >= vdev->bar1_phys && src < vdev->bar1_phys + vdev->bar1_len) {
            /* Source is BAR1 (VRAM window) */
            u64 vram_off = src + offset - vdev->bar1_phys + vdev->bar1_offset;
            /* Need to shift window if accessing different VRAM region */
            shift_bar1_window(vdev, vram_off);
            memcpy_fromio(vdev->dma_buffer,
                         vdev->bar1_base + (vram_off - vdev->bar1_offset),
                         this_chunk);
        } else {
            /* Source is system RAM */
            void *src_virt = phys_to_virt(src + offset);
            memcpy(vdev->dma_buffer, src_virt, this_chunk);
        }

        /* Step 2: Write DMA buffer to destination */
        if (dst >= vdev->bar1_phys && dst < vdev->bar1_phys + vdev->bar1_len) {
            /* Destination is BAR1 (VRAM window) */
            u64 vram_off = dst + offset - vdev->bar1_phys + vdev->bar1_offset;
            shift_bar1_window(vdev, vram_off);
            memcpy_toio(vdev->bar1_base + (vram_off - vdev->bar1_offset),
                       vdev->dma_buffer, this_chunk);
        } else if (dst >= vdev->bar0_phys && dst < vdev->bar0_phys + vdev->bar0_len) {
            /* Destination is BAR0 */
            memcpy_toio(vdev->bar0_base + (dst + offset - vdev->bar0_phys),
                       vdev->dma_buffer, this_chunk);
        } else {
            /* Destination is system RAM */
            void *dst_virt = phys_to_virt(dst + offset);
            memcpy(dst_virt, vdev->dma_buffer, this_chunk);
        }

        offset += this_chunk;
    }

    /* Memory barrier — ensure all writes are visible to GPU */
    wmb();

    return 0;
}

/* ============================================================================
 * NVMe → GPU direct streaming (Moore Stream)
 *
 * This is the critical path for running LLMs on legacy hardware:
 * 1. Open NVMe file (model weights on SSD)
 * 2. Read chunks via kernel VFS (uses page cache)
 * 3. Copy from page cache → DMA buffer → GPU VRAM via BAR1
 * 4. Signal completion via metapage (GDS pattern)
 *
 * For true zero-copy, you'd use:
 * - NVMe P2P DMA (requires IOMMU passthrough)
 * - NVIDIA GPUDirect Storage (enterprise GPUs only)
 *
 * This implementation uses the bounce buffer approach which works
 * on all Pascal GPUs including GTX 1070 Ti.
 * ============================================================================ */

int vitriol_nvme_to_gpu(struct vitriol_device *vdev, struct file *nvme_file,
                        loff_t file_offset, u64 gpu_offset, u32 size)
{
    u32 chunk_size = DMA_BUFFER_SIZE;
    u64 transferred = 0;
    loff_t pos = file_offset;
    int ret;
    struct iov_iter iter;
    struct kvec kv;

    if (!vdev->initialized || !vdev->dma_buffer)
        return -ENODEV;

    if (!nvme_file)
        return -EINVAL;

    pr_info("VITRIOL: Moore Stream NVMe→GPU file_off=%llx gpu_off=%llx size=%u\n",
            file_offset, gpu_offset, size);

    while (transferred < size) {
        u32 this_chunk = min(chunk_size, (u32)(size - transferred));

        ret = vitriol_check_thermal(vdev);
        if (ret)
            return ret;

        /* Step 1: Read from NVMe file into DMA buffer via kernel_read */
        kv.iov_base = vdev->dma_buffer;
        kv.iov_len = this_chunk;
        iov_iter_kvec(&iter, READ, &kv, 1, this_chunk);

        ret = kernel_read(nvme_file, vdev->dma_buffer, this_chunk, &pos);
        if (ret < 0) {
            pr_err("VITRIOL: NVMe read failed at offset %llx: %d\n",
                   file_offset + transferred, ret);
            return ret;
        }

        if (ret == 0) {
            pr_err("VITRIOL: Unexpected EOF at offset %llx\n",
                   file_offset + transferred);
            return -EIO;
        }

        /* Step 2: Write to GPU VRAM via BAR1 */
        u64 vram_off = gpu_offset + transferred;
        ret = shift_bar1_window(vdev, vram_off);
        if (ret)
            return ret;

        u64 bar1_offset_in_window = vram_off - vdev->bar1_offset;
        if (bar1_offset_in_window + ret <= vdev->bar1_len) {
            memcpy_toio(vdev->bar1_base + bar1_offset_in_window,
                       vdev->dma_buffer, ret);
        } else {
            /* Chunk spans window boundary — split */
            u32 first_part = vdev->bar1_len - bar1_offset_in_window;
            memcpy_toio(vdev->bar1_base + bar1_offset_in_window,
                       vdev->dma_buffer, first_part);

            /* Shift window and write remainder */
            shift_bar1_window(vdev, vram_off + first_part);
            memcpy_toio(vdev->bar1_base,
                       vdev->dma_buffer + first_part,
                       ret - first_part);
        }

        transferred += ret;

        /* Update metapage with progress (userspace can poll this) */
        if (vdev->metapage) {
            vdev->metapage_value = (u32)(transferred * 100 / size);
            wmb();
        }
    }

    /* Final memory barrier */
    wmb();

    pr_info("VITRIOL: Moore Stream complete — %llu bytes transferred\n", transferred);
    return 0;
}

/* ============================================================================
 * Metapage signaling (GDS completion pattern)
 *
 * NVIDIA GDS uses a shared 4KB page between kernel and userspace:
 * - Kernel writes fence_value after DMA completion
 * - Userspace polls the page (no syscall overhead)
 * - This is faster than eventfd or futex for tight loops
 * ============================================================================ */

void vitriol_signal_metapage(struct vitriol_device *vdev, u64 fence_value)
{
    /* Update software fence value for FENCE instruction */
    vdev->metapage_value = (u32)fence_value;

    if (!vdev->metapage)
        return;

    /* Write fence value — userspace is polling this */
    vdev->metapage[0] = fence_value;

    /* CRITICAL: memory barrier before userspace sees it */
    wmb();

    pr_debug("VITRIOL: Metapage fence signaled: %llu\n", fence_value);
}
