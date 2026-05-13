// SHIFT — BAR Window Remapping (SPARK-verified)
//
// Bridges to SPARK Ada tool_shift.adb via C ABI.
//
// HOW IT WORKS:
//   SHIFT remaps the GPU's BAR1 sliding window to a new offset within the
//   256MB BAR1 aperture. GPUs with limited BAR1 mappable space (like the
//   GTX 960 with only 256MB BAR1 for 2GB VRAM) use a sliding window approach:
//   the kernel maps a small portion of VRAM at a time by changing the BAR
//   offset register. This tool validates that:
//
//   1. The requested offset does not exceed the BAR1 aperture (256MB max)
//   2. The offset is page-aligned (4KB boundary) — required by ioremap()
//   3. The window fits within the physical BAR range
//
//   SPARK FORMAL VERIFICATION (gnatprove):
//   - Precondition: Validate returns non-zero only if offset <= Max_Aperture
//     AND offset is 4KB-aligned (offset & 0xFFF == 0)
//   - Postcondition: Execute always succeeds (Result.Success = True) when
//     called with validated input
//   - Loop-free: No iteration, constant-time validation
//   - No overflow: Uses Interfaces.Unsigned_64 arithmetic, no wrap-around
//
//   C ABI BRIDGE:
//   - Ada function: tool_shift__validate(Vial, Drop) -> int (1=pass, 0=fail)
//   - Ada function: tool_shift__execute(Vial, Drop) -> Tool_Result
//   - C wrapper: vitriol_tool_wrapper.c translates GNAT mangled names
//   - Zig wrapper: this file translates ToolInterface -> SPARK Drop/Vial
//
//   CALL FLOW:
//   alkac.zig validateWithTools() -> mod.zig getTool(0x04) ->
//   spark_shift.zig SHIFT.validate() -> spark_bridge.zig validateShift() ->
//   vitriol_tool_wrapper.c tool_shift_validate() ->
//   tool_shift.adb tool_shift__validate() [SPARK verified]
//
// Op-Code: 0x04  Category: CORE  Safety: L4

const std = @import("std");
const interface = @import("../interface.zig");
const spark = @import("spark_bridge.zig");

pub const SHIFT = struct {
    pub const OP = interface.ToolInterface.OpCode.SHIFT;
    pub const NAME = "SHIFT";
    pub const DESCRIPTION = "Remap BAR window offset (SPARK-verified)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) return error.InvalidAlignment;

        var vial = spark.VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_size,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 4,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const ok = spark.validateShift(&vial, &drop);
        return .{
            .allowed = ok,
            .injected_operations = &.{},
            .reason = if (!ok) "SPARK: SHIFT rejected (offset exceeds aperture or not 4KB-aligned)" else null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        var vial = spark.VialConstraints{
            .aperture_size = ctx.aperture_size,
            .aperture_max = ctx.aperture_size,
            .thermal_halt = @truncate(ctx.thermal_limit),
            .thermal_throttle = @truncate(ctx.thermal_limit),
            .dma_capable = false,
        };
        var drop = spark.Drop{
            .op_kind = 4,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = spark.executeShift(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
