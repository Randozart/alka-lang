const std = @import("std");
const binder = @import("bind/binder.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len < 3) {
        std.debug.print("VITRIOL BIND — PCIe Device Seizure Tool\n\n", .{});
        std.debug.print("Usage:\n", .{});
        std.debug.print("  vitriol-bind <bdf>              Unbind from driver, bind to vfio-pci\n", .{});
        std.debug.print("  vitriol-bind <bdf> --force      Hot-remove + rescan (nuclear option)\n", .{});
        std.debug.print("  vitriol-bind <bdf> --restore    Restore previous driver\n", .{});
        std.debug.print("  vitriol-bind <bdf> --status     Show current driver\n", .{});
        std.debug.print("\nExamples:\n", .{});
        std.debug.print("  vitriol-bind 0000:01:00.0           # Unbind GPU from nvidia, bind to vfio\n", .{});
        std.debug.print("  vitriol-bind 0000:01:00.0 --force   # Force-seize GPU\n", .{});
        std.debug.print("  vitriol-bind 0000:01:00.0 --status  # Check who owns the GPU\n", .{});
        return;
    }

    const bdf = args[1];
    const mode = if (args.len >= 3) args[2] else "bind";

    if (std.mem.eql(u8, mode, "--status")) {
        const driver = binder.findDriver(allocator, bdf) catch |err| {
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            return;
        };
        if (driver) |d| {
            std.debug.print("{s} → {s}\n", .{ bdf, d });
        } else {
            std.debug.print("{s} → no driver\n", .{bdf});
        }
        return;
    }

    if (std.mem.eql(u8, mode, "--restore")) {
        if (args.len < 4) {
            std.debug.print("Usage: vitriol-bind <bdf> --restore <driver_name>\n", .{});
            return;
        }
        const prev_driver = args[3];
        const result = binder.restoreDriver(allocator, bdf, prev_driver);
        if (result.success) {
            std.debug.print("✓ {s} restored to {s}\n", .{ bdf, prev_driver });
        } else {
            std.debug.print("✗ {s}: {s}\n", .{ bdf, result.error_msg orelse "unknown error" });
        }
        return;
    }

    const force = std.mem.eql(u8, mode, "--force");
    const result = binder.bindDevice(allocator, bdf, force);

    if (result.success) {
        if (force) {
            std.debug.print("✓ {s} force-bound (hot-remove + rescan)\n", .{bdf});
        } else {
            const prev = result.previous_driver orelse "unknown";
            std.debug.print("✓ {s} unbound from {s}, bound to vfio-pci\n", .{ bdf, prev });
        }
    } else {
        std.debug.print("✗ {s}: {s}\n", .{ bdf, result.error_msg orelse "unknown error" });
        if (!force) {
            std.debug.print("  Tip: try --force if the driver resists\n", .{});
        }
    }
}
