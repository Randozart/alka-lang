const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const STILL = struct {
    pub const OP = OpCode.STILL;
    pub const NAME = "STILL";
    pub const DESCRIPTION = "Manual DRAM refresh control - stops auto-refresh for precision timing";

    pub const DEFAULT_REFRESH_INTERVAL_US = 64;
    pub const MAX_SAFE_HOLD_US = 500;

    pub fn validate(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const hold_us = if (operands.len > 1) operands[1] else DEFAULT_REFRESH_INTERVAL_US;

        if (hold_us > MAX_SAFE_HOLD_US) {
            return interface.ToolInterface.ValidateError.ThermalLimitExceeded;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "SYNC L3" },
            .reason = std.fmt.allocPrintZ(std.heap.page_allocator, "RAM held still for {}us", .{hold_us}) catch "RAM still",
        };
    }

    pub fn execute(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const hold_us = if (operands.len > 0) operands[0] else DEFAULT_REFRESH_INTERVAL_US;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = hold_us * 1000,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};