pub const claim = @import("core/claim.zig");
pub const flow = @import("core/flow.zig");
pub const shift = @import("core/shift.zig");
pub const misc = @import("core/misc.zig");

pub const Tool = struct {
    pub const Context = @import("interface.zig").ToolInterface.Context;
    pub const Result = @import("interface.zig").ToolInterface.Result;
    pub const ValidateResult = @import("interface.zig").ToolInterface.ValidateResult;
    pub const ValidateError = @import("interface.zig").ToolInterface.ValidateError;

    pub const ValidateFn = fn (operands: []const u64, ctx: Context) ValidateError!ValidateResult;
    pub const ExecuteFn = fn (operands: []const u64, ctx: Context) Result;

    name: []const u8,
    description: []const u8,
    validate: ValidateFn,
    execute: ExecuteFn,
};

pub fn getTool(op_code: u8) ?Tool {
    return switch (op_code) {
        0x01 => Tool{ .name = "CLAIM", .description = "Stake hardware node", .validate = claim.CLAIM.validate, .execute = claim.CLAIM.execute },
        0x03 => Tool{ .name = "FLOW", .description = "DMA transfer", .validate = flow.FLOW.validate, .execute = flow.FLOW.execute },
        0x04 => Tool{ .name = "SHIFT", .description = "Remap BAR window", .validate = shift.SHIFT.validate, .execute = shift.SHIFT.execute },
        0x05 => Tool{ .name = "FENCE", .description = "Wait for condition", .validate = misc.FENCE.validate, .execute = misc.FENCE.execute },
        0x06 => Tool{ .name = "SYNC", .description = "Memory barrier", .validate = misc.SYNC.validate, .execute = misc.SYNC.execute },
        0x07 => Tool{ .name = "SENSE", .description = "Read sensor", .validate = misc.SENSE.validate, .execute = misc.SENSE.execute },
        0x09 => Tool{ .name = "SIGNAL", .description = "Trigger interrupt", .validate = misc.SIGNAL.validate, .execute = misc.SIGNAL.execute },
        0x0A => Tool{ .name = "YIELD", .description = "Cooperative yield", .validate = misc.YIELD.validate, .execute = misc.YIELD.execute },
        else => null,
    };
}