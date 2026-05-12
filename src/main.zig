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
const executor = @import("executor/alka_run.zig");
const mock_executor = @import("executor/mock_executor.zig");
const gguf_parser = @import("gguf/parser.zig");
const safety_injector = @import("compiler/safety_injector.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Alka Compiler v3.0 — The Officina\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Usage:\n", .{});
        std.debug.print("  alka <source.alka> <vial.alkavl>          Compile a Recipe with a Vial\n", .{});
        std.debug.print("  alka --execute <binary.alkas> [azoth]     Execute binary via kernel\n", .{});
        std.debug.print("  alka --safe <binary.alkas> <azoth.azoth>  Execute with rollback\n", .{});
        std.debug.print("  alka --gguf <model.gguf> <vial.alkavl>    Generate tensor streaming recipe\n", .{});
        std.debug.print("  alka --inject <source.alka> <vial.alkavl> Compile with safety injection\n", .{});
        std.debug.print("  alka --mock <binary.alkas>              Simulate execution (no kernel/hardware)\n", .{});
        std.debug.print("  alka --probe <pci_bdf>                    Scan hardware and generate .alkavl\n", .{});
        std.debug.print("  alka --generate-vial <pci_bdf> [name]     Generate .alkavl for specific device\n", .{});
        std.debug.print("  alka --probe-all                          Scan all PCI devices\n", .{});
        std.debug.print("\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  alka moore_stream.alka ivyb_pascal.alkavl\n", .{});
        std.debug.print("  alka --safe purify_1070ti.alkas purify_1070ti.azoth\n", .{});
        std.debug.print("  alka --gguf llama-7b.Q4_K_M.gguf ivyb_pascal.alkavl\n", .{});
        std.debug.print("  alka --probe 0000:01:00.0                 # Scan GPU at BDF 01:00.0\n", .{});
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

    if (std.mem.eql(u8, args[1], "--generate-vial")) {
        if (args.len < 3) {
            std.debug.print("Usage: alka --generate-vial <pci_bdf> [vessel_name]\n", .{});
            std.debug.print("Example: alka --generate-vial 0000:02:00.0 GTX_960\n", .{});
            return;
        }
        const bdf = args[2];
        const vessel_name = if (args.len >= 4) args[3] else null;

        std.debug.print("Generating Vial for: {s}\n", .{bdf});

        const device = scanner.Scanner.scanPciDevice(allocator, bdf) catch |err| {
            std.debug.print("Error scanning device: {s}\n", .{@errorName(err)});
            return;
        };

        const name = vessel_name orelse try std.fmt.allocPrint(allocator, "GPU_{x:0>4}_{x:0>4}", .{ device.vendor, device.device });

        const vial_content = scanner.Scanner.generateVial(allocator, device, name) catch |err| {
            std.debug.print("Error generating Vial: {s}\n", .{@errorName(err)});
            return;
        };
        defer allocator.free(vial_content);

        const vial_path = try std.fmt.allocPrint(allocator, "{s}.alkavl", .{name});
        defer allocator.free(vial_path);

        try std.fs.cwd().writeFile(.{ .sub_path = vial_path, .data = vial_content });
        std.debug.print("\n=== Generated Vial ===\n", .{});
        std.debug.print("{s}\n", .{vial_content});
        std.debug.print("Emitted: {s}\n", .{vial_path});
        return;
    }

    if (std.mem.eql(u8, args[1], "--execute")) {
        if (args.len < 3) {
            std.debug.print("Usage: alka --execute <binary.alkas> [azoth.azoth]\n", .{});
            return;
        }
        const alkas_path = args[2];
        const azoth_path = if (args.len >= 4) args[3] else null;

        std.debug.print("Executing: {s}\n", .{alkas_path});
        if (azoth_path) |az| {
            std.debug.print("Rollback: {s}\n", .{az});
        }

        const result = executor.run(
            allocator,
            alkas_path,
            azoth_path,
            null,
            azoth_path != null,
        ) catch |err| {
            std.debug.print("Execution failed: {s}\n", .{@errorName(err)});
            return;
        };

        std.debug.print("\n=== Execution Result ===\n", .{});
        std.debug.print("  Status: {s}\n", .{statusString(result.status)});
        std.debug.print("  Packets: {}/{}\n", .{ result.packets_executed, result.packets_total });
        std.debug.print("  Cycles: {}\n", .{result.cycles_spent});
        std.debug.print("  Bytes transferred: {}\n", .{result.bytes_transferred});
        std.debug.print("  Peak thermal: {} mC\n", .{result.thermal_peak});
        if (result.status != 0) {
            std.debug.print("  Error: {s}\n", .{result.error_msg});
        }
        std.debug.print("========================\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "--safe")) {
        if (args.len < 4) {
            std.debug.print("Usage: alka --safe <binary.alkas> <azoth.azoth>\n", .{});
            return;
        }
        const alkas_path = args[2];
        const azoth_path = args[3];

        std.debug.print("Safe execution: {s} + {s}\n", .{ alkas_path, azoth_path });

        const result = executor.run(
            allocator,
            alkas_path,
            azoth_path,
            null,
            true,
        ) catch |err| {
            std.debug.print("Safe execution failed: {s}\n", .{@errorName(err)});
            return;
        };

        std.debug.print("\n=== Safe Execution Result ===\n", .{});
        std.debug.print("  Status: {s}\n", .{statusString(result.status)});
        std.debug.print("  Packets: {}/{}\n", .{ result.packets_executed, result.packets_total });
        std.debug.print("  Cycles: {}\n", .{result.cycles_spent});
        std.debug.print("  Bytes transferred: {}\n", .{result.bytes_transferred});
        std.debug.print("  Peak thermal: {} mC\n", .{result.thermal_peak});
        if (result.status != 0) {
            std.debug.print("  Error: {s}\n", .{result.error_msg});
        }
        std.debug.print("=============================\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "--gguf")) {
        if (args.len < 4) {
            std.debug.print("Usage: alka --gguf <model.gguf> <vial.alkavl>\n", .{});
            return;
        }
        const gguf_path = args[2];
        const vial_path = args[3];

        std.debug.print("Parsing GGUF: {s}\n", .{gguf_path});

        var gguf = gguf_parser.parse(allocator, gguf_path) catch |err| {
            std.debug.print("GGUF parse error: {s}\n", .{@errorName(err)});
            return;
        };
        defer gguf.deinit();

        std.debug.print("  Architecture: {s}\n", .{gguf.metadata.arch orelse "unknown"});
        std.debug.print("  Tensors: {}\n", .{gguf.metadata.tensor_count});
        std.debug.print("  Alignment: {}\n", .{gguf.metadata.alignment});

        const vial_data = try std.fs.cwd().readFileAlloc(allocator, vial_path, std.math.maxInt(usize));
        defer allocator.free(vial_data);

        const vial = try alkac.parseVial(vial_data, allocator);
        var vessel_it = vial.vessels.iterator();
        const vessel_name = if (vessel_it.next()) |entry| entry.key_ptr.* else "gpu0";

        const instructions = gguf_parser.generateAlkaInstructions(allocator, &gguf, vessel_name, 0x100000000) catch |err| {
            std.debug.print("Instruction generation error: {s}\n", .{@errorName(err)});
            return;
        };
        defer allocator.free(instructions);

        const out_path = try std.fmt.allocPrint(allocator, "{s}.alka", .{gguf_path});
        defer allocator.free(out_path);

        try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = instructions });
        std.debug.print("\nEmitted: {s}\n", .{out_path});
        return;
    }

    if (std.mem.eql(u8, args[1], "--inject")) {
        if (args.len < 4) {
            std.debug.print("Usage: alka --inject <source.alka> <vial.alkavl>\n", .{});
            return;
        }
        const source_path = args[2];
        const vial_path = args[3];

        std.debug.print("Compiling with safety injection: {s} + {s}\n", .{ source_path, vial_path });

        const source = try std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize));
        defer allocator.free(source);

        const vial_data = try std.fs.cwd().readFileAlloc(allocator, vial_path, std.math.maxInt(usize));
        defer allocator.free(vial_data);

        var program = try alkac.parseProgram(source, allocator);
        const vial = try alkac.parseVial(vial_data, allocator);

        var injector = safety_injector.Injector.init(allocator);
        defer injector.deinit();

        try injector.inject(&program, &vial);
        try injector.injectThermalChecks(&program, &vial);

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
        return;
    }

    if (std.mem.eql(u8, args[1], "--mock")) {
        if (args.len < 3) {
            std.debug.print("Usage: alka --mock <source.alka> <vial.alkavl>\n", .{});
            return;
        }
        const source_path = args[2];

        std.debug.print("Mock execution: {s}\n", .{source_path});

        const alkas = try std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize));
        defer allocator.free(alkas);

        var mock = mock_executor.MockExecutor.init(allocator, 256) catch |err| {
            std.debug.print("Mock init failed: {s}\n", .{@errorName(err)});
            return;
        };
        defer mock.deinit();

        mock.execute(alkas) catch |err| {
            std.debug.print("Mock execution error: {s}\n", .{@errorName(err)});
        };

        mock.printReport();
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

fn statusString(status: u32) []const u8 {
    return switch (status) {
        0 => "OK",
        1 => "ERROR",
        2 => "THERMAL",
        3 => "TIMEOUT",
        4 => "CRC_FAIL",
        else => "UNKNOWN",
    };
}