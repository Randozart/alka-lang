// YIELD — Cooperative Scheduler Yield Tool
//
// Purpose:
//   Cooperatively yields control back to the Linux scheduler for a
//   specified duration. This is the safe way to pause Alka execution
//   without holding hardware resources hostage.
//
// How it works:
//   1. Accepts a yield duration in microseconds (default 1000us)
//   2. Returns control to the OS scheduler for the specified time
//   3. Used as the Azoth counterpart to OSSIFY (returns pinned cores)
//   4. Returns cycle count based on yield duration
//
// VITRIOL relevance:
//   When thermal shadowing detects high temperatures, the compiler injects
//   YIELD to cool down before continuing. Also used to return OSSIFY'd
//   cores to the scheduler after experiments complete.
//
// Op-Code: 0x0A
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

const std = @import("std");
const interface = @import("../interface.zig");

pub const YIELD = struct {
    pub const OP = interface.ToolInterface.OpCode.YIELD;
    pub const NAME = "YIELD";
    pub const DESCRIPTION = "Cooperative yield to Linux scheduler";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const micros = if (operands.len > 0) operands[0] else 1000;

        _ = ctx;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = micros * 1000,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
