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

pub const MetrodPacket = extern struct {
    op_code: u8,
    flags: u8,
    vessel_id: u16,
    src_addr: u64,
    dst_addr: u64,
    size: u32,
    reserved: u32,
    crc: u32,
};

pub const MetrodPacketExt = extern struct {
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

pub const PACKET_SIZE = @sizeOf(MetrodPacket);
pub const PACKET_SIZE_EXT = @sizeOf(MetrodPacketExt);

pub fn computeCrc(packet: *const MetrodPacket) u32 {
    var crc: u32 = 0;
    const bytes: [*]const u8 = @ptrCast(packet);
    for (0..PACKET_SIZE) |i| {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

pub fn computeCrcExt(packet: *const MetrodPacketExt) u32 {
    var crc: u32 = 0;
    const bytes: [*]const u8 = @ptrCast(packet);
    for (0..PACKET_SIZE_EXT) |i| {
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
};

pub fn parseOperand(str: []const u8) Operand {
    if (std.mem.indexOf(u8, str, "MB")) |_| {
        const num = std.fmt.parseInt(u64, str[0..str.len-2], 10) catch 0;
        return .{ .memory_size = .{ .value = num * 1024 * 1024, .unit = "MB" } };
    }
    if (std.mem.indexOf(u8, str, "GB")) |_| {
        const num = std.fmt.parseInt(u64, str[0..str.len-2], 10) catch 0;
        return .{ .memory_size = .{ .value = num * 1024 * 1024 * 1024, .unit = "GB" } };
    }
    if (str.len > 2 and str[0] == '0' and str[1] == 'x') {
        return .{ .literal = std.fmt.parseInt(u64, str[2..], 16) catch 0 };
    }
    return .{ .literal = std.fmt.parseInt(u64, str, 10) catch 0 };
}

pub fn evalOperand(operand: Operand) u64 {
    return switch (operand) {
        .literal => |v| v,
        .identifier => 0,
        .indexed => |idx| idx.index,
        .memory_size => |m| m.value,
    };
}