// spark_bridge.zig — Unified C ABI bridge to SPARK-verified tools
//
// Each function calls the corresponding GNAT-compiled Ada package
// through the C ABI. All tools are formally verified by gnatprove.

const std = @import("std");

pub const Drop = packed struct {
    op_kind: u8,
    flags: u8,
    vessel_id: u16,
    src_addr: u64,
    dst_addr: u64,
    size: u32,
    reserved: u32,
    crc: u32,
};

pub const VialConstraints = extern struct {
    aperture_size: u64,
    aperture_max: u64,
    thermal_halt: u32,
    thermal_throttle: u32,
    dma_capable: bool,
};

pub const ToolResult = extern struct {
    success: bool,
    cycles_spent: u64,
    bytes_transferred: u64,
    error_message: ?*anyopaque,
};

// GNAT mangles: Tool_Shift.Validate -> tool_shift__validate
// C wrapper exposes: tool_shift_validate
extern fn tool_shift_validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_shift_execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

extern fn tool_refract_validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_refract_execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

extern fn tool_flow_validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_flow_execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

extern fn tool_fence_validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_fence_execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

extern fn tool_signal_validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_signal_execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

pub fn validateShift(vial: *const VialConstraints, drop: *const Drop) bool {
    return tool_shift_validate(vial, drop) != 0;
}

pub fn executeShift(vial: *const VialConstraints, drop: *const Drop) ToolResult {
    return tool_shift_execute(vial, drop);
}

pub fn validateRefract(vial: *const VialConstraints, drop: *const Drop) bool {
    return tool_refract_validate(vial, drop) != 0;
}

pub fn executeRefract(vial: *const VialConstraints, drop: *const Drop) ToolResult {
    return tool_refract_execute(vial, drop);
}

pub fn validateFlow(vial: *const VialConstraints, drop: *const Drop) bool {
    return tool_flow_validate(vial, drop) != 0;
}

pub fn executeFlow(vial: *const VialConstraints, drop: *const Drop) ToolResult {
    return tool_flow_execute(vial, drop);
}

pub fn validateFence(vial: *const VialConstraints, drop: *const Drop) bool {
    return tool_fence_validate(vial, drop) != 0;
}

pub fn executeFence(vial: *const VialConstraints, drop: *const Drop) ToolResult {
    return tool_fence_execute(vial, drop);
}

pub fn validateSignal(vial: *const VialConstraints, drop: *const Drop) bool {
    return tool_signal_validate(vial, drop) != 0;
}

pub fn executeSignal(vial: *const VialConstraints, drop: *const Drop) ToolResult {
    return tool_signal_execute(vial, drop);
}
