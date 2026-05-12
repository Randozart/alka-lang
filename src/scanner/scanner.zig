// Copyright 2026 Randy Smits-Schreuder Goedheijt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Runtime Exception for Use as a Language:
// When the Work or any Derivative Work thereof is used to generate code
// ("generated code"), such generated code shall not be subject to the
// terms of this License, provided that the generated code itself is not
// a Derivative Work of the Work. This exception does not apply to code
// that is itself a compiler, interpreter, or similar tool that incorporates
// or embeds the Work.

const std = @import("std");

/// Substrate Scanner: Auto-discovers hardware capabilities and generates .alkavl files
pub const Scanner = struct {
    pub const DiscoveredDevice = struct {
        pci_id: u32,
        vendor: u16,
        device: u16,
        bus: u8,
        slot: u8,
        function: u8,
        bars: [6]BarInfo,
        driver: ?[]const u8,
        thermal_path: ?[]const u8,
    };

    pub const BarInfo = struct {
        physical_base: u64,
        size: u64,
        is_prefetchable: bool,
        requires_sliding_window: bool,
    };

    pub fn scanPciDevice(allocator: std.mem.Allocator, bdf: []const u8) !DiscoveredDevice {
        const path = try std.fmt.allocPrint(allocator, "/sys/bus/pci/devices/{s}/", .{bdf});
        defer allocator.free(path);

        var dir = std.fs.openDirAbsolute(path, .{}) catch return error.DeviceNotFound;
        defer dir.close();

        var bdf_parts = std.mem.splitScalar(u8, bdf, ':');
        _ = bdf_parts.next();
        const bus_str = bdf_parts.next() orelse return error.ParseError;
        const slot_func = bdf_parts.next() orelse return error.ParseError;

        const bus = std.fmt.parseInt(u8, bus_str, 16) catch return error.ParseError;
        var sf = std.mem.splitScalar(u8, slot_func, '.');
        const slot = std.fmt.parseInt(u8, sf.next() orelse return error.ParseError, 16) catch return error.ParseError;
        const function = std.fmt.parseInt(u8, sf.next() orelse return error.ParseError, 16) catch return error.ParseError;

        const vendor_id = try readHexFile(dir, allocator, "vendor");
        const device_id = try readHexFile(dir, allocator, "device");

        const resource_data = dir.readFileAlloc(allocator, "resource", 4096) catch return error.IoError;
        defer allocator.free(resource_data);

        var bars: [6]BarInfo = [_]BarInfo{.{ .physical_base = 0, .size = 0, .is_prefetchable = false, .requires_sliding_window = false }} ** 6;
        var lines = std.mem.tokenizeScalar(u8, resource_data, '\n');
        var bar_idx: usize = 0;
        while (bar_idx < 6) : (bar_idx += 1) {
            const line = lines.next() orelse break;
            if (line.len == 0) continue;
            var parts = std.mem.splitScalar(u8, line, ' ');
            const base_str = parts.next() orelse break;
            const end_str = parts.next() orelse break;
            const flags_str = parts.next() orelse break;

            const base = std.fmt.parseInt(u64, base_str, 16) catch 0;
            const end = std.fmt.parseInt(u64, end_str, 16) catch 0;
            const flags = std.fmt.parseInt(u64, flags_str, 16) catch 0;

            const size = if (end >= base) end - base + 1 else 0;
            const is_prefetchable = (flags & 0x200) != 0;
            const is_memory = (flags & 0x1) != 0;

            bars[bar_idx] = BarInfo{
                .physical_base = base,
                .size = size,
                .is_prefetchable = is_prefetchable,
                .requires_sliding_window = is_memory and size <= 256 * 1024 * 1024 and size > 0,
            };
        }

        const driver = readDriver(dir, allocator) catch null;
        const thermal_path = findThermalSensor(allocator) catch null;

        return DiscoveredDevice{
            .pci_id = (@as(u32, vendor_id) << 16) | device_id,
            .vendor = vendor_id,
            .device = device_id,
            .bus = bus,
            .slot = slot,
            .function = function,
            .bars = bars,
            .driver = driver,
            .thermal_path = thermal_path,
        };
    }

    pub fn generateVial(allocator: std.mem.Allocator, device: DiscoveredDevice, name: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();

        const writer = buf.writer();

        try writer.writeAll("// Auto-generated Alka Vial\n");
        try writer.print("// Scanned: {s}\n", .{name});
        try writer.print("// PCI ID: {x:0>4}:{x:0>4}\n\n", .{ device.vendor, device.device });

        try writer.print("Vessel {s} {{\n", .{name});
        try writer.print("    PCI_ID: {x:0>4}:{x:0>4};\n", .{ device.vendor, device.device });
        try writer.print("    BDF: {x:0>4}:{x:0>2}.{d};\n\n", .{ 
            device.bus, device.slot, device.function,
        });

        var bar_count: usize = 0;
        for (device.bars, 0..) |bar, i| {
            if (bar.size > 0 and bar.is_prefetchable) {
                const size_mb = bar.size / (1024 * 1024);
                try writer.print("    Aperture DATA_PLANE {{\n", .{});
                try writer.print("        BAR: {d};\n", .{i});
                try writer.print("        BASE: 0x{x};\n", .{bar.physical_base});
                try writer.print("        SIZE: {d}MB;\n", .{size_mb});
                try writer.print("        TYPE: Prefetchable;\n", .{});
                if (bar.requires_sliding_window) {
                    try writer.writeAll("        CONSTRAINT: SLIDING_WINDOW;\n");
                }
                try writer.writeAll("    }\n\n");
                bar_count += 1;
            } else if (bar.size > 0 and !bar.is_prefetchable and bar.size < 64 * 1024 * 1024) {
                const size_mb = bar.size / (1024 * 1024);
                try writer.print("    Aperture CTRL_PLANE {{\n", .{});
                try writer.print("        BAR: {d};\n", .{i});
                try writer.print("        BASE: 0x{x};\n", .{bar.physical_base});
                try writer.print("        SIZE: {d}MB;\n", .{size_mb});
                try writer.print("        TYPE: NonPrefetchable;\n", .{});
                try writer.writeAll("    }\n\n");
                bar_count += 1;
            }
        }

        try writer.writeAll("    Thermal SENSOR_0 {\n");
        try writer.writeAll("        HALT_AT: 98000;\n");
        try writer.writeAll("        THROTTLE_AT: 90000;\n");
        try writer.writeAll("    }\n\n");

        if (bar_count > 0) {
            const total_vram_mb = device.bars[1].size / (1024 * 1024);
            try writer.print("    Memory VRAM {{\n", .{});
            try writer.print("        TOTAL: {d}MB;\n", .{total_vram_mb});
            try writer.print("        RESERVED: 256MB;\n", .{});
            try writer.writeAll("    }\n");
        }

        try writer.writeAll("}\n");

        return buf.toOwnedSlice();
    }

    pub fn scanAllPciDevices(allocator: std.mem.Allocator) !std.ArrayList(DiscoveredDevice) {
        var devices = std.ArrayList(DiscoveredDevice).init(allocator);
        errdefer devices.deinit();

        var dir = std.fs.openDirAbsolute("/sys/bus/pci/devices/", .{ .iterate = true }) catch return error.DeviceNotFound;
        defer dir.close();

        var iter = dir.iterate();
        while (true) {
            const maybe_entry = iter.next() catch break;
            const entry = maybe_entry orelse break;
            if (entry.kind == .directory) {
                const device = scanPciDevice(allocator, entry.name) catch continue;
                devices.append(device) catch continue;
            }
        }

        return devices;
    }

    fn readHexFile(dir: std.fs.Dir, allocator: std.mem.Allocator, filename: []const u8) !u16 {
        const data = dir.readFileAlloc(allocator, filename, 16) catch return error.IoError;
        defer allocator.free(data);
        const trimmed = std.mem.trim(u8, data, " \t\n\r");
        return std.fmt.parseInt(u16, trimmed, 16) catch return error.ParseError;
    }

    fn readDriver(dir: std.fs.Dir, allocator: std.mem.Allocator) !?[]const u8 {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const link = dir.readLink("driver", &path_buf) catch return null;
        const basename = std.fs.path.basename(link);
        return try allocator.dupe(u8, basename);
    }

    fn findThermalSensor(allocator: std.mem.Allocator) !?[]const u8 {
        var dir = std.fs.openDirAbsolute("/sys/class/hwmon/", .{ .iterate = true }) catch return null;
        defer dir.close();

        var iter = dir.iterate();
        while (true) {
            const maybe_entry = iter.next() catch break;
            const entry = maybe_entry orelse break;
            if (entry.kind == .directory) {
                var sensor_dir = dir.openDir(entry.name, .{}) catch continue;
                defer sensor_dir.close();

                const name_data = sensor_dir.readFileAlloc(allocator, "name", 64) catch continue;
                defer allocator.free(name_data);

                if (std.mem.indexOf(u8, name_data, "nvidia") != null or
                    std.mem.indexOf(u8, name_data, "nouveau") != null)
                {
                    return try std.fmt.allocPrint(allocator, "/sys/class/hwmon/{s}", .{entry.name});
                }
            }
        }

        return null;
    }
};