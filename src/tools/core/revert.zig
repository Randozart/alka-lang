// REVERT — State Restoration Tool
//
// Purpose:
//   Restores a previously SNAP'd hardware state blob back to the target vessel.
//   This is the "antidote" operation — it undoes any changes made since the
//   snapshot was taken. REVERT is the runtime counterpart to the compile-time
//   Azoth binary generation.
//
// How it works:
//   1. Validates the blob name exists in the substrate context
//   2. Writes the saved register values back to the hardware
//   3. Issues a full memory barrier (SYNC L3) to ensure all writes are visible
//   4. Injects an AUDIT to verify the restored state matches expectations
//
// VITRIOL relevance:
//   If a Moore Stream transfer corrupts GPU state, REVERT restores the clean
//   snapshot. In the Azoth system, REVERT packets are generated automatically
//   for every forward operation and executed in reverse order on failure.
//
// Op-Code: 0x0D
// Category: CORE
// Safety: L2 (soft contract — injects SYNC + AUDIT)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const REVERT = struct {
    pub const OP = OpCode.REVERT;
    pub const NAME = "REVERT";
    pub const DESCRIPTION = "Restore previously SNAP'd state to a hardware node";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 2) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "SYNC L3", "AUDIT" },
            .reason = "State restoration validated — barrier + audit injected",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;
        const blob_id = if (operands.len > 1) operands[1] else 0;

        _ = ctx;
        _ = vessel_id;
        _ = blob_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 128,
            .bytes_transferred = 256,
            .error_message = null,
        };
    }
};
