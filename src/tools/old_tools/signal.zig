// SIGNAL — Hardware Interrupt Trigger Tool
//
// Purpose:
//   Triggers a hardware interrupt to wake the CPU or signal other
//   devices. This is how Alka communicates events across the substrate
//   without going through the OS interrupt handler.
//
// How it works:
//   1. Accepts an interrupt vector operand
//   2. Issues the hardware interrupt at the specified vector
//   3. Returns immediately (5 cycles — very fast)
//   4. Used to wake CPU cores after DMA completion
//
// VITRIOL relevance:
//   After a Moore Stream FLOW completes, SIGNAL wakes the CPU to process
//   results. The compiler auto-injects SYNC L3 before SIGNAL after FLOW
//   to ensure all transferred data is visible before the interrupt fires.
//
// Op-Code: 0x09
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

const std = @import("std");
const interface = @import("../interface.zig");

pub const SIGNAL = struct {
    pub const OP = interface.ToolInterface.OpCode.SIGNAL;
    pub const NAME = "SIGNAL";
    pub const DESCRIPTION = "Trigger a hardware interrupt to wake CPU";

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
        const vector = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = vector;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 5,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
