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
const welder = @import("../codegen/welder.zig");
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
    VesselNotFound,
    InvalidAlignment,
    ProhibitedRange,
    OutOfMemory,
};

pub fn compile(
    program: Program,
    vial: Vial,
    out: *std.ArrayList(u8),
    azoth_out: ?*std.ArrayList(u8),
    allocator: std.mem.Allocator,
) CompilerError!void {
    // Stage 1: Emit raw packets
    for (program.instructions.items) |instr| {
        const inst_def = instructions.getInstructionByName(instr.name) orelse {
            return CompilerError.UnknownInstruction;
        };

        try validateInstruction(instr, vial, allocator, inst_def);
        try validateWithTools(instr, inst_def, vial, allocator);

        const packet = try emitPacket(inst_def.op_code, instr.operands, vial);
        _ = out.appendSlice(std.mem.asBytes(&packet)) catch return CompilerError.BufferOverflow;
    }

    // Stage 2: Post-precipitation refinement via Welder
    // The Welder validates CRCs and optimizes packet sequences
    const refined = try welder.Welder.refineBinary(out.items, allocator);
    defer allocator.free(refined);

    out.clearRetainingCapacity();
    try out.appendSlice(refined);

    // Stage 3: Generate Azoth rollback binary
    if (azoth_out) |az| {
        const azoth = try alka_bin.generateAzothBinary(out.items, allocator);
        defer allocator.free(azoth);
        try az.appendSlice(azoth);
    }
}

fn validateInstruction(instr: Instruction, vial: Vial, allocator: std.mem.Allocator, inst_def: *const instructions.Instruction) CompilerError!void {
    _ = instr;
    _ = vial;
    _ = allocator;
    _ = inst_def;
    // Vessel validation deferred to runtime
}

fn validateWithTools(instr: Instruction, inst_def: *const instructions.Instruction, vial: Vial, allocator: std.mem.Allocator) !void {
    _ = allocator;
    _ = vial;

    const op_code = @intFromEnum(inst_def.op_code);
    const tool = tools.getTool(op_code) orelse return;

    var operands: [3]u64 = .{ 0, 0, 0 };
    for (instr.operands.items, 0..) |op, i| {
        if (i >= 3) break;
        operands[i] = alka_bin.evalOperand(op);
    }

    const ctx = tools.Tool.Context{
        .physical_addr = 0,
        .pci_bus = 0,
        .pci_device = 0,
        .pci_function = 0,
        .bar_base = 0,
        .aperture_size = 0,
        .thermal_limit = 0,
        .current_temp = 0,
    };

    const result = try tool.validate(operands[0..@min(instr.operands.items.len, 3)], ctx);

    if (!result.allowed) {
        return CompilerError.ParseError;
    }
}

