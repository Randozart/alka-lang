// SUSPEND — Manual DRAM Refresh Control Tool
//
// Purpose:
//   Takes over DRAM refresh cycles from the memory controller, enabling
//   precision timing by stopping auto-refresh during critical operations.
//   This creates "pure execution windows" where bus timing is deterministic.
//
// How it works:
//   1. Validates the hold duration is within safe limits (max 500us)
//   2. Pauses the automatic DRAM refresh for the specified bank
//   3. Injects SYNC L3 to ensure all pending writes complete before the hold
//   4. Restores auto-refresh after the hold period expires
//
// VITRIOL relevance:
//   Used in substrate orchestration to create timing-isolated windows. When
//   DRAM refresh is paused, the memory bus becomes deterministic — essential
//   for nanosecond-precision operations and side-channel measurements.
//
// Op-Code: 0x36
// Category: SUBSTRATE
// Safety: CRITICAL (requires explicit Vial waiver — data loss if held too long)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const SUSPEND = struct {
    pub const OP = OpCode.SUSPEND;
    pub const NAME = "SUSPEND";
    pub const DESCRIPTION = "Pause auto-behavior of subsystem - stops auto-refresh for precision timing";

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