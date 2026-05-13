// FENCE — Metapage Completion Poll (SPARK-verified)
//
// Bridges to SPARK Ada tool_fence.adb via C ABI.
//
// HOW IT WORKS:
//   FENCE polls a GPU metapage register until it reaches an expected value,
//   serving as a hardware synchronization barrier. After issuing DMA transfers
//   (FLOW) or compute commands (SIGNAL), the GPU writes a completion marker
//   to a known memory location (the "metapage"). FENCE reads this location
//   in a bounded loop until the marker appears or a timeout expires.
//
//   The timeout is specified in microseconds via operands[0] (src_addr).
//   Validation checks:
//   1. Timeout > 0 (must wait at least 1 microsecond)
//   2. Timeout <= 10,000,000 (max 10 seconds — prevents infinite hangs)
//
//   SPARK FORMAL VERIFICATION (gnatprove):
//   - Precondition: Validate returns non-zero only if 0 < timeout <= 10,000,000
//   - Postcondition: Execute returns Success = True and Bytes_Transferred = 0
//   - Loop termination: Loop variant (Increases => Elapsed) proves the poll
//     loop always terminates because Elapsed increases by Poll_Step (100us)
//     each iteration and is bounded by Timeout_Us
//   - No overflow: Elapsed + Poll_Step cannot overflow within 10-second bound
//
//   C ABI BRIDGE:
//   - Ada function: tool_fence__validate(Vial, Drop) -> int (1=pass, 0=fail)
//   - Ada function: tool_fence__execute(Vial, Drop) -> Tool_Result
//   - C wrapper: vitriol_tool_wrapper.c translates GNAT mangled names
//   - Zig wrapper: this file translates ToolInterface -> SPARK Drop/Vial
//
//   CALL FLOW:
//   alkac.zig validateWithTools() -> mod.zig getTool(0x05) ->
//   spark_fence.zig FENCE.validate() -> spark_bridge.zig validateFence() ->
//   vitriol_tool_wrapper.c tool_fence_validate() ->
//   tool_fence.adb tool_fence__validate() [SPARK verified]
//
// Op-Code: 0x05  Category: CORE  Safety: L4

const std = @import("std");
const interface = @import("../interface.zig");
const spark = @import("spark_bridge.zig");

pub const FENCE = struct {
    pub const OP = interface.ToolInterface.OpCode.FENCE;
    pub const NAME = "FENCE";
    pub const DESCRIPTION = "Wait for metapage (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) return error.InvalidAlignment;

        var vial = spark.VialConstraints{
            .aperture_size = 0,
            .aperture_max = 0,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 5,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const ok = spark.validateFence(&vial, &drop);
        return .{
            .allowed = ok,
            .injected_operations = &.{},
            .reason = if (!ok) "SPARK: FENCE rejected (timeout must be 1us..10s)" else null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        var vial = spark.VialConstraints{
            .aperture_size = 0,
            .aperture_max = 0,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 5,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = spark.executeFence(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
