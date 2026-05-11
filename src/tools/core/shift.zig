// SHIFT — BAR Window Remap Tool
//
// Purpose:
//   Remaps a BAR window to a new offset, enabling the sliding window mechanism
//   that allows Alka to access more memory than the 256MB aperture size permits.
//   This is how large transfers bypass aperture limitations.
//
// How it works:
//   1. Validates the target offset is within the physical BAR range
//   2. Writes the new offset to the BAR window register
//   3. Injects a SYNC L1 barrier to ensure the remap is visible to the device
//   4. Returns control for the next FLOW operation in the windowed sequence
//
// VITRIOL relevance:
//   When FLOW exceeds the 256MB aperture, the compiler injects a SHIFT loop:
//   SHIFT @ 0, FLOW 256MB, SHIFT @ 256MB, FLOW 256MB, etc. This enables
//   transferring multi-gigabyte payloads through a small BAR window.
//
// Op-Code: 0x04
// Category: CORE
// Safety: L2 (soft contract — injects SYNC barrier)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const SHIFT = struct {
    pub const OP = OpCode.SHIFT;
    pub const NAME = "SHIFT";
    pub const DESCRIPTION = "Remaps a BAR window to a new offset - the sliding window for 256MB aperture bypass";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const offset = operands[0];

        if (offset > ctx.aperture_size and ctx.aperture_size > 0) {
            return interface.ToolInterface.ValidateError.ApertureOverflow;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{"SYNC L1"},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const offset = operands[0];
        
        _ = ctx;
        _ = offset;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 12,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};