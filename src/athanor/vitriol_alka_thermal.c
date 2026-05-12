/*
 * vitriol_alka_thermal.c — Thermal Monitoring for VITRIOL
 *
 * Reads GPU temperature via hwmon sysfs interface.
 * On NVIDIA GPUs, temperature is exposed at:
 *   /sys/class/hwmon/hwmonN/temp1_input
 *
 * Values are in millidegrees Celsius (e.g., 65000 = 65 C).
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/hwmon.h>
#include <linux/device.h>
#include <linux/delay.h>
#include <linux/fs.h>

#include "vitriol_alka.h"
#include "vitriol_alka_core.h"

u32 vitriol_read_thermal(struct vitriol_device *vdev)
{
    struct file *fp;
    char buf[32];
    ssize_t len;
    loff_t pos = 0;
    u32 temp = 0;

    if (!vdev)
        return 0;

    /* Try common NVIDIA hwmon paths */
    fp = filp_open("/sys/class/hwmon/hwmon1/temp1_input", O_RDONLY, 0);
    if (IS_ERR(fp)) {
        fp = filp_open("/sys/class/hwmon/hwmon2/temp1_input", O_RDONLY, 0);
    }
    if (IS_ERR(fp)) {
        fp = filp_open("/sys/class/hwmon/hwmon3/temp1_input", O_RDONLY, 0);
    }

    if (!IS_ERR(fp)) {
        len = kernel_read(fp, buf, sizeof(buf) - 1, &pos);
        if (len > 0) {
            buf[len] = '\0';
            temp = simple_strtoul(buf, NULL, 10);
        }
        filp_close(fp, NULL);
    }

    vdev->current_temp = temp;
    return temp;
}

int vitriol_check_thermal(struct vitriol_device *vdev)
{
    if (vdev->safety_level < 1)
        return 0;

    vdev->current_temp = vitriol_read_thermal(vdev);

    if (vdev->thermal_halt > 0 && vdev->current_temp >= vdev->thermal_halt) {
        pr_warn("VITRIOL: HALT temperature reached (%u mC = %u C)\n",
                vdev->current_temp, vdev->current_temp / 1000);
        return -EHWPOISON;
    }

    if (vdev->thermal_throttle > 0 && vdev->current_temp >= vdev->thermal_throttle) {
        pr_warn("VITRIOL: THROTTLE temperature reached (%u mC = %u C)\n",
                vdev->current_temp, vdev->current_temp / 1000);
        msleep(100);
    }

    return 0;
}
