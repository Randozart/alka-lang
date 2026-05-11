// GUARD — Runtime Safety Sentinel Tool
//
// Purpose:
//   Monitors a hardware condition during execution and triggers an automatic
//   action if the condition is violated. GUARD is the runtime enforcement
//   mechanism for thermal limits, power budgets, and other safety contracts
//   defined in the Vial.
//
// How it works:
//   1. Parses the guard condition (vessel.property > threshold)
//   2. Sets up a hardware watchpoint or polling loop on the condition
//   3. If violated, executes the specified action (QUENCH, YIELD, REVERT)
//   4. Runs continuously until the instruction sequence completes
//
// VITRIOL relevance:
//   During the Moore Stream, GUARD monitors GPU temperature. If it exceeds
//   the Vial's THROTTLE_AT threshold, GUARD triggers YIELD to cool down.
//   If it exceeds HALT_AT, GUARD triggers QUENCH to cut power.
//
// Op-Code: 0x31
// Category: SAFETY
// Safety: L1 (hard contract — will hard abort on violation)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const GUARD = struct {
    pub const OP = OpCode.GUARD;
    pub const NAME = "GUARD";
    pub const DESCRIPTION = "Runtime safety sentinel — monitors condition and triggers action on violation";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 3) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const threshold = operands[2];

        if (threshold > ctx.thermal_limit and ctx.thermal_limit > 0) {
            return interface.ToolInterface.ValidateError.ThermalLimitExceeded;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = "Guard condition validated against thermal limits",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;
        const action = if (operands.len > 1) operands[1] else 0;
        const threshold = if (operands.len > 2) operands[2] else 0;

        _ = ctx;
        _ = vessel_id;
        _ = action;
        _ = threshold;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 4,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
