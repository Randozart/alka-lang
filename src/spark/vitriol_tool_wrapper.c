/* vitriol_tool_wrapper.c
 *
 * Thin C wrapper between Zig compiler and SPARK Ada tools.
 * Handles ABI translation: Zig passes structs by pointer,
 * Ada expects access parameters. This layer ensures correct
 * calling convention on all platforms.
 */

#include "vitriol_tool_ffi.h"

/* Ada function declarations (GNAT mangled names) */
extern int tool_shift__validate(const VialConstraints *vial, const Drop *drop);
extern ToolResult tool_shift__execute(const VialConstraints *vial, const Drop *drop);

extern int tool_slice__validate(const VialConstraints *vial, const Drop *drop);
extern ToolResult tool_slice__execute(const VialConstraints *vial, const Drop *drop);

extern int tool_flow__validate(const VialConstraints *vial, const Drop *drop);
extern ToolResult tool_flow__execute(const VialConstraints *vial, const Drop *drop);

extern int tool_fence__validate(const VialConstraints *vial, const Drop *drop);
extern ToolResult tool_fence__execute(const VialConstraints *vial, const Drop *drop);

extern int tool_signal__validate(const VialConstraints *vial, const Drop *drop);
extern ToolResult tool_signal__execute(const VialConstraints *vial, const Drop *drop);

/* Public C API matching vitriol_tool_ffi.h */

int tool_shift_validate(const VialConstraints *vial, const Drop *drop) {
    return tool_shift__validate(vial, drop);
}

ToolResult tool_shift_execute(const VialConstraints *vial, const Drop *drop) {
    return tool_shift__execute(vial, drop);
}

int tool_slice_validate(const VialConstraints *vial, const Drop *drop) {
    return tool_slice__validate(vial, drop);
}

ToolResult tool_slice_execute(const VialConstraints *vial, const Drop *drop) {
    return tool_slice__execute(vial, drop);
}

int tool_flow_validate(const VialConstraints *vial, const Drop *drop) {
    return tool_flow__validate(vial, drop);
}

ToolResult tool_flow_execute(const VialConstraints *vial, const Drop *drop) {
    return tool_flow__execute(vial, drop);
}

int tool_fence_validate(const VialConstraints *vial, const Drop *drop) {
    return tool_fence__validate(vial, drop);
}

ToolResult tool_fence_execute(const VialConstraints *vial, const Drop *drop) {
    return tool_fence__execute(vial, drop);
}

int tool_signal_validate(const VialConstraints *vial, const Drop *drop) {
    return tool_signal__validate(vial, drop);
}

ToolResult tool_signal_execute(const VialConstraints *vial, const Drop *drop) {
    return tool_signal__execute(vial, drop);
}
