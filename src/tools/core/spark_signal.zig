// SIGNAL — GPU Compute Trigger (SPARK-verified)
//
// Bridges to SPARK Ada tool_signal.adb via C ABI.
//
// HOW IT WORKS:
//   SIGNAL triggers the GPU to begin compute execution with the data that
//   has been loaded into VRAM by preceding FLOW/REFRACT/PIPE operations.
//   It writes a signal ID to a GPU register, which the GPU firmware interprets
//   as a "start computing" command. The signal ID identifies which compute
//   kernel or shader program to launch.
//
//   Validation checks:
//   1. signal_id > 0 (zero is reserved/invalid)
//   2. signal_id <= 0xFFFFFFFF (must fit in a 32-bit GPU register)
//
//   SPARK FORMAL VERIFICATION (gnatprove):
//   - Precondition: Validate returns non-zero only if 0 < signal_id <= 2^32-1
//   - Postcondition: Execute returns Success = True and Bytes_Transferred = 0
//     (SIGNAL is a control operation, no data transfer)
//   - No overflow: signal_id fits in 32 bits, stored in 64-bit field safely
//   - Constant-time: No loops, no branches beyond the validation check
//
//   C ABI BRIDGE:
//   - Ada function: tool_signal__validate(Vial, Drop) -> int (1=pass, 0=fail)
//   - Ada function: tool_signal__execute(Vial, Drop) -> Tool_Result
//   - C wrapper: vitriol_tool_wrapper.c translates GNAT mangled names
//   - Zig wrapper: this file translates ToolInterface -> SPARK Drop/Vial
//
//   CALL FLOW:
//   alkac.zig validateWithTools() -> mod.zig getTool(0x09) ->
//   spark_signal.zig SIGNAL.validate() -> spark_bridge.zig validateSignal() ->
//   vitriol_tool_wrapper.c tool_signal_validate() ->
//   tool_signal.adb tool_signal__validate() [SPARK verified]
//
// Op-Code: 0x09  Category: CORE  Safety: L4

const std = @import("std");
const interface = @import("../interface.zig");
const spark = @import("spark_bridge.zig");

pub const SIGNAL = struct {
    pub const OP = interface.ToolInterface.OpCode.SIGNAL;
    pub const NAME = "SIGNAL";
    pub const DESCRIPTION = "GPU compute trigger (SPARK-verified)";

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
            .op_kind = 9,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = operands[0],
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const ok = spark.validateSignal(&vial, &drop);
        return .{
            .allowed = ok,
            .injected_operations = &.{},
            .reason = if (!ok) "SPARK: SIGNAL rejected (signal_id must be 1..0xFFFFFFFF)" else null,
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
            .op_kind = 9,
            .flags = 0,
            .vessel_id = 0,
            .src_addr = if (operands.len >= 1) operands[0] else 0,
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        };

        const result = spark.executeSignal(&vial, &drop);
        return .{
            .success = result.success,
            .cycles_spent = result.cycles_spent,
            .bytes_transferred = result.bytes_transferred,
            .error_message = null,
        };
    }
};
