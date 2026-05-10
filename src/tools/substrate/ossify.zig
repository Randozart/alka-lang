const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const OSSIFY = struct {
    pub const OP = OpCode.OSSIFY;
    pub const NAME = "OSSIFY";
    pub const DESCRIPTION = "Pins a CPU core to Alka code, bypassing the Linux scheduler entirely";

    pub fn validate(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const core_id = operands[0];
        if (core_id > 3) {
            return interface.ToolInterface.ValidateError.VesselNotFound;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "CLAIM CPU_CORE", "SYNC L1" },
            .reason = "Core pinned - OS scheduler bypassed",
        };
    }

    pub fn execute(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const core_id = if (operands.len > 0) operands[0] else 0;
        _ = core_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 100,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};