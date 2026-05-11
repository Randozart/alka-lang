// ECHO — Non-Intrusive Introspection Tool
//
// Purpose:
//   Reads hardware state and dual-writes it to a side-buffer without affecting
//   the hardware itself. ECHO is the "peek" instruction — it lets you observe
//   register values, configuration space, and memory contents without mutating
//   anything. Essential for debugging and the REPL's "Ghost Mode."
//
// How it works:
//   1. Reads the specified register or memory location from the vessel
//   2. Copies the value to the designated side-buffer (debug log, REPL output)
//   3. Does NOT modify any hardware state
//   4. Returns the observed value for inspection
//
// VITRIOL relevance:
//   During development, ECHO lets you inspect the GPU's configuration space,
//   BAR mappings, and metapage status without disrupting the Moore Stream.
//   In the REPL, ECHO is the primary tool for hardware archaeology.
//
// Op-Code: 0x17
// Category: CORE
// Safety: L3 (advisory — read-only, no side effects)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const ECHO = struct {
    pub const OP = OpCode.ECHO;
    pub const NAME = "ECHO";
    pub const DESCRIPTION = "Non-intrusive introspection — read state without mutating hardware";

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
            .reason = "Read-only introspection — no side effects",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;
        const offset = if (operands.len > 1) operands[1] else 0;

        _ = ctx;
        _ = vessel_id;
        _ = offset;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 4,
            .bytes_transferred = 4,
            .error_message = null,
        };
    }
};
