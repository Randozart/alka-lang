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

pub const GGUF_MAGIC = "GGUF";

pub const GgufTensor = struct {
    name: []const u8,
    n_dims: u32,
    ne: [4]u64,
    offset: u64,
    dtype: GgufType,
};

pub const GgufType = enum(u32) {
    F32 = 0,
    F16 = 1,
    Q4_0 = 2,
    Q4_1 = 3,
    Q5_0 = 6,
    Q5_1 = 7,
    Q8_0 = 8,
    Q8_1 = 9,
    Q2_K = 10,
    Q3_K = 11,
    Q4_K = 12,
    Q5_K = 13,
    Q6_K = 14,
    IQ2_XXS = 15,
    IQ2_XS = 16,
    IQ3_XXS = 17,
    IQ1_S = 18,
    IQ4_NL = 19,
    IQ3_S = 20,
    IQ2_S = 21,
    IQ4_XS = 22,
    I8 = 23,
    I16 = 24,
    I32 = 25,
    I64 = 26,
    F64 = 27,
    IQ1_M = 28,
    BF16 = 29,
};

pub const GgufMetadata = struct {
    version: u32,
    tensor_count: u64,
    kv_count: u64,
    alignment: u32,
    arch: ?[]const u8,
    quantization: ?[]const u8,
    name: ?[]const u8,
    description: ?[]const u8,
};

pub const GgufFile = struct {
    metadata: GgufMetadata,
    tensors: std.ArrayList(GgufTensor),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GgufFile) void {
        for (self.tensors.items) |*t| {
            self.allocator.free(t.name);
        }
        self.tensors.deinit();
        if (self.metadata.arch) |a| self.allocator.free(a);
        if (self.metadata.quantization) |q| self.allocator.free(q);
        if (self.metadata.name) |n| self.allocator.free(n);
        if (self.metadata.description) |d| self.allocator.free(d);
    }
};

pub const ParseError = error{
    InvalidMagic,
    UnsupportedVersion,
    InvalidType,
    UnexpectedEof,
    OutOfMemory,
    InvalidAlignment,
};

pub fn parse(allocator: std.mem.Allocator, path: []const u8) !GgufFile {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return ParseError.UnexpectedEof,
        error.AccessDenied => return ParseError.UnexpectedEof,
        else => return err,
    };
    defer file.close();

    const stat = try file.stat();
    const data = file.readToEndAlloc(allocator, stat.size) catch |err| switch (err) {
        error.OutOfMemory => return ParseError.OutOfMemory,
        else => return ParseError.UnexpectedEof,
    };
    defer allocator.free(data);

    return parseFromMemory(allocator, data);
}

pub fn parseFromMemory(allocator: std.mem.Allocator, data: []const u8) ParseError!GgufFile {
    var offset: usize = 0;

    if (data.len < 4) return ParseError.UnexpectedEof;
    if (!std.mem.eql(u8, data[0..4], GGUF_MAGIC)) return ParseError.InvalidMagic;
    offset += 4;

    const version = try readU32(data, &offset);
    if (version != 2 and version != 3) return ParseError.UnsupportedVersion;

    const tensor_count = try readU64(data, &offset);
    const kv_count = try readU64(data, &offset);

    var metadata = parseMetadata(allocator, data, &offset, kv_count) catch return ParseError.UnexpectedEof;
    metadata.version = version;
    metadata.tensor_count = tensor_count;
    metadata.kv_count = kv_count;

    const alignment = metadata.alignment;
    const data_offset = alignOffset(offset, alignment);

    var tensors = std.ArrayList(GgufTensor).init(allocator);
    errdefer tensors.deinit();

    var i: usize = 0;
    while (i < tensor_count) : (i += 1) {
        const name_len = try readU64(data, &offset);
        if (offset + name_len > data.len) return ParseError.UnexpectedEof;
        const name = try allocator.dupe(u8, data[offset .. offset + name_len]);
        offset += name_len;

        const n_dims = try readU32(data, &offset);
        var ne: [4]u64 = .{ 1, 1, 1, 1 };
        var j: usize = 0;
        while (j < n_dims) : (j += 1) {
            ne[j] = try readU64(data, &offset);
        }

        const dtype_raw = try readU32(data, &offset);
        const dtype: GgufType = std.meta.intToEnum(GgufType, dtype_raw) catch return ParseError.InvalidType;

        const tensor_offset = try readU64(data, &offset);

        try tensors.append(GgufTensor{
            .name = name,
            .n_dims = n_dims,
            .ne = ne,
            .offset = data_offset + tensor_offset,
            .dtype = dtype,
        });
    }

    return GgufFile{
        .metadata = metadata,
        .tensors = tensors,
        .allocator = allocator,
    };
}

