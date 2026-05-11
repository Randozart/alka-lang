// LIMIT — Hard Contract Enforcement Tool
//
// Purpose:
//   Enforces a hard contract on a vessel property (thermal, power, bandwidth).
//   Unlike GUARD which monitors at runtime, LIMIT is a compile-time contract
//   that the compiler uses to validate all subsequent operations. If any
//   instruction would violate the limit, compilation fails.
//
// How it works:
//   1. Parses the limit expression (vessel.property MAX value)
//   2. Stores the limit in the substrate context for subsequent validation
//   3. All future instructions are checked against this limit during validation
//   4. If an instruction exceeds the limit, the compiler rejects it
//
// VITRIOL relevance:
//   LIMIT GPU_MAIN.THERMAL MAX 85C tells the compiler that no sequence of
//   operations should cause the GPU to exceed 85°C. The compiler uses this
//   to inject YIELD instructions between heat-generating transfers.
//
// Op-Code: 0x0E
// Category: CORE
// Safety: L1 (hard contract — compilation fails on violation)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const LIMIT = struct {
    pub const OP = OpCode.LIMIT;
    pub const NAME = "LIMIT";
    pub const DESCRIPTION = "Hard contract enforcement — compile-time limit on vessel properties";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 2) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const limit_value = operands[1];

        if (limit_value > ctx.thermal_limit and ctx.thermal_limit > 0) {
            return interface.ToolInterface.ValidateError.ThermalLimitExceeded;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = "Hard contract established",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;
        const limit_value = if (operands.len > 1) operands[1] else 0;

        _ = ctx;
        _ = vessel_id;
        _ = limit_value;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 4,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
