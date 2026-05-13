const std = @import("std");

pub const BindError = error{
    NoPermission,
    DeviceNotFound,
    UnbindFailed,
    BindFailed,
    HotRemoveFailed,
    RescanFailed,
    InvalidBdf,
    IoError,
    BufferTooSmall,
};

const SYSFS_PCI = "/sys/bus/pci";
const SYSFS_DEVICES = "/sys/bus/pci/devices";
const SYSFS_DRIVERS = "/sys/bus/pci/drivers";
const PCI_RESCAN = "/sys/bus/pci/rescan";

pub const BindResult = struct {
    success: bool,
    previous_driver: ?[]const u8,
    error_msg: ?[]const u8,
};

/// Find which driver currently owns a device by BDF (e.g. "0000:01:00.0")
pub fn findDriver(allocator: std.mem.Allocator, bdf: []const u8) !?[]const u8 {
    var path_buf: [512]u8 = undefined;
    var link_buf: [4096]u8 = undefined;
    const driver_link = try formatBuf(&path_buf, "{s}/{s}/driver", .{ SYSFS_DEVICES, bdf });

    const link_target = std.fs.readLinkAbsolute(driver_link, &link_buf) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return error.DeviceNotFound,
    };

    if (std.mem.lastIndexOfScalar(u8, link_target, '/')) |slash| {
        return try allocator.dupe(u8, link_target[slash + 1 ..]);
    }
    return null;
}

/// Unbind a device from its current driver via sysfs
pub fn unbindFromDriver(bdf: []const u8) BindError!void {
    const driver_name = findDriver(std.heap.page_allocator, bdf) catch null;
    if (driver_name) |name| {
        defer std.heap.page_allocator.free(name);
        var buf: [512]u8 = undefined;
        const unbind_path = formatBuf(&buf, "{s}/{s}/unbind", .{ SYSFS_DRIVERS, name }) catch return error.IoError;
        writeToFile(unbind_path, bdf) catch return error.UnbindFailed;
    }
}

/// Bind a device to the vfio-pci driver
pub fn bindToVfio(bdf: []const u8) BindError!void {
    var buf_a: [512]u8 = undefined;
    var buf_b: [512]u8 = undefined;
    const new_id_path = formatBuf(&buf_a, "{s}/vfio-pci/new_id", .{ SYSFS_DRIVERS }) catch return error.IoError;
    const bind_path = formatBuf(&buf_b, "{s}/vfio-pci/bind", .{ SYSFS_DRIVERS }) catch return error.IoError;

    writeToFile(new_id_path, "0x0000 0x0000") catch {
        // vfio-pci not loaded — try modprobe
        _ = std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{ "modprobe", "vfio-pci" },
        }) catch {};
        // Retry after loading module
        writeToFile(new_id_path, "0x0000 0x0000") catch return error.BindFailed;
    };

    writeToFile(bind_path, bdf) catch return error.BindFailed;
}

/// Hot-remove a device from the PCI bus (BIND! force)
pub fn hotRemove(bdf: []const u8) BindError!void {
    var buf: [512]u8 = undefined;
    const remove_path = formatBuf(&buf, "{s}/{s}/remove", .{ SYSFS_DEVICES, bdf }) catch return error.HotRemoveFailed;
    writeToFile(remove_path, "1") catch return error.HotRemoveFailed;
}

/// Rescan the PCI bus to rediscover hot-removed devices
pub fn rescan() BindError!void {
    writeToFile(PCI_RESCAN, "1") catch return error.RescanFailed;
}

/// Perform a full BIND operation
pub fn bindDevice(allocator: std.mem.Allocator, bdf: []const u8, force: bool) BindResult {
    if (force) {
        hotRemove(bdf) catch |err| return .{
            .success = false,
            .previous_driver = null,
            .error_msg = switch (err) {
                error.HotRemoveFailed => "Hot-remove failed — insufficient permissions or device doesn't exist",
                error.NoPermission => "Need root for hot-remove",
                else => "Unknown error during hot-remove",
            },
        };
        rescan() catch |err| return .{
            .success = false,
            .previous_driver = null,
            .error_msg = switch (err) {
                error.RescanFailed => "PCI rescan failed",
                error.NoPermission => "Need root for rescan",
                else => "Unknown error during rescan",
            },
        };
        return .{ .success = true, .previous_driver = null, .error_msg = null };
    }

    const prev_driver = findDriver(allocator, bdf) catch null;
    unbindFromDriver(bdf) catch |err| return .{
        .success = false,
        .previous_driver = prev_driver,
        .error_msg = switch (err) {
            error.UnbindFailed => "Unbind failed — try --force for hot-remove",
            error.NoPermission => "Need root to unbind",
            else => "Unknown error during unbind",
        },
    };
    bindToVfio(bdf) catch |err| return .{
        .success = false,
        .previous_driver = prev_driver,
        .error_msg = switch (err) {
            error.BindFailed => "Bind to vfio-pci failed — is vfio-pci kernel module available?",
            error.NoPermission => "Need root to bind",
            else => "Unknown error during bind",
        },
    };
    return .{ .success = true, .previous_driver = prev_driver, .error_msg = null };
}

/// Restore a device to its previous driver (for Azoth rollback)
pub fn restoreDriver(allocator: std.mem.Allocator, bdf: []const u8, previous_driver: []const u8) BindResult {
    _ = allocator;
    unbindFromDriver(bdf) catch |err| return .{
        .success = false,
        .previous_driver = null,
        .error_msg = switch (err) {
            error.UnbindFailed => "Unbind from vfio-pci failed",
            error.NoPermission => "Need root",
            else => "Unknown error",
        },
    };

    var buf: [512]u8 = undefined;
    const bind_path = formatBuf(&buf, "{s}/{s}/bind", .{ SYSFS_DRIVERS, previous_driver }) catch {
        return .{ .success = false, .previous_driver = null, .error_msg = "Invalid driver name" };
    };
    writeToFile(bind_path, bdf) catch return .{
        .success = false,
        .previous_driver = null,
        .error_msg = "Restore bind failed — may need driver reload",
    };
    return .{ .success = true, .previous_driver = null, .error_msg = null };
}

fn formatBuf(buf: []u8, comptime fmt: []const u8, args: anytype) ![]const u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch return error.BufferTooSmall;
}

fn writeToFile(path: []const u8, content: []const u8) !void {
    const file = std.fs.openFileAbsolute(path, .{ .mode = .write_only }) catch |err| switch (err) {
        error.AccessDenied => return error.NoPermission,
        error.FileNotFound => return error.DeviceNotFound,
        else => return error.IoError,
    };
    defer file.close();
    file.writeAll(content) catch return error.IoError;
}