fn parseMetadata(allocator: std.mem.Allocator, data: []const u8, offset: *usize, count: u64) ParseError!GgufMetadata {
    var metadata = GgufMetadata{
        .version = 0,
        .tensor_count = 0,
        .kv_count = 0,
        .alignment = 32,
        .arch = null,
        .quantization = null,
        .name = null,
        .description = null,
    };

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const key_len = try readU64(data, offset);
        if (offset.* + key_len > data.len) return ParseError.UnexpectedEof;
        const key = data[offset.* .. offset.* + key_len];
        offset.* += key_len;

        const value_type = try readU32(data, offset);
        _ = try readValue(allocator, data, offset, value_type, key, &metadata);
    }

    return metadata;
}

const ValueType = enum(u32) {
    UINT8 = 0,
    INT8 = 1,
    UINT16 = 2,
    INT16 = 3,
    UINT32 = 4,
    INT32 = 5,
    FLOAT32 = 6,
    BOOL = 7,
    STRING = 8,
    ARRAY = 9,
    UINT64 = 10,
    INT64 = 11,
    FLOAT64 = 12,
};

fn readValue(
    allocator: std.mem.Allocator,
    data: []const u8,
    offset: *usize,
    type_raw: u32,
    key: []const u8,
    metadata: *GgufMetadata,
) ParseError!void {
    const vtype: ValueType = std.meta.intToEnum(ValueType, type_raw) catch return ParseError.InvalidType;

    switch (vtype) {
        .UINT8, .INT8 => { _ = try readU8(data, offset); },
        .UINT16, .INT16 => { _ = try readU16(data, offset); },
        .UINT32, .INT32 => { _ = try readU32(data, offset); },
        .FLOAT32 => { _ = try readF32(data, offset); },
        .BOOL => { _ = try readU8(data, offset); },
        .STRING => {
            const str = try readString(allocator, data, offset);
            defer allocator.free(str);

            if (std.mem.eql(u8, key, "general.architecture")) {
                metadata.arch = try allocator.dupe(u8, str);
            } else if (std.mem.eql(u8, key, "general.quantization_version")) {
                metadata.quantization = try allocator.dupe(u8, str);
            } else if (std.mem.eql(u8, key, "general.name")) {
                metadata.name = try allocator.dupe(u8, str);
            } else if (std.mem.eql(u8, key, "general.description")) {
                metadata.description = try allocator.dupe(u8, str);
            } else if (std.mem.eql(u8, key, "general.alignment")) {
                metadata.alignment = std.fmt.parseInt(u32, str, 10) catch 32;
            }
        },
        .ARRAY => {
            const arr_type = try readU32(data, offset);
            const arr_len = try readU64(data, offset);
            var j: usize = 0;
            while (j < arr_len) : (j += 1) {
                _ = try readValue(allocator, data, offset, arr_type, "", metadata);
            }
        },
        .UINT64, .INT64 => { _ = try readU64(data, offset); },
        .FLOAT64 => { _ = try readF64(data, offset); },
    }
}

fn readU8(data: []const u8, offset: *usize) ParseError!u8 {
    if (offset.* + 1 > data.len) return ParseError.UnexpectedEof;
    const val = data[offset.*];
    offset.* += 1;
    return val;
}

fn readU16(data: []const u8, offset: *usize) ParseError!u16 {
    if (offset.* + 2 > data.len) return ParseError.UnexpectedEof;
    const buf: *const [2]u8 = @ptrCast(data[offset.*..][0..2].ptr);
    const val = std.mem.readInt(u16, buf, .little);
    offset.* += 2;
    return val;
}

