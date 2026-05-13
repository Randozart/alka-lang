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

pub const Drop = packed struct {
    op_code: u8,
    flags: u8,
    vessel_id: u16,
    src_addr: u64,
    dst_addr: u64,
    size: u32,
    reserved: u32,
    crc: u32,
};

pub const DropExt = extern struct {
    op_code: u8,
    intensity: u8,
    safety: u16,
    src_addr: u64,
    dst_addr: u64,
    length: u64,
    pattern: [32]u8,
    auth_sig: u32,
    reserved: u4,
};

pub const DROP_SIZE = @sizeOf(Drop);
pub const DROP_SIZE_EXT = @sizeOf(DropExt);

pub fn computeCrc(packet: *const Drop) u32 {
    var crc: u32 = 0;
    const bytes: [*]const u8 = @ptrCast(packet);
    const crc_offset = @offsetOf(Drop, "crc");
    for (0..crc_offset) |i| {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

pub fn computeCrcExt(packet: *const DropExt) u32 {
    var crc: u32 = 0;
    const bytes: [*]const u8 = @ptrCast(packet);
    const crc_offset = @offsetOf(DropExt, "auth_sig");
    for (0..crc_offset) |i| {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

pub const EmitError = error{
    UnknownInstruction,
    InvalidOperand,
    BufferOverflow,
};

pub const Operand = union(enum) {
    literal: u64,
    identifier: []const u8,
    indexed: struct { base: []const u8, index: u64 },
    memory_size: struct { value: u64, unit: []const u8 },
    vessel_member: []const u8,
};

const UnitSpec = struct {
    suffixes: []const []const u8,
    multiplier: u64,
};

const unit_table = [_]UnitSpec{
    .{ .suffixes = &.{ "B", "b" }, .multiplier = 1 },
    .{ .suffixes = &.{ "KB", "Kb" }, .multiplier = 1024 },
    .{ .suffixes = &.{ "KIB", "KiB" }, .multiplier = 1024 },
    .{ .suffixes = &.{ "MB", "Mb" }, .multiplier = 1024 * 1024 },
    .{ .suffixes = &.{ "MIB", "MiB" }, .multiplier = 1024 * 1024 },
    .{ .suffixes = &.{ "GB", "Gb" }, .multiplier = 1024 * 1024 * 1024 },
    .{ .suffixes = &.{ "GIB", "GiB" }, .multiplier = 1024 * 1024 * 1024 },
    .{ .suffixes = &.{ "TB", "Tb" }, .multiplier = 1024 * 1024 * 1024 * 1024 },
    .{ .suffixes = &.{ "TIB", "TiB" }, .multiplier = 1024 * 1024 * 1024 * 1024 },
};

pub fn parseMemorySize(str: []const u8) ?Operand {
    const UnitMatch = struct {
        suffix_len: usize,
        multiplier: u64,
    };

    var best: ?UnitMatch = null;

    for (unit_table) |spec| {
        for (spec.suffixes) |suffix| {
            if (str.len <= suffix.len) continue;
            const suffix_start = str.len - suffix.len;
            const str_suffix = str[suffix_start..];
            if (std.ascii.eqlIgnoreCase(str_suffix, suffix)) {
                const num_str = str[0..suffix_start];
                _ = std.fmt.parseInt(u64, num_str, 10) catch continue;
                if (best == null or suffix.len > best.?.suffix_len) {
                    best = UnitMatch{ .suffix_len = suffix.len, .multiplier = spec.multiplier };
                }
            }
        }
    }

    if (best) |m| {
        const num_str = str[0 .. str.len - m.suffix_len];
        const num = std.fmt.parseInt(u64, num_str, 10) catch return null;
        return Operand{ .memory_size = .{ .value = num * m.multiplier, .unit = str[str.len - m.suffix_len ..] } };
    }
    return null;
}

pub fn parseOperand(str: []const u8) Operand {
    const trimmed = std.mem.trimRight(u8, str, " \t\r\n");

    if (trimmed.len == 0) return Operand{ .literal = 0 };

    if (trimmed[0] == '.') {
        const member = std.mem.trimLeft(u8, trimmed, ".");
        if (member.len > 0) {
            return Operand{ .vessel_member = member };
        }
    }

    if (parseMemorySize(trimmed)) |operand| return operand;

    if (trimmed.len > 2 and trimmed[0] == '0' and (trimmed[1] == 'x' or trimmed[1] == 'X')) {
        return Operand{ .literal = std.fmt.parseInt(u64, trimmed[2..], 16) catch 0 };
    }

    if (std.fmt.parseInt(u64, trimmed, 10)) |val| {
        return Operand{ .literal = val };
    } else |_| {
        return Operand{ .identifier = trimmed };
    }
}

pub fn evalOperand(operand: Operand) u64 {
    return switch (operand) {
        .literal => |v| v,
        .identifier => 0,
        .indexed => |idx| idx.index,
        .memory_size => |m| m.value,
        .vessel_member => 0,
    };
}

/// Generate the Azoth (rollback) counterpart for a given Drop.
/// Returns the inverse operation that restores pre-execution state.
pub fn generateAzothPacket(packet: *const Drop) Drop {
    var azoth = packet.*;

    // Set Azoth flag (bit 7)
    azoth.flags |= 0x80;

    // Map forward operation to rollback counterpart
    azoth.op_code = switch (packet.op_code) {
        0x01 => 0x0D, // CLAIM → REVERT (restore driver binding)
        0x02 => 0x20, // STAKE → ABDUCT (release physical pages)
        0x03 => 0x1F, // FLOW → VOID (overwrite transferred data)
        0x04 => 0x04, // SHIFT → SHIFT (restore original offset — src/dst swapped)
        0x0F => 0x24, // VEIL → GHOST (restore PCI visibility)
        0x34 => 0x0A, // OSSIFY → YIELD (return core to scheduler)
        0x35 => 0x2A, // BOND → FLUX (invalidate tunnel mappings)
        0x3A => 0x01, // OCCUPY → CLAIM (restore OS device access)
        0x1C => 0x1F, // STRIKE → VOID (sanitize flipped bits)
        0x1D => 0x0B, // QUENCH → RECAST (restore power state)
        0x1F => 0x1F, // VOID → VOID (can't undo secure erase, but log it)
        else => packet.op_code, // Self-inverse or no rollback needed
    };

    // Swap src/dst for bidirectional operations
    if (packet.op_code == 0x04) { // SHIFT
        const tmp = azoth.src_addr;
        azoth.src_addr = azoth.dst_addr;
        azoth.dst_addr = tmp;
    }

    azoth.crc = computeCrc(&azoth);
    return azoth;
}

/// Generate a complete Azoth binary from an AlkaSol binary.
/// Returns the rollback binary that restores pre-execution state.
pub fn generateAzothBinary(alkas: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var azoth = std.ArrayList(u8).init(allocator);
    errdefer azoth.deinit();

    // Process packets in reverse order (LIFO rollback)
    var i: usize = alkas.len;
    while (i >= DROP_SIZE) {
        i -= DROP_SIZE;
        var packet: Drop = undefined;
        @memcpy(std.mem.asBytes(&packet), alkas[i .. i + DROP_SIZE]);

        // Skip non-rollbackable instructions (DRY_RUN, MOCK, PROVE)
        if (packet.op_code == 0x2C or packet.op_code == 0x2D or packet.op_code == 0x2E) continue;

        const azoth_packet = generateAzothPacket(&packet);
        try azoth.appendSlice(std.mem.asBytes(&azoth_packet));
    }

    return azoth.toOwnedSlice();
}