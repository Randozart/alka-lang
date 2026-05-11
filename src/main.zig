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
const alka_bin = @import("codegen/alka_bin.zig");
const alkac = @import("compiler/alkac.zig");
const scanner = @import("scanner/scanner.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Alka Compiler v2.2 — The Officina\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Usage:\n", .{});
        std.debug.print("  alka <source.alka> <vial.alkavl>     Compile a Recipe with a Vial\n", .{});
        std.debug.print("  alka --probe <pci_bdf>               Scan hardware and generate .alkavl\n", .{});
        std.debug.print("  alka --probe-all                     Scan all PCI devices\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  alka moore_stream.alka ivyb_pascal.alkavl\n", .{});
        std.debug.print("  alka --probe 0000:01:00.0            # Scan GPU at BDF 01:00.0\n", .{});
        return;
    }

    // Handle --probe commands
    if (std.mem.eql(u8, args[1], "--probe")) {
        if (args.len < 3) {
            std.debug.print("Usage: alka --probe <pci_bdf>\n", .{});
            std.debug.print("Example: alka --probe 0000:01:00.0\n", .{});
            return;
        }

        const bdf = args[2];
        std.debug.print("Scanning PCI device: {s}\n", .{bdf});

        const device = scanner.Scanner.scanPciDevice(allocator, bdf) catch |err| {
            std.debug.print("Error scanning device: {s}\n", .{@errorName(err)});
            return;
        };

        std.debug.print("\n=== Discovered Device ===\n", .{});
        std.debug.print("  PCI ID: {x:0>4}:{x:0>4}\n", .{ device.vendor, device.device });
        std.debug.print("  Bus: {d}:{d}.{d}\n", .{ device.bus, device.slot, device.function });
        if (device.driver) |drv| {
            std.debug.print("  Driver: {s}\n", .{drv});
        }
        std.debug.print("\n  BARs:\n", .{});
        for (device.bars, 0..) |bar, i| {
            if (bar.size > 0) {
                std.debug.print("    BAR{d}: base=0x{x} size={d}MB prefetchable={any} sliding_window={any}\n", .{
                    i, bar.physical_base, bar.size / (1024 * 1024), bar.is_prefetchable, bar.requires_sliding_window,
                });
            }
        }
        if (device.thermal_path) |tp| {
            std.debug.print("\n  Thermal Sensor: {s}\n", .{tp});
        }

        // Generate and write .alkavl
        const vial_name = try std.fmt.allocPrint(allocator, "auto_{x:0>4}_{x:0>4}", .{ device.vendor, device.device });
        const vial_content = try scanner.Scanner.generateVial(allocator, device, vial_name);
        defer allocator.free(vial_content);

        const vial_path = try std.fmt.allocPrint(allocator, "{s}.alkavl", .{vial_name});
        defer allocator.free(vial_path);

        try std.fs.cwd().writeFile(.{ .sub_path = vial_path, .data = vial_content });
        std.debug.print("\nEmitted: {s}\n", .{vial_path});
        return;
    }

    if (std.mem.eql(u8, args[1], "--probe-all")) {
        std.debug.print("Scanning all PCI devices...\n\n", .{});

        const devices = scanner.Scanner.scanAllPciDevices(allocator) catch |err| {
            std.debug.print("Error scanning devices: {s}\n", .{@errorName(err)});
            return;
        };

        std.debug.print("Found {} devices:\n\n", .{devices.items.len});
        for (devices.items) |device| {
            std.debug.print("  {x:0>4}:{x:0>4} at {d}:{d:0>2}.{d}\n", .{
                device.vendor, device.device, device.bus, device.slot, device.function,
            });
            for (device.bars, 0..) |bar, i| {
                if (bar.size > 0) {
                std.debug.print("    BAR{d}: {d}MB{s}\n", .{
                    i, bar.size / (1024 * 1024),
                    if (bar.requires_sliding_window) " [SLIDING WINDOW]" else "",
                });
                }
            }
            std.debug.print("\n", .{});
        }
        return;
    }

    // Standard compilation mode
    if (args.len < 3) {
        std.debug.print("Error: Expected <source.alka> <vial.alkavl>\n", .{});
        return;
    }

    const source_path = args[1];
    const vial_path = args[2];

    std.debug.print("Compiling: {s} + {s}\n", .{ source_path, vial_path });

    const source = try std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize));
    defer allocator.free(source);

    const vial_data = try std.fs.cwd().readFileAlloc(allocator, vial_path, std.math.maxInt(usize));
    defer allocator.free(vial_data);

    const program = try alkac.parseProgram(source, allocator);
    const vial = try alkac.parseVial(vial_data, allocator);

    try alkac.analyzeWithTools(program, vial, allocator);

    var binary = std.ArrayList(u8).init(allocator);
    var azoth = std.ArrayList(u8).init(allocator);
    try alkac.compile(program, vial, &binary, &azoth, allocator);

    const out_path = try std.fmt.allocPrint(allocator, "{s}.alkas", .{ source_path });
    defer allocator.free(out_path);

    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = binary.items });

    const azoth_path = try std.fmt.allocPrint(allocator, "{s}.azoth", .{ source_path });
    defer allocator.free(azoth_path);

    try std.fs.cwd().writeFile(.{ .sub_path = azoth_path, .data = azoth.items });

    std.debug.print("Emitted: {s} ({} bytes, {} packets)\n", .{
        out_path,
        binary.items.len,
        binary.items.len / @sizeOf(alka_bin.MetrodPacket),
    });
    std.debug.print("Emitted: {s} ({} bytes, {} rollback packets)\n", .{
        azoth_path,
        azoth.items.len,
        azoth.items.len / @sizeOf(alka_bin.MetrodPacket),
    });
}