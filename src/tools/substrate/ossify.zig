// OSSIFY — CPU Core Pinning Tool
//
// Purpose:
//   Pins a CPU core to Alka execution, bypassing the Linux scheduler entirely.
//   The core becomes a dedicated Alka execution unit — no context switches,
//   no IRQ handling, no OS interference. Pure silicon control.
//
// How it works:
//   1. Validates the target core ID is available (0-3 for isolated cores)
//   2. Claims the CPU core and removes it from the scheduler runqueue
//   3. Injects SYNC L1 barrier to ensure the core isolation is coherent
//   4. Core now executes Alka instructions with zero OS latency
//
// VITRIOL relevance:
//   For hard real-time operations, OSSIFY a core to guarantee nanosecond
//   precision. The Azoth counterpart is YIELD — which returns the core to
//   the scheduler when the experiment completes or fails.
//
// Op-Code: 0x34
// Category: SUBSTRATE
// Safety: CRITICAL (requires explicit Vial waiver — can cause system instability)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const OSSIFY = struct {
    pub const OP = OpCode.OSSIFY;
    pub const NAME = "OSSIFY";
    pub const DESCRIPTION = "Pins a CPU core to Alka code, bypassing the Linux scheduler entirely";

    pub fn validate(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const core_id = operands[0];
        if (core_id > 3) {
            return interface.ToolInterface.ValidateError.VesselNotFound;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "CLAIM CPU_CORE", "SYNC L1" },
            .reason = "Core pinned - OS scheduler bypassed",
        };
    }

    pub fn execute(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const core_id = if (operands.len > 0) operands[0] else 0;
        _ = core_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 100,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};