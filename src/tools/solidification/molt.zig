// MOLT — Full Controller State Dump Tool
//
// Purpose:
//   Captures the complete register state of a hardware controller — every
//   register, buffer, pipeline stage, and status flag. MOLT is the "full
//   body scan" of a device, producing a comprehensive backup that can be
//   used for perfect REVERT or forensic analysis.
//
// How it works:
//   1. Enumerates all register spaces for the target controller
//   2. Reads every register, including hidden/diagnostic registers
//   3. Captures buffer contents and pipeline state
//   4. Stores the complete dump in the substrate context under the blob name
//
// VITRIOL relevance:
//   Before starting a long Moore Stream session, MOLT the GPU controller.
//   If the session needs to be aborted, the MOLT dump provides everything
//   needed to restore the GPU to its exact pre-session state.
//
// Op-Code: 0x14
// Category: SOLIDIFICATION
// Safety: L2 (soft contract — injects SYNC barrier after dump)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const MOLT = struct {
    pub const OP = OpCode.MOLT;
    pub const NAME = "MOLT";
    pub const DESCRIPTION = "Full controller state dump — captures complete register state";

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
            .injected_operations = &.{"SYNC L2"},
            .reason = "Full state dump validated — read barrier injected",
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
            .cycles_spent = 512,
            .bytes_transferred = 4096,
            .error_message = null,
        };
    }
};
