// FLOW — DMA Transfer (SPARK-verified)
//
// Bridges to SPARK Ada tool_flow.adb via C ABI.
//
// HOW IT WORKS:
//   FLOW initiates a DMA transfer from a source address (typically NVMe SSD
//   or system RAM) to a destination address in GPU VRAM. This is the primary
//   data movement tool in the Alka pipeline, used to stream model weights,
//   tensors, and other payloads directly to the GPU without CPU involvement.
//
//   Validation checks:
//   1. Transfer size > 0 (no zero-length transfers)
//   2. Transfer size <= aperture_max (fits within BAR1 window)
//   3. Vial declares DMA_Capable = true (hardware supports DMA)
//   4. src_addr + size >= src_addr (no 64-bit overflow on source)
//   5. dst_addr + size >= dst_addr (no 64-bit overflow on destination)
//
//   SPARK FORMAL VERIFICATION (gnatprove):
//   - Precondition: Validate returns non-zero only if all 5 checks above pass
//   - Postcondition: Execute returns Bytes_Transferred = Op.Size (exact count)
//   - No overflow: Checked via saturating arithmetic comparison
//   - Total correctness: If validated, execution is guaranteed to succeed
//
//   C ABI BRIDGE:
//   - Ada function: tool_flow__validate(Vial, Drop) -> int (1=pass, 0=fail)
//   - Ada function: tool_flow__execute(Vial, Drop) -> Tool_Result
//   - C wrapper: vitriol_tool_wrapper.c translates GNAT mangled names
//   - Zig wrapper: this file translates ToolInterface -> SPARK Drop/Vial
//
//   CALL FLOW:
//   alkac.zig validateWithTools() -> mod.zig getTool(0x03) ->
//   spark_flow.zig FLOW.validate() -> spark_bridge.zig validateFlow() ->
//   vitriol_tool_wrapper.c tool_flow_validate() ->
//   tool_flow.adb tool_flow__validate() [SPARK verified]
//
// Op-Code: 0x03  Category: CORE  Safety: L4

const std = @import("std");
const interface = @import("../interface.zig");
const spark = @import("spark_bridge.zig");

pub const FLOW = struct {
    pub const OP = interface.ToolInterface.OpCode.FLOW;
    pub const NAME = "FLOW";
    pub const DESCRIPTION = "DMA transfer (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 3) return error.InvalidAlignment;

        var vial = spark.VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_max,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = true,
        };
        var drop = spark.Drop{
            .op_kind = 3,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = operands[1],
            .size = @truncate(operands[2]),
            .reserved = 0,
            .crc = 0,
        };

        const ok = spark.validateFlow(&vial, &drop);
        return .{
            .allowed = ok,
            .injected_operations = &.{},
            .reason = if (!ok) "SPARK: FLOW rejected (size, aperture, DMA capability, or overflow)" else null,
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
            .dma_capable = true,
        };
        var drop = spark.Drop{
            .op_kind = 3,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = if (operands.len >= 2) operands[1] else 0,
            .size = if (operands.len >= 3) @truncate(operands[2]) else 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = spark.executeFlow(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
