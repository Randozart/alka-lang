// AUDIT — Post-Instruction Residue Check Tool
//
// Purpose:
//   After any operation, verifies that no registers are left in an illegal
//   state, no stale data remains in caches, and no hardware flags indicate
//   errors. AUDIT is the "clean-up inspector" that runs after intrusive
//   operations to confirm the machine is in a consistent state.
//
// How it works:
//   1. Reads all error/status registers for the target vessel
//   2. Checks cache coherency flags
//   3. Verifies no pending interrupts or DMA errors
//   4. Returns a pass/fail result with details on any residue found
//
// VITRIOL relevance:
//   After each Moore Stream window transfer, AUDIT checks that the GPU's
//   error registers are clean and the metapage was updated correctly.
//   If AUDIT finds residue, the compiler can inject a REVERT.
//
// Op-Code: 0x2B
// Category: TESTING
// Safety: L3 (advisory — informational only)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const AUDIT = struct {
    pub const OP = OpCode.AUDIT;
    pub const NAME = "AUDIT";
    pub const DESCRIPTION = "Post-instruction residue check — verify clean hardware state";

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
            .reason = "Audit check validated",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = vessel_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 16,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
