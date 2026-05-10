const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const OCCUPY = struct {
    pub const OP = OpCode.OCCUPY;
    pub const NAME = "OCCUPY";
    pub const DESCRIPTION = "Seize PCIe device - sever all OS access to the device";

    pub fn validate(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "CLAIM DEVICE", "SYNC L1", "STASIS ROOT_COMPLEX" },
            .reason = "Device seized - OS access severed via PCIe ACS",
        };
    }

    pub fn execute(
        operands: []const u64,
        _: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const device_id = if (operands.len > 0) operands[0] else 0;
        _ = device_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 200,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};