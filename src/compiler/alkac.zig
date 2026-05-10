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
const instructions = @import("../instructions/mod.zig");
const alka_bin = @import("../codegen/alka_bin.zig");
const tools = @import("../tools/mod.zig");

pub const Program = struct {
    directives: std.ArrayList([]const u8),
    instructions: std.ArrayList(Instruction),
};

pub const Instruction = struct {
    name: []const u8,
    operands: std.ArrayList(alka_bin.Operand),
};

pub const Vial = struct {
    vessels: std.StringArrayHashMap(Vessel),
};

pub const Vessel = struct {
    name: []const u8,
    pci_id: ?struct { vendor: u16, device: u16 },
    apertures: std.ArrayList(Aperture),
    thermal: ?Thermal,
    block_device: ?[]const u8,
    dma_capable: ?bool,
};

pub const Aperture = struct {
    name: []const u8,
    bar: u8,
    max_window: ?u64,
    size: ?u64,
    aperture_type: ?[]const u8,
};

pub const Thermal = struct {
    halt_at: ?u64,
    throttle_at: ?u64,
};

pub const CompilerError = error{
    UnknownInstruction,
    UnknownVessel,
    UnknownAperture,
    ApertureOverflow,
    ThermalLimitExceeded,
    ParseError,
    FileNotFound,
    BufferOverflow,
};

pub fn compile(
    program: Program,
    vial: Vial,
    out: *std.ArrayList(u8),
) CompilerError!void {
    for (program.instructions.items) |instr| {
        const inst_def = instructions.getInstructionByName(instr.name) orelse {
            return CompilerError.UnknownInstruction;
        };

        try validateInstruction(instr, vial);

        const packet = try emitPacket(inst_def.op_code, instr.operands, vial);
        _ = out.appendSlice(std.mem.asBytes(&packet)) catch return CompilerError.BufferOverflow;
    }
}

fn validateInstruction(instr: Instruction, vial: Vial) CompilerError!void {
    for (instr.operands.items) |operand| {
        switch (operand) {
            .identifier => |name| {
                if (!vial.vessels.contains(name)) {
                    return CompilerError.UnknownVessel;
                }
            },
            else => {},
        }
    }
}

fn emitPacket(
    op_code: instructions.OpCode,
    operands: std.ArrayList(alka_bin.Operand),
    _: Vial,
) CompilerError!alka_bin.MetrodPacket {
    var packet = std.mem.zeroInit(alka_bin.MetrodPacket, .{
        .op_code = @intFromEnum(op_code),
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    });

    if (operands.items.len >= 1) {
        packet.src_addr = alka_bin.evalOperand(operands.items[0]);
    }
    if (operands.items.len >= 2) {
        packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
    }
    if (operands.items.len >= 3) {
        packet.size = @truncate(alka_bin.evalOperand(operands.items[2]));
    }

    packet.crc = alka_bin.computeCrc(&packet);
    return packet;
}

pub fn parseProgram(source: []const u8, allocator: std.mem.Allocator) !Program {
    var program = Program{
        .directives = std.ArrayList([]const u8).init(allocator),
        .instructions = std.ArrayList(Instruction).init(allocator),
    };

    var lines = std.mem.tokenizeScalar(u8, source, '\n');
    while (lines.next()) |line| {
        var trimmed = std.mem.trim(u8, line, " \t");

        if (trimmed.len == 0 or trimmed[0] == '/') continue;

        if (std.mem.startsWith(u8, trimmed, "REQUIRE ")) {
            const path = std.mem.trim(u8, trimmed[8..], " ;");
            try program.directives.append(try allocator.dupe(u8, path));
            continue;
        }

        var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const name = parts.next() orelse continue;

        var instr = Instruction{
            .name = try allocator.dupe(u8, name),
            .operands = std.ArrayList(alka_bin.Operand).init(allocator),
        };

        while (parts.next()) |part| {
            if (part.len > 0 and !std.mem.eql(u8, part, "->")) {
                instr.operands.append(alka_bin.parseOperand(part)) catch {};
            }
        }

        try program.instructions.append(instr);
    }

    return program;
}

