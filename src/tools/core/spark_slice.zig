// SLICE — Region Chunker (SPARK-verified)
//
// Bridges to SPARK Ada tool_slice.adb via C ABI.
//
// HOW IT WORKS:
//   SLICE slices large tensors (e.g., 7B-parameter LLM weights = ~14GB)
//   into BAR1-sized chunks for micro-paging through the 256MB sliding window.
//   Since the GTX 960 can only map 256MB of its 2GB VRAM at once, tensors
//   larger than 256MB must be processed in chunks. SLICE calculates how
//   many Drop-sized chunks are needed to cover the full tensor and validates
//   that each chunk fits within the aperture.
//
//   Inputs:
//   - operands[0] (src_addr): Source tensor base address
//   - operands[1] (dst_addr): Total tensor size in bytes
//   - operands[2] (size, optional): Chunk size (defaults to Max_Aperture)
//
//   Validation checks:
//   1. Total tensor size > 0 (non-empty tensor)
//   2. Chunk size > 0 (no zero-length chunks)
//   3. Chunk size <= aperture_max (each chunk fits BAR1 window)
//   4. Chunk_Count(Total, Chunk_Size) * Chunk_Size >= Total
//      (chunks cover the entire tensor with no gaps)
//
//   SPARK FORMAL VERIFICATION (gnatprove):
//   - Precondition: Validate returns non-zero only if all 4 checks pass
//   - Postcondition: Execute returns Bytes_Transferred = Total (full tensor)
//   - Loop termination: Execute contains a while loop with:
//     * Loop_Invariant: Current = I * Chunk_Size (tracks progress)
//     * Loop_Variant: Increases => I (proves I approaches Drops)
//   - Chunk_Count formula: (Total - 1) / Chunk + 1 (ceiling division)
//     Proven: Result >= 1 when Total > 0 and Chunk > 0
//   - No overflow: Uses (Total - 1) instead of (Total + Chunk - 1) to
//     avoid overflow when Total + Chunk would exceed 2^64
//
//   C ABI BRIDGE:
//   - Ada function: tool_slice__validate(Vial, Drop) -> int (1=pass, 0=fail)
//   - Ada function: tool_slice__execute(Vial, Drop) -> Tool_Result
//   - C wrapper: vitriol_tool_wrapper.c translates GNAT mangled names
//   - Zig wrapper: this file translates ToolInterface -> SPARK Drop/Vial
//
//   CALL FLOW:
//   alkac.zig validateWithTools() -> mod.zig getTool(0x3B) ->
//   spark_slice.zig SLICE.validate() -> spark_bridge.zig validateSlice() ->
//   vitriol_tool_wrapper.c tool_slice_validate() ->
//   tool_slice.adb tool_slice__validate() [SPARK verified]
//
// Op-Code: 0x3B  Category: CORE  Safety: L4

const std = @import("std");
const interface = @import("../interface.zig");
const spark = @import("spark_bridge.zig");

pub const SLICE = struct {
    pub const OP = interface.ToolInterface.OpCode.SLICE;
    pub const NAME = "SLICE";
    pub const DESCRIPTION = "Split region into chunks (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 2) return error.InvalidAlignment;

        var vial = spark.VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_max,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 0x3B,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = operands[1],
            .size = if (operands.len >= 3) @truncate(operands[2]) else 0,
            .reserved = 0,
            .crc = 0,
        };

        const ok = spark.validateSlice(&vial, &drop);
        return .{
            .allowed = ok,
            .injected_operations = &.{},
            .reason = if (!ok) "SPARK: SLICE rejected (tensor size zero or chunk exceeds aperture)" else null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        var vial = spark.VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_max,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 0x3B,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = if (operands.len >= 2) operands[1] else 0,
            .size = if (operands.len >= 3) @truncate(operands[2]) else 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = spark.executeSlice(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
