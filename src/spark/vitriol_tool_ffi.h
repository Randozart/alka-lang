/* vitriol_tool_ffi.h — FFI bridge between Zig compiler and SPARK tools
 *
 * Each SPARK tool is an individual, hot-swappable Ada package that
 * exposes two functions via C ABI:
 *   int tool_<name>_validate(const VialConstraints *vial, const Drop *drop);
 *   ToolResult tool_<name>_execute(const VialConstraints *vial, const Drop *drop);
 *
 * Zig calls these through @cImport or direct extern declarations.
 *
 * Tool packages:
 *   tool_shift.o   — Tool_Shift    BAR window remapping
 *   tool_flow.o    — Tool_Flow     DMA transfer
 *   tool_fence.o   — Tool_Fence    Metapage completion poll
 *   tool_signal.o  — Tool_Signal   GPU compute trigger
 *   tool_refract.o — Tool_Refract  Sub-tensor slicer
 */

#ifndef VITRIOL_TOOL_FFI_H
#define VITRIOL_TOOL_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opcode (matches Alka instruction set) */
typedef uint8_t OpCode;

/* 32-byte Drop — atomic execution unit of the Alka Sol */
typedef struct __attribute__((packed)) {
    uint8_t  op_code;
    uint8_t  flags;
    uint16_t vessel_id;
    uint64_t src_addr;
    uint64_t dst_addr;
    uint32_t size;
    uint32_t reserved;
    uint32_t crc;
} Drop;

/* Vial constraints passed from compiler to tool */
typedef struct {
    uint64_t aperture_size;
    uint64_t aperture_max;
    uint32_t thermal_halt;
    uint32_t thermal_throttle;
    bool     dma_capable;
} VialConstraints;

/* Tool result */
typedef struct {
    bool     success;
    uint64_t cycles_spent;
    uint64_t bytes_transferred;
    const char *error_message;
} ToolResult;

/* SPARK tool entry points (compiled from Ada/SPARK) */

/* SHIFT (0x04) — BAR window remapping */
int      tool_shift_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_shift_execute(const VialConstraints *vial, const Drop *drop);

/* REFRACT (0x3B) — Sub-tensor slicer */
int      tool_refract_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_refract_execute(const VialConstraints *vial, const Drop *drop);

/* FLOW (0x03) — DMA transfer */
int      tool_flow_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_flow_execute(const VialConstraints *vial, const Drop *drop);

/* FENCE (0x05) — Metapage completion poll */
int      tool_fence_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_fence_execute(const VialConstraints *vial, const Drop *drop);

/* SIGNAL (0x09) — GPU compute trigger */
int      tool_signal_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_signal_execute(const VialConstraints *vial, const Drop *drop);

#ifdef __cplusplus
}
#endif

#endif /* VITRIOL_TOOL_FFI_H */
