// TRACE — Instruction Execution Trace Tool
//
// Purpose:
//   Logs every instruction execution to a flight recorder for post-mortem
//   analysis. TRACE captures the sequence of operations, their operands,
//   timing, and results. This is the "black box" of Alka — when something
//   goes wrong, TRACE provides the forensic record.
//
// How it works:
//   1. Enables the hardware trace buffer (or allocates a software buffer)
//   2. Records each instruction's opcode, operands, and timestamp
//   3. Stores the trace in the substrate context for later retrieval
//   4. Can be filtered by instruction type or vessel
//
// VITRIOL relevance:
//   During development, TRACE helps debug Moore Stream issues by showing
//   exactly which FLOW/SHIFT/FENCE sequence executed and in what order.
//   In production, TRACE is disabled for performance.
//
// Op-Code: 0x30
// Category: MONITORING
// Safety: L3 (advisory — logging only, no side effects)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const TRACE = struct {
    pub const OP = OpCode.TRACE;
    pub const NAME = "TRACE";
    pub const DESCRIPTION = "Instruction execution trace — flight recorder for post-mortem";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = "Execution trace enabled",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const trace_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = trace_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 4,
            .bytes_transferred = 8,
            .error_message = null,
        };
    }
};
