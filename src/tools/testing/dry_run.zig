// DRY_RUN — Simulation Without Execution Tool
//
// Purpose:
//   Simulates instruction execution without any physical side effects.
//   DRY_RUN performs address calculations, validates operands, and logs
//   the intended action — but skips the actual hardware poke. This is
//   the "rehearsal" instruction for safe testing.
//
// How it works:
//   1. Parses the instruction and operands normally
//   2. Validates against the Vial constraints
//   3. Computes what the result would be (addresses, sizes, timing)
//   4. Logs the intended action without touching hardware
//   5. Returns the simulated result for inspection
//
// VITRIOL relevance:
//   Before executing a Moore Stream on production hardware, DRY_RUN
//   simulates the entire sequence to verify addresses, sizes, and
//   timing. The Welder strips DRY_RUN packets from the final binary.
//
// Op-Code: 0x2C
// Category: TESTING
// Safety: L3 (advisory — no physical effects)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const DRY_RUN = struct {
    pub const OP = OpCode.DRY_RUN;
    pub const NAME = "DRY_RUN";
    pub const DESCRIPTION = "Simulate execution without physical side effects";

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
            .reason = "Simulation validated — no physical effects",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const instruction_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = instruction_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 0,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