fn emitPacket(
    op_code: instructions.OpCode,
    operands: std.ArrayList(alka_bin.Operand),
    vial: Vial,
) CompilerError!alka_bin.Drop {
    var packet = std.mem.zeroInit(alka_bin.Drop, .{
        .op_code = @intFromEnum(op_code),
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    });

    if (op_code == .CLAIM and operands.items.len >= 1) {
        const name = switch (operands.items[0]) {
            .identifier => |id| id,
            else => {
                packet.src_addr = alka_bin.evalOperand(operands.items[0]);
                packet.crc = alka_bin.computeCrc(&packet);
                return packet;
            },
        };

        var it = vial.vessels.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, name)) {
                const vessel = entry.value_ptr.*;
                if (vessel.pci_id) |pci| {
                    packet.src_addr = (@as(u64, pci.device) << 16) | pci.vendor;
                    packet.vessel_id = 0;
                    packet.crc = alka_bin.computeCrc(&packet);
                    return packet;
                }
                break;
            }
        }
        return CompilerError.UnknownVessel;
    }

    if (op_code == .LIMIT and operands.items.len >= 1) {
        const name = switch (operands.items[0]) {
            .identifier => |id| id,
            else => {
                packet.src_addr = alka_bin.evalOperand(operands.items[0]);
                if (operands.items.len >= 2) {
                    packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
                }
                packet.crc = alka_bin.computeCrc(&packet);
                return packet;
            },
        };

        var it = vial.vessels.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, name)) {
                const vessel = entry.value_ptr.*;
                if (vessel.pci_id) |pci| {
                    packet.src_addr = (@as(u64, pci.device) << 16) | pci.vendor;
                }
                break;
            }
        }
        if (operands.items.len >= 2) {
            packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
        }
        packet.crc = alka_bin.computeCrc(&packet);
        return packet;
    }

    if (op_code == .FENCE and operands.items.len >= 1) {
        const name = switch (operands.items[0]) {
            .identifier => |id| id,
            else => {
                packet.src_addr = alka_bin.evalOperand(operands.items[0]);
                if (operands.items.len >= 2) {
                    packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
                }
                packet.crc = alka_bin.computeCrc(&packet);
                return packet;
            },
        };

        var it = vial.vessels.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, name)) {
                const vessel = entry.value_ptr.*;
                if (vessel.pci_id) |pci| {
                    packet.src_addr = (@as(u64, pci.device) << 16) | pci.vendor;
                }
                break;
            }
        }
        if (operands.items.len >= 2) {
            packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
        }
        packet.crc = alka_bin.computeCrc(&packet);
        return packet;
    }

    if (op_code == .SIGNAL and operands.items.len >= 1) {
        const name = switch (operands.items[0]) {
            .identifier => |id| id,
            else => {
                packet.src_addr = alka_bin.evalOperand(operands.items[0]);
                packet.crc = alka_bin.computeCrc(&packet);
                return packet;
            },
        };

        var hash: u64 = 5381;
        for (name) |c| {
            hash = ((hash << 5) +% hash) +% c;
        }
        packet.src_addr = hash;
        packet.crc = alka_bin.computeCrc(&packet);
        return packet;
    }

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
        const raw_name = parts.next() orelse continue;
        const name = std.mem.trimRight(u8, raw_name, "; \t");

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
    var in_aperture = false;
    var aperture_name: ?[]const u8 = null;
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

        if (std.mem.startsWith(u8, trimmed, "Aperture ")) {
            in_aperture = true;
            aperture_name = std.mem.trim(u8, trimmed[9..], " {");
            continue;
        }

        if (std.mem.eql(u8, trimmed, "}")) {
            if (in_aperture) {
                in_aperture = false;
                aperture_name = null;
            } else {
                current_name = null;
            }
            continue;
        }

        if (current_name == null) continue;

        const v = vial.vessels.getPtr(current_name.?) orelse continue;

        if (in_aperture) {
            if (std.mem.startsWith(u8, trimmed, "BAR:")) {
                const bar_val = std.fmt.parseInt(u8, std.mem.trim(u8, trimmed[4..], " ;"), 10) catch 0;
                const ap = Aperture{
                    .name = try allocator.dupe(u8, aperture_name.?),
                    .bar = bar_val,
                    .max_window = null,
                    .size = null,
                    .aperture_type = null,
                };
                try v.apertures.append(ap);
            } else if (v.apertures.items.len > 0) {
                const ap = &v.apertures.items[v.apertures.items.len - 1];
                if (std.mem.startsWith(u8, trimmed, "SIZE:")) {
                    const val = std.mem.trim(u8, trimmed[5..], " ;");
                    if (std.mem.indexOf(u8, val, "MB") != null) {
                        const num = std.fmt.parseInt(u64, val[0..val.len-2], 10) catch 0;
                        ap.size = num * 1024 * 1024;
                    } else if (std.mem.indexOf(u8, val, "GB") != null) {
                        const num = std.fmt.parseInt(u64, val[0..val.len-2], 10) catch 0;
                        ap.size = num * 1024 * 1024 * 1024;
                    } else {
                        ap.size = std.fmt.parseInt(u64, val, 10) catch 0;
                    }
                } else if (std.mem.startsWith(u8, trimmed, "BASE:")) {
                    _ = std.mem.trim(u8, trimmed[5..], " ;");
                } else if (std.mem.startsWith(u8, trimmed, "TYPE:")) {
                    const type_val = std.mem.trim(u8, trimmed[5..], " ;");
                    _ = try allocator.dupe(u8, type_val);
                }
            }
            continue;
        }

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
                const num = std.fmt.parseInt(u64, val[0..val.len-2], 10) catch 0;
                size = num * 1024 * 1024;
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
            .CLAIM => { op_desc = "Stake hardware node"; byte_count = 32; },
            .STAKE => { op_desc = "Claim memory region"; byte_count = 64; },
            .FLOW => { op_desc = "DMA transfer"; byte_count = 64; },
            .SHIFT => { op_desc = "Remap BAR window"; byte_count = 32; },
            .FENCE => { op_desc = "Wait for condition"; byte_count = 32; },
            .SYNC => { op_desc = "Memory barrier"; byte_count = 16; },
            .SENSE => { op_desc = "Read sensor"; byte_count = 16; },
            .PULSE => { op_desc = "Timing signal"; byte_count = 24; },
            .SIGNAL => { op_desc = "Trigger interrupt"; byte_count = 16; },
            .YIELD => { op_desc = "Cooperative yield"; byte_count = 8; },
            .RECAST => { op_desc = "FPGA reconfigure"; byte_count = 128; },
            .SNAP => { op_desc = "Serialize state"; byte_count = 256; },
            .REVERT => { op_desc = "Restore state"; byte_count = 256; },
            .LIMIT => { op_desc = "Hard contract"; byte_count = 32; },
            .VEIL => { op_desc = "Hide from OS"; byte_count = 48; },
            .DELEGATE => { op_desc = "CPU bypass"; byte_count = 64; },
            .RHYTHM => { op_desc = "Timing constraint"; byte_count = 32; },
            .DISTILL => { op_desc = "Algorithmic synthesis"; byte_count = 512; },
            .ENQUEUE => { op_desc = "Command ring"; byte_count = 32; },
            .MOLT => { op_desc = "Full state dump"; byte_count = 4096; },
            .VOUCH => { op_desc = "Attestation"; byte_count = 128; },
            .PROBE_BUS => { op_desc = "Forensic audit"; byte_count = 64; },
            .ECHO => { op_desc = "Non-intrusive introspection"; byte_count = 32; },
            .STASIS => { op_desc = "Bus-level locking"; byte_count = 24; },
            .TRANSVERSE => { op_desc = "Bit-level swizzling"; byte_count = 48; },
            .SEARCH => { op_desc = "Physical signature scanning"; byte_count = 128; },
            .FOSSILIZE => { op_desc = "Substrate persistence"; byte_count = 64; },
            .STRIKE => { op_desc = "Rowhammer/bit flipping"; byte_count = 16; },
            .QUENCH => { op_desc = "Emergency power-state reset"; byte_count = 8; },
            .FORGE => { op_desc = "Bitstream injection"; byte_count = 2048; },
            .VOID => { op_desc = "Secure substrate erase"; byte_count = 16; },
            .ABDUCT => { op_desc = "Physical page stealing"; byte_count = 128; },
            .SNOOP => { op_desc = "Cache-coherent monitoring"; byte_count = 32; },
            .SCATTER => { op_desc = "Vectored I/O (scatter-gather)"; byte_count = 64; },
            .WHISPER => { op_desc = "Side-channel extraction"; byte_count = 48; },
            .GHOST => { op_desc = "Configuration space masking"; byte_count = 48; },
            .HIJACK => { op_desc = "IRQ stealing"; byte_count = 32; },
            .FLUX => { op_desc = "Cache invalidation"; byte_count = 16; },
            .AUDIT => { op_desc = "Post-instruction residue check"; byte_count = 32; },
            .DRY_RUN => { op_desc = "Simulate without executing"; byte_count = 0; },
            .MOCK => { op_desc = "Use mock hardware"; byte_count = 0; },
            .PROVE => { op_desc = "Formal verification"; byte_count = 0; },
            .WATCH => { op_desc = "Real-time hardware monitoring"; byte_count = 4; },
            .TRACE => { op_desc = "Instruction execution trace"; byte_count = 8; },
            .GUARD => { op_desc = "Runtime safety sentinel"; byte_count = 16; },
            .ISOLATE => { op_desc = "Complete hardware isolation"; byte_count = 8; },
            .VERIFY => { op_desc = "Cryptographic state verification"; byte_count = 64; },
            .OSSIFY => { op_desc = "Pin CPU core - scheduler bypass"; byte_count = 100; },
            .BOND => { op_desc = "RAM-to-GPU direct tunnel"; byte_count = 64; },
            .STILL => { op_desc = "Manual DRAM refresh control"; byte_count = 24; },
            .RESONATE => { op_desc = "Hardware reset coordination"; byte_count = 48; },
            .OSCILLATE => { op_desc = "Dual-bank refresh coordination"; byte_count = 96; },
            .IMC_HIJACK => { op_desc = "Direct memory controller access"; byte_count = 32; },
            .OCCUPY => { op_desc = "Seize PCIe device - OS access severed"; byte_count = 200; },
            else => { op_desc = "Unknown"; byte_count = 32; },
        }

        std.debug.print("  [{s:>12}] {s:40} - {} bytes\n", .{ instr.name, op_desc, byte_count });

        instruction_count += 1;
        total_bytes += byte_count;
    }

    std.debug.print("\n  Total: {} instructions, {} bytes\n", .{ instruction_count, total_bytes });
    std.debug.print("=== Analysis Complete ===\n\n", .{});
}