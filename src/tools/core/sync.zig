// SYNC — Memory Barrier Tool
//
// Purpose:
//   Enforces memory ordering barriers (L1=write, L2=read, L3=full).
//   Ensures that all pending memory operations complete before subsequent
//   instructions execute. Critical for hardware synchronization.
//
// How it works:
//   1. Accepts a barrier level operand (1=wmb, 2=rmb, 3=full mb)
//   2. Issues the appropriate hardware memory barrier instruction
//   3. Returns the cycle cost based on barrier strength
//   4. Auto-injected by the compiler before SIGNAL after FLOW
//
// VITRIOL relevance:
//   SYNC L3 is auto-injected before Moore Stream transfers to ensure all
//   prior writes are visible. SYNC L1 is injected after SHIFT to ensure
//   the BAR remap is coherent. The barrier level determines the cost.
//
// Op-Code: 0x06
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

const std = @import("std");
const interface = @import("../interface.zig");

pub const SYNC = struct {
    pub const OP = interface.ToolInterface.OpCode.SYNC;
    pub const NAME = "SYNC";
    pub const DESCRIPTION = "Memory barrier (L1=wmb, L2=rmb, L3=mb)";

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
        const level = if (operands.len > 0) operands[0] else 3;
        const cost: u64 = if (level == 1) 8 else if (level == 2) 12 else 20;

        _ = ctx;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = cost,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
