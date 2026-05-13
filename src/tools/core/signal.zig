// SIGNAL — GPU Compute Trigger (SPARK-verified)
//
// Bridges to SPARK Ada tool_signal.adb via C ABI.
// SPARK-verified: signal_id valid, fits 32-bit register,
// no data transfer (zero bytes).
//
// Op-Code: 0x09  Category: CORE  Safety: L3

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

extern fn tool_signal__validate(vial: *const VialConstraints, drop: *const Drop) c_int;
extern fn tool_signal__execute(vial: *const VialConstraints, drop: *const Drop) ToolResult;

pub const SIGNAL = struct {
    pub const OP = OpCode.SIGNAL;
    pub const NAME = "SIGNAL";
    pub const DESCRIPTION = "Trigger GPU compute (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 1) return error.InvalidAlignment;

        var vial = VialConstraints{ .aperture_size = 0, .aperture_max = 0, .thermal_halt = 0, .thermal_throttle = 0, .dma_capable = false };
        var drop = Drop{
            .op_kind = 9,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = tool_signal__validate(&vial, &drop);
        return .{
            .allowed = result != 0,
            .injected_operations = &.{},
            .reason = if (result == 0) "SPARK: SIGNAL rejected (invalid signal_id)" else null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        _ = ctx;
        var vial = VialConstraints{ .aperture_size = 0, .aperture_max = 0, .thermal_halt = 0, .thermal_throttle = 0, .dma_capable = false };
        var drop = Drop{
            .op_kind = 9,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = tool_signal__execute(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