fn readU32(data: []const u8, offset: *usize) ParseError!u32 {
    if (offset.* + 4 > data.len) return ParseError.UnexpectedEof;
    const buf: *const [4]u8 = @ptrCast(data[offset.*..][0..4].ptr);
    const val = std.mem.readInt(u32, buf, .little);
    offset.* += 4;
    return val;
}

fn readU64(data: []const u8, offset: *usize) ParseError!u64 {
    if (offset.* + 8 > data.len) return ParseError.UnexpectedEof;
    const buf: *const [8]u8 = @ptrCast(data[offset.*..][0..8].ptr);
    const val = std.mem.readInt(u64, buf, .little);
    offset.* += 8;
    return val;
}

fn readF32(data: []const u8, offset: *usize) ParseError!f32 {
    if (offset.* + 4 > data.len) return ParseError.UnexpectedEof;
    const buf: *const [4]u8 = @ptrCast(data[offset.*..][0..4].ptr);
    const val = std.mem.readInt(u32, buf, .little);
    offset.* += 4;
    return @bitCast(val);
}

fn readF64(data: []const u8, offset: *usize) ParseError!f64 {
    if (offset.* + 8 > data.len) return ParseError.UnexpectedEof;
    const buf: *const [8]u8 = @ptrCast(data[offset.*..][0..8].ptr);
    const val = std.mem.readInt(u64, buf, .little);
    offset.* += 8;
    return @bitCast(val);
}

fn readString(allocator: std.mem.Allocator, data: []const u8, offset: *usize) ParseError![]const u8 {
    const len = try readU64(data, offset);
    if (offset.* + len > data.len) return ParseError.UnexpectedEof;
    const str = try allocator.dupe(u8, data[offset.* .. offset.* + len]);
    offset.* += len;
    return str;
}

fn alignOffset(offset: usize, alignment: u32) usize {
    const al = @as(usize, @intCast(alignment));
    return (offset + al - 1) & ~(al - 1);
}

pub fn tensorSizeBytes(tensor: GgufTensor) u64 {
    var elements: u64 = 1;
    var i: usize = 0;
    while (i < tensor.n_dims) : (i += 1) {
        elements *= tensor.ne[i];
    }

    const type_size = switch (tensor.dtype) {
        .F32 => 4,
        .F16, .BF16 => 2,
        .F64 => 8,
        .Q4_0, .Q4_1 => @divFloor(elements, 2),
        .Q5_0, .Q5_1 => @divFloor(elements * 5, 8),
        .Q8_0, .Q8_1 => elements,
        .Q2_K => @divFloor(elements, 4),
        .Q3_K => @divFloor(elements * 3, 8),
        .Q4_K => @divFloor(elements, 2),
        .Q5_K => @divFloor(elements * 5, 8),
        .Q6_K => @divFloor(elements * 6, 8),
        .I8 => 1,
        .I16 => 2,
        .I32 => 4,
        .I64 => 8,
        else => 4,
    };

    return elements * type_size;
}

pub fn generateAlkaInstructions(
    allocator: std.mem.Allocator,
    gguf: *const GgufFile,
    target_vessel: []const u8,
    output_buffer: u64,
) ![]const u8 {
    var instructions = std.ArrayList(u8).init(allocator);
    errdefer instructions.deinit();

    const writer = instructions.writer();

    try writer.print("// Auto-generated from GGUF: {s}\n", .{gguf.metadata.arch orelse "unknown"});
    try writer.print("// Tensors: {} | Alignment: {}\n\n", .{ gguf.metadata.tensor_count, gguf.metadata.alignment });

    for (gguf.tensors.items) |tensor| {
        const size = tensorSizeBytes(tensor);
        const src = tensor.offset;
        const dst = output_buffer + tensor.offset;

        try writer.print("FLOW {s} 0x{x} 0x{x} {d}\n", .{
            target_vessel,
            src,
            dst,
            size,
        });
        try writer.print("SYNC\n\n", .{});
    }

    return instructions.toOwnedSlice();
}
