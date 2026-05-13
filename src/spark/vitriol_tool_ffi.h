/* vitriol_tool_ffi.h — FFI bridge between Zig compiler and SPARK tools
 *
 * Each SPARK tool exposes two functions via C ABI:
 *   int tool_<name>_validate(const VialConstraints *vial, const Drop *drop);
 *   ToolResult tool_<name>_execute(const VialConstraints *vial, const Drop *drop);
 *
 * Zig calls these through @cImport or direct extern declarations.
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
    uint64_t aperture_size;     /* BAR window size (bytes) */
    uint64_t aperture_max;      /* Max sliding window */
    uint32_t thermal_halt;      /* mC */
    uint32_t thermal_throttle;  /* mC */
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
int      tool_shift_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_shift_execute(const VialConstraints *vial, const Drop *drop);

int      tool_refract_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_refract_execute(const VialConstraints *vial, const Drop *drop);

int      tool_flow_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_flow_execute(const VialConstraints *vial, const Drop *drop);

int      tool_fence_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_fence_execute(const VialConstraints *vial, const Drop *drop);

int      tool_signal_validate(const VialConstraints *vial, const Drop *drop);
ToolResult tool_signal_execute(const VialConstraints *vial, const Drop *drop);

#ifdef __cplusplus
}
#endif

#endif /* VITRIOL_TOOL_FFI_H */
