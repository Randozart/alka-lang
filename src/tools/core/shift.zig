const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const SHIFT = struct {
    pub const OP = OpCode.SHIFT;
    pub const NAME = "SHIFT";
    pub const DESCRIPTION = "Remaps a BAR window to a new offset - the sliding window for 256MB aperture bypass";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const offset = operands[0];

        if (offset > ctx.aperture_size and ctx.aperture_size > 0) {
            return interface.ToolInterface.ValidateError.ApertureOverflow;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{"SYNC L1"},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const offset = operands[0];
        
        _ = ctx;
        _ = offset;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 12,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};