pub fn parseVial(source: []const u8, allocator: std.mem.Allocator) !Vial {
    var vial = Vial{
        .vessels = std.StringArrayHashMap(Vessel).init(allocator),
    };

    var current_name: ?[]const u8 = null;
    var lines = std.mem.tokenizeScalar(u8, source, '\n');

    while (lines.next()) |line| {
        var trimmed = std.mem.trim(u8, line, " \t");
        if (trimmed.len == 0 or trimmed[0] == '/') continue;

        if (std.mem.startsWith(u8, trimmed, "Vessel ")) {
            current_name = std.mem.trim(u8, trimmed[7..], " {");
            const vessel = Vessel{
                .name = try allocator.dupe(u8, current_name.?),
                .pci_id = null,
                .apertures = std.ArrayList(Aperture).init(allocator),
                .thermal = null,
                .block_device = null,
                .dma_capable = null,
            };
            try vial.vessels.put(vessel.name, vessel);
            continue;
        }

        if (std.mem.eql(u8, trimmed, "}")) {
            current_name = null;
            continue;
        }

        if (current_name == null) continue;

        const v = vial.vessels.getPtr(current_name.?) orelse continue;
        
        if (std.mem.startsWith(u8, trimmed, "PCI_ID:")) {
            const id = std.mem.trim(u8, trimmed[7..], " ;");
            var parts = std.mem.tokenizeScalar(u8, id, ':');
            const vendor = std.fmt.parseInt(u16, parts.next() orelse "0", 16) catch 0;
            const device = std.fmt.parseInt(u16, parts.next() orelse "0", 16) catch 0;
            v.pci_id = .{ .vendor = vendor, .device = device };
        } else if (std.mem.startsWith(u8, trimmed, "BLOCK_DEVICE:")) {
            const dev = std.mem.trim(u8, trimmed[13..], " ;");
            v.block_device = try allocator.dupe(u8, dev);
        } else if (std.mem.startsWith(u8, trimmed, "DMA_CAPABLE:")) {
            const val = std.mem.trim(u8, trimmed[12..], " ;");
            v.dma_capable = std.mem.eql(u8, val, "true");
        } else if (std.mem.startsWith(u8, trimmed, "MAX_WINDOW:")) {
            const val = std.mem.trim(u8, trimmed[11..], " ;");
            var size: u64 = 0;
            if (std.mem.indexOf(u8, val, "MB") != null) {
                size = std.fmt.parseInt(u64, val[0..val.len-2], 10) catch 0 * 1024 * 1024;
            } else {
                size = std.fmt.parseInt(u64, val, 10) catch 0;
            }
            if (v.apertures.items.len > 0) {
                v.apertures.items[v.apertures.items.len - 1].max_window = size;
            }
        }
    }

    return vial;
}

pub fn analyzeWithTools(
    program: Program,
    _: Vial,
    _: std.mem.Allocator,
) !void {
    std.debug.print("\n=== Instruction Analysis ===\n", .{});

    var total_bytes: u64 = 0;
    var instruction_count: usize = 0;

    for (program.instructions.items) |instr| {
        const inst_def = instructions.getInstructionByName(instr.name) orelse continue;
        
        var op_desc: []const u8 = "";
        var byte_count: u64 = 32;
        
        switch (inst_def.op_code) {
            .CLAIM => op_desc = "Stake hardware node",
            .FLOW => { op_desc = "DMA transfer"; byte_count = 32; },
            .SHIFT => op_desc = "Remap BAR window",
            .FENCE => op_desc = "Wait for condition",
            .SYNC => op_desc = "Memory barrier",
            .SENSE => op_desc = "Read sensor",
            .PULSE => op_desc = "Timing signal",
            .SIGNAL => op_desc = "Trigger interrupt",
            .YIELD => op_desc = "Cooperative yield",
            else => op_desc = "Other",
        }
        
        std.debug.print("  [{s}] {s} - {} bytes\n", .{instr.name, op_desc, byte_count});
        
        instruction_count += 1;
        total_bytes += byte_count;
    }

    std.debug.print("\n  Total: {} instructions, {} bytes\n", .{instruction_count, total_bytes});
    std.debug.print("=== Analysis Complete ===\n\n", .{});
}