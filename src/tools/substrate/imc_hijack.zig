const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const IMC_HIJACK = struct {
    pub const OP = OpCode.IMC_HIJACK;
    pub const NAME = "IMC_HIJACK";
    pub const DESCRIPTION = "Direct access to Ivy Bridge Memory Controller registers (MCHBAR)";

    pub const MCHBAR_BASE = 0xFED10000;
    pub const T_REFI_OFFSET = 0x4000;
    pub const CMD_OFFSET = 0x4004;

    pub const Command = enum(u8) {
        PAUSE_REFRESH = 0,
        FORCE_REFRESH = 1,
        RESTORE = 2,
    };

    pub fn validate(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "CLAIM SYSTEM_BUS" },
            .reason = "IMC registers mapped",
        };
    }

    pub fn execute(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const cmd = if (operands.len > 0) operands[0] else 0;

        var msg: []const u8 = undefined;
        switch (cmd) {
            0 => msg = "DRAM refresh paused - bus is PURE",
            1 => msg = "Immediate refresh triggered",
            else => msg = "IMC restored to auto-refresh",
        }

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 25,
            .bytes_transferred = 0,
            .error_message = msg,
        };
    }
};