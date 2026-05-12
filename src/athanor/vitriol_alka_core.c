/*
 * vitriol_alka_core.c — Athanor Kernel Module Core
 *
 * Device registration, PCI probe, character device, and module lifecycle.
 *
 * License: GPL v2
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/pci.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/uaccess.h>
#include <linux/mutex.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/ktime.h>
#include <linux/hwmon.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/interrupt.h>
#include <linux/ioctl.h>
#include <linux/slab.h>
#include <linux/version.h>

#include "vitriol_alka.h"
#include "vitriol_alka_core.h"

#define DRIVER_NAME "vitriol_alka"
#define DEVICE_NAME "vitriol"
#define DMA_BUFFER_SIZE (4 * 1024 * 1024)  /* 4MB DMA bounce buffer */

struct vitriol_device *g_dev;

/* Supported GPUs */
static const struct pci_device_id vitriol_pci_ids[] = {
    { PCI_DEVICE(0x10de, 0x1b82) },  /* GTX 1070 Ti */
    { PCI_DEVICE(0x10de, 0x1b06) },  /* GTX 1080 */
    { PCI_DEVICE(0x10de, 0x1b80) },  /* GTX 1080 Ti */
    { PCI_DEVICE(0x10de, 0x1401) },  /* GTX 960 (2GB) */
    { PCI_DEVICE(0x10de, 0x1406) },  /* GTX 960 (4GB) */
    { 0 }
};
MODULE_DEVICE_TABLE(pci, vitriol_pci_ids);

/* Forward declarations */
static int vitriol_open(struct inode *inode, struct file *filp);
static int vitriol_release(struct inode *inode, struct file *filp);
static long vitriol_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
static int vitriol_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id);
static void vitriol_pci_remove(struct pci_dev *pdev);

static const struct file_operations vitriol_fops = {
    .owner = THIS_MODULE,
    .open = vitriol_open,
    .release = vitriol_release,
    .unlocked_ioctl = vitriol_ioctl,
    .compat_ioctl = vitriol_ioctl,
};

static struct pci_driver vitriol_pci_driver = {
    .name = DRIVER_NAME,
    .id_table = vitriol_pci_ids,
    .probe = vitriol_pci_probe,
    .remove = vitriol_pci_remove,
};

/* ============================================================================
 * Device file operations
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

/* ============================================================================
 * IOCTL dispatcher — delegates to vitriol_alka_ioctls.c
 * ============================================================================ */

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

static long vitriol_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    struct vitriol_device *vdev = filp->private_data;
    long ret = 0;

    if (!vdev)
        return -ENODEV;

    mutex_lock(&vdev->lock);

    switch (cmd) {
    case VITRIOL_IOC_LOAD_VIAL:
        ret = vitriol_ioctl_load_vial(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_EXECUTE:
        ret = vitriol_ioctl_execute(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_EXECUTE_SAFE:
        ret = vitriol_ioctl_execute_safe(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_GET_STATE:
        ret = vitriol_ioctl_get_state(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_SET_SAFETY:
        ret = vitriol_ioctl_set_safety(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_READ_THERMAL:
        ret = vitriol_ioctl_read_thermal(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_MAP_BAR:
        ret = vitriol_ioctl_map_bar(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_UNMAP_BAR:
        ret = vitriol_ioctl_unmap_bar(vdev, (void __user *)arg);
        break;
    case VITRIOL_IOC_HEARTBEAT:
        ret = vitriol_ioctl_heartbeat(vdev);
        break;
    case VITRIOL_IOC_QUERY_OPS:
        ret = vitriol_ioctl_query_ops(vdev, (void __user *)arg);
        break;
    default:
        ret = -ENOTTY;
        break;
    }

    mutex_unlock(&vdev->lock);
    return ret;
}

/* ============================================================================
 * Heartbeat thread (KV260 dead-man's switch)
 * ============================================================================ */

static int heartbeat_thread_fn(void *data)
{
    struct vitriol_device *vdev = data;

    while (!kthread_should_stop()) {
        vdev->last_heartbeat = ktime_get();
        msleep(10);
    }

    return 0;
}

/* ============================================================================
 * PCI Probe — the critical path
 * ============================================================================ */

static int vitriol_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
    int ret;

    pr_info("VITRIOL: Probing GPU %04x:%04x at %s\n",
            pdev->vendor, pdev->device, pci_name(pdev));

    /* Enable PCI device */
    ret = pci_enable_device(pdev);
    if (ret) {
        pr_err("VITRIOL: Failed to enable device\n");
        return ret;
    }

    /* Request BAR regions */
    ret = pci_request_regions(pdev, DRIVER_NAME);
    if (ret) {
        pr_err("VITRIOL: Failed to request BAR regions\n");
        goto err_disable;
    }

    pci_set_master(pdev);

    /* Set DMA mask — try 64-bit, fall back to 32-bit */
    ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(64));
    if (ret) {
        pr_warn("VITRIOL: 64-bit DMA unavailable, trying 32-bit\n");
        ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
        if (ret) {
            pr_err("VITRIOL: DMA not available\n");
            goto err_regions;
        }
    }

    /* Store in global device */
    g_dev->pdev = pdev;
    g_dev->bar0_phys = pci_resource_start(pdev, 0);
    g_dev->bar1_phys = pci_resource_start(pdev, 1);
    g_dev->bar0_len = pci_resource_len(pdev, 0);
    g_dev->bar1_len = pci_resource_len(pdev, 1);

    pr_info("VITRIOL: BAR0 phys=%pa len=%pa\n", &g_dev->bar0_phys, &g_dev->bar0_len);
    pr_info("VITRIOL: BAR1 phys=%pa len=%pa (VRAM window)\n", &g_dev->bar1_phys, &g_dev->bar1_len);

    /* Allocate DMA bounce buffer */
    g_dev->dma_buffer = dma_alloc_coherent(&pdev->dev, DMA_BUFFER_SIZE,
                                            &g_dev->dma_handle, GFP_KERNEL);
    if (!g_dev->dma_buffer) {
        pr_err("VITRIOL: Failed to allocate DMA buffer\n");
        ret = -ENOMEM;
        goto err_regions;
    }

    pr_info("VITRIOL: DMA buffer allocated at %pad (size: %d)\n",
            &g_dev->dma_handle, DMA_BUFFER_SIZE);

    /* Allocate metapage for completion signaling (GDS pattern) */
    g_dev->metapage = dma_alloc_coherent(&pdev->dev, PAGE_SIZE,
                                          &g_dev->metapage_dma, GFP_KERNEL);
    if (!g_dev->metapage) {
        pr_err("VITRIOL: Failed to allocate metapage\n");
        ret = -ENOMEM;
        goto err_dma;
    }

    pr_info("VITRIOL: Metapage allocated at %pad (phys)\n", &g_dev->metapage_dma);

    /* Initialize wait queue for FENCE operations */
    init_waitqueue_head(&g_dev->fence_wq);
    g_dev->metapage_value = 0;

    /* Start heartbeat thread */
    g_dev->last_heartbeat = ktime_get();
    g_dev->heartbeat_thread = kthread_run(heartbeat_thread_fn, g_dev, "vitriol_heartbeat");
    if (IS_ERR(g_dev->heartbeat_thread)) {
        pr_err("VITRIOL: Failed to create heartbeat thread\n");
        g_dev->heartbeat_thread = NULL;
    }

    pr_info("VITRIOL: GPU claimed — control plane (BAR0) and data plane (BAR1) ready\n");
    return 0;

err_dma:
    dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, g_dev->dma_buffer, g_dev->dma_handle);
err_regions:
    pci_release_regions(pdev);
err_disable:
    pci_disable_device(pdev);
    return ret;
}

static void vitriol_pci_remove(struct pci_dev *pdev)
{
    if (g_dev->heartbeat_thread) {
        kthread_stop(g_dev->heartbeat_thread);
        g_dev->heartbeat_thread = NULL;
    }

    if (g_dev->metapage)
        dma_free_coherent(&pdev->dev, PAGE_SIZE, (void *)g_dev->metapage, g_dev->metapage_dma);

    if (g_dev->dma_buffer)
        dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, g_dev->dma_buffer, g_dev->dma_handle);

    pci_release_regions(pdev);
    pci_disable_device(pdev);

    g_dev->pdev = NULL;
    g_dev->initialized = false;

    pr_info("VITRIOL: GPU released\n");
}

/* ============================================================================
 * Module init/exit
 * ============================================================================ */

static struct class *vitriol_class;
static struct device *vitriol_device_node;
static dev_t vitriol_devt;
static struct cdev vitriol_cdev;

static int __init vitriol_init(void)
{
    int ret;

    pr_info("VITRIOL: Athanor v3.0 — Alka Hardware Executor\n");
    pr_info("VITRIOL: Visita Interiora Terrae Rectificando Invenies Occultum Lapidem\n");

    /* Allocate global device */
    g_dev = kzalloc(sizeof(*g_dev), GFP_KERNEL);
    if (!g_dev)
        return -ENOMEM;

    mutex_init(&g_dev->lock);
    g_dev->safety_level = 1; /* thermal checks enabled by default */

    /* Register character device */
    ret = alloc_chrdev_region(&vitriol_devt, 0, 1, DEVICE_NAME);
    if (ret) {
        pr_err("VITRIOL: Failed to allocate chrdev\n");
        kfree(g_dev);
        return ret;
    }

    cdev_init(&vitriol_cdev, &vitriol_fops);
    vitriol_cdev.owner = THIS_MODULE;

    ret = cdev_add(&vitriol_cdev, vitriol_devt, 1);
    if (ret) {
        pr_err("VITRIOL: Failed to add cdev\n");
        unregister_chrdev_region(vitriol_devt, 1);
        kfree(g_dev);
        return ret;
    }

    /* Create device node */
    vitriol_class = class_create(DEVICE_NAME);
    if (IS_ERR(vitriol_class)) {
        pr_err("VITRIOL: Failed to create class\n");
        cdev_del(&vitriol_cdev);
        unregister_chrdev_region(vitriol_devt, 1);
        kfree(g_dev);
        return PTR_ERR(vitriol_class);
    }

    vitriol_device_node = device_create(vitriol_class, NULL, vitriol_devt, NULL, DEVICE_NAME);
    if (IS_ERR(vitriol_device_node)) {
        pr_err("VITRIOL: Failed to create device\n");
        class_destroy(vitriol_class);
        cdev_del(&vitriol_cdev);
        unregister_chrdev_region(vitriol_devt, 1);
        kfree(g_dev);
        return PTR_ERR(vitriol_device_node);
    }

    /* Register PCI driver */
    ret = pci_register_driver(&vitriol_pci_driver);
    if (ret) {
        pr_err("VITRIOL: Failed to register PCI driver\n");
        device_destroy(vitriol_class, vitriol_devt);
        class_destroy(vitriol_class);
        cdev_del(&vitriol_cdev);
        unregister_chrdev_region(vitriol_devt, 1);
        kfree(g_dev);
        return ret;
    }

    pr_info("VITRIOL: /dev/vitriol ready — waiting for GPU probe\n");
    return 0;
}

static void __exit vitriol_exit(void)
{
    pci_unregister_driver(&vitriol_pci_driver);
    device_destroy(vitriol_class, vitriol_devt);
    class_destroy(vitriol_class);
    cdev_del(&vitriol_cdev);
    unregister_chrdev_region(vitriol_devt, 1);
    kfree(g_dev);

    pr_info("VITRIOL: Athanor unloaded\n");
}

module_init(vitriol_init);
module_exit(vitriol_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Athanor — Alka Hardware Executor for VITRIOL");
MODULE_AUTHOR("Randy Smits-Schreuder Goedheijt");
MODULE_VERSION("3.0");
