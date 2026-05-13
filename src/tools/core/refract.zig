// REFRACT — Sub-tensor Slicer (SPARK-verified)
//
// Bridges to SPARK Ada tool_refract.adb via C ABI.
// SPARK-verified: each chunk fits aperture, drops cover full tensor,
// loop terminates, no chunk overlaps or gaps.
//
// Op-Code: 0x3B  Category: CORE  Safety: L3

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

const Drop = extern struct {
    op_kind: u8, flags: u8, vessel_id: u16,
    src_addr: u64, dst_addr: u64, size: u32,
    reserved: u32, crc: u32,
};
const VialConstraints = extern struct {
    aperture_size: u64, aperture_max: u64,
    thermal_halt: u32, thermal_throttle: u32,
    dma_capable: bool,
};
const ToolResult = extern struct {
    success: bool, cycles_spent: u64,
    bytes_transferred: u64, error_message: ?*anyopaque,
};

extern fn tool_refract__validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_refract__execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

pub const REFRACT = struct {
    pub const OP = OpCode.REFRACT;
    pub const NAME = "REFRACT";
    pub const DESCRIPTION = "Sub-tensor slicer (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 3) return error.InvalidAlignment;

        var vial = VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_size,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = true,
        };
        var drop = Drop{
            .op_kind = 0x3B,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = operands[1],
            .size = @truncate(operands[2]),
            .reserved = 0,
            .crc = 0,
        };

        const result = tool_refract__validate(&vial, &drop);
        return .{
            .allowed = result != 0,
            .injected_operations = &.{},
            .reason = if (result == 0) "SPARK: REFRACT rejected (chunk size or coverage)" else null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        var vial = VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_size,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = true,
        };
        var drop = Drop{
            .op_kind = 0x3B,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = if (operands.len >= 2) operands[1] else 0,
            .size = if (operands.len >= 3) @truncate(operands[2]) else 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = tool_refract__execute(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
