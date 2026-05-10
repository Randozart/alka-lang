const std = @import("std");
const parser = @import("../parser/parser.zig");

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

pub const OpCodes = struct {
    pub const CLAIM: u8 = 0x01;
    pub const STAKE: u8 = 0x02;
    pub const FLOW: u8 = 0x03;
    pub const SHIFT: u8 = 0x04;
    pub const FENCE: u8 = 0x05;
    pub const SYNC: u8 = 0x06;
    pub const SENSE: u8 = 0x07;
    pub const PULSE: u8 = 0x08;
    pub const SIGNAL: u8 = 0x09;
    pub const YIELD: u8 = 0x0A;
    pub const RECAST: u8 = 0x0B;
    pub const SNAP: u8 = 0x0C;
    pub const REVERT: u8 = 0x0D;
    pub const LIMIT: u8 = 0x0E;
};

fn computeCrc(packet: *const MetrodPacket) u32 {
    var crc: u32 = 0;
    const bytes: [*]const u8 = @ptrCast(packet);
    for (0..@sizeOf(MetrodPacket)) |i| {
        crc = (crc << 1) | (crc >> 31);
        crc ^= bytes[i];
    }
    return crc;
}

fn evalExpr(expr: parser.Expression) u64 {
    return switch (expr) {
        .literal => |v| v,
        .memory_size => |m| m.value * switch (m.unit[0]) {
            'M' => 1024 * 1024,
            'G' => 1024 * 1024 * 1024,
            else => 1,
        },
        .identifier => 0,
        .indexed => |idx| evalExpr(idx.index),
    };
}

pub fn emitMetrod(program: parser.Program, vial: parser.Vial, arena: *std.heap.ArenaAllocator) ![]u8 {
    var packets = std.ArrayList(MetrodPacket).init(arena.allocator());
    var vessel_ids = std.StringArrayHashMap(u16).init(arena.allocator());

    var id: u16 = 0;
    for (vial.vessels.keys()) |key| {
        try vessel_ids.put(key, id);
        id += 1;
    }

    for (program.instructions.items) |instr| {
        switch (instr) {
            .claim => |c| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.CLAIM,
                    .flags = 0,
                    .vessel_id = vessel_ids.get(c.target) orelse 0,
                    .src_addr = 0,
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .flow => |f| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.FLOW,
                    .flags = 0,
                    .vessel_id = 0,
                    .src_addr = evalExpr(f.src),
                    .dst_addr = evalExpr(f.dst),
                    .size = @truncate(evalExpr(f.size)),
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .shift => |s| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.SHIFT,
                    .flags = 0,
                    .vessel_id = vessel_ids.get(s.vessel) orelse 0,
                    .src_addr = evalExpr(s.offset),
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .fence => |fc| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.FENCE,
                    .flags = 0,
                    .vessel_id = vessel_ids.get(fc.vessel) orelse 0,
                    .src_addr = 0,
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .sync => |sy| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.SYNC,
                    .flags = sy.level,
                    .vessel_id = 0,
                    .src_addr = 0,
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .pulse => |p| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.PULSE,
                    .flags = 0,
                    .vessel_id = vessel_ids.get(p.target) orelse 0,
                    .src_addr = evalExpr(p.freq),
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .stake => |st| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.STAKE,
                    .flags = 0,
                    .vessel_id = 0,
                    .src_addr = evalExpr(st.addr),
                    .dst_addr = 0,
                    .size = @truncate(evalExpr(st.len)),
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .sense => |se| {
                _ = se;
            },
            .yield => |y| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.YIELD,
                    .flags = 0,
                    .vessel_id = 0,
                    .src_addr = y.micros,
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .signal => |si| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.SIGNAL,
                    .flags = 0,
                    .vessel_id = 0,
                    .src_addr = si.vector,
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .recast => |r| {
                _ = r;
            },
            .snap => |sn| {
                _ = sn;
            },
            .revert => |rev| {
                _ = rev;
            },
            .limit => |l| {
                var packet = std.mem.zeroInit(MetrodPacket, .{
                    .op_code = OpCodes.LIMIT,
                    .flags = 0,
                    .vessel_id = vessel_ids.get(l.vessel) orelse 0,
                    .src_addr = evalExpr(l.value),
                    .dst_addr = 0,
                    .size = 0,
                    .reserved = 0,
                    .crc = 0,
                });
                packet.crc = computeCrc(&packet);
                try packets.append(packet);
            },
            .require => {},
        }
    }

    const total_bytes = packets.items.len * @sizeOf(MetrodPacket);
    const result = try arena.allocator().alloc(u8, total_bytes);

    var offset: usize = 0;
    for (packets.items) |packet| {
        const packet_bytes: [*]u8 = @ptrCast(&packet);
        std.mem.copyForwards(u8, result[offset..], packet_bytes[0..@sizeOf(MetrodPacket)]);
        offset += @sizeOf(MetrodPacket);
    }

    return result;
}