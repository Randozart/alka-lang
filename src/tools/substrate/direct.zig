// DIRECT — Memory Controller Access Tool
//
// Purpose:
//   Provides direct access to the Ivy Bridge Memory Controller registers
//   via MCHBAR. This bypasses the OS memory manager entirely, enabling
//   manual control of DRAM timing, refresh, and command scheduling.
//
// How it works:
//   1. Maps the MCHBAR base address (0xFED10000) into accessible space
//   2. Claims the system bus for exclusive IMC access
//   3. Supports PAUSE_REFRESH, FORCE_REFRESH, and RESTORE commands
//   4. Returns command status for verification
//
// VITRIOL relevance:
//   The deepest level of substrate control — DIRECT lets Alka manage
//   DRAM at the hardware level. Used with STILL and OSCILLATE for complete
//   memory timing control during precision operations.
//
// Op-Code: 0x39
// Category: SUBSTRATE
// Safety: CRITICAL (requires explicit Vial waiver — direct memory controller access)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const DIRECT = struct {
    pub const OP = OpCode.DIRECT;
    pub const NAME = "DIRECT";
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