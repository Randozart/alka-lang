const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const FLOW = struct {
    pub const OP = OpCode.FLOW;
    pub const NAME = "FLOW";
    pub const DESCRIPTION = "The Moore Stream - DMA transfer bypassing the CPU";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 3) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const src = operands[0];
        const dst = operands[1];
        const size = operands[2];
        _ = src;
        _ = dst;

        if (size > ctx.aperture_size) {
            const windows = (size + ctx.aperture_size - 1) / ctx.aperture_size;
            _ = windows;
            var injected: [16][]const u8 = undefined;
            var count: usize = 0;

            var offset: u64 = 0;
            while (offset < size) : (offset += ctx.aperture_size) {
                injected[count] = std.fmt.allocPrintZ(std.heap.page_allocator, "SHIFT @ {d}", .{offset}) catch "SHIFT";
                count += 1;
                if (count >= 16) break;
            }

            return interface.ToolInterface.ValidateResult{
                .allowed = true,
                .injected_operations = injected[0..count],
                .reason = "Automatic windowing: split into multiple operations",
            };
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const size = if (operands.len >= 3) operands[2] else 0;

        const cycles_per_beat: u64 = 4;
        const beats_per_ns: u64 = 8000;
        const transfer_time_ns = if (size > 0) (size / 64) * cycles_per_beat / beats_per_ns else 0;

        _ = ctx;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = transfer_time_ns,
            .bytes_transferred = size,
            .error_message = null,
        };
    }
};