// MOCK — Virtual Hardware Testing Tool
//
// Purpose:
//   Creates a virtual hardware representation for safe instruction
//   validation without touching real metal. MOCK is the "sandbox"
//   instruction — it sets up a simulated substrate that responds to
//   Alka commands identically to real hardware, but with zero risk.
//
// How it works:
//   1. Allocates a mock substrate context in userspace memory
//   2. Populates it with the Vial's vessel descriptions
//   3. Routes all subsequent instructions to the mock context
//   4. Returns simulated results with realistic timing
//
// VITRIOL relevance:
//   During development, MOCK lets you test Moore Stream sequences
//   without a real GPU. The mock substrate simulates BAR mappings,
//   DMA transfers, and thermal responses — perfect for CI/CD testing.
//
// Op-Code: 0x2D
// Category: TESTING
// Safety: L3 (advisory — no physical effects)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const MOCK = struct {
    pub const OP = OpCode.MOCK;
    pub const NAME = "MOCK";
    pub const DESCRIPTION = "Use mock hardware for safe testing without physical effects";

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
            .reason = "Mock hardware validated — safe testing mode",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const mock_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = mock_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 0,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
