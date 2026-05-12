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
const alka_bin = @import("../codegen/alka_bin.zig");

pub const MockGpuState = struct {
    vram: []u8,
    vram_size: u64,
    bar0: [1024]u8,
    bar1_window_offset: u64,
    bar1_window_size: u64,
    temperature: u32,
    temperature_ramp: u32,
    metapage_value: u32,
    dma_transfers: u64,
    bytes_transferred: u64,
    cycles_spent: u64,
    initialized: bool,
    claimed: bool,
    veiled: bool,
    isolated: bool,
    thermal_halt: u32,
    thermal_throttle: u32,
    fence_expected: u32,
    fence_timeout_ms: u32,

    pub fn init(allocator: std.mem.Allocator, vram_mb: u64) !MockGpuState {
        const vram = try allocator.alloc(u8, vram_mb * 1024 * 1024);
        @memset(vram, 0);
        return MockGpuState{
            .vram = vram,
            .vram_size = vram_mb * 1024 * 1024,
            .bar0 = [_]u8{0} ** 1024,
            .bar1_window_offset = 0,
            .bar1_window_size = 256 * 1024 * 1024,
            .temperature = 35000,
            .temperature_ramp = 50,
            .metapage_value = 0,
            .dma_transfers = 0,
            .bytes_transferred = 0,
            .cycles_spent = 0,
            .initialized = false,
            .claimed = false,
            .veiled = false,
            .isolated = false,
            .thermal_halt = 85000,
            .thermal_throttle = 80000,
            .fence_expected = 0,
            .fence_timeout_ms = 5000,
        };
    }

    pub fn deinit(self: *MockGpuState, allocator: std.mem.Allocator) void {
        allocator.free(self.vram);
    }

    pub fn vramWrite(self: *MockGpuState, offset: u64, data: []const u8) !void {
        if (offset + data.len > self.vram_size) {
            return error.VramOverflow;
        }
        @memcpy(self.vram[offset .. offset + data.len], data);
    }

    pub fn vramRead(self: *MockGpuState, offset: u64, buf: []u8) !void {
        if (offset + buf.len > self.vram_size) {
            return error.VramOverflow;
        }
        @memcpy(buf, self.vram[offset .. offset + buf.len]);
    }

    pub fn rampTemperature(self: *MockGpuState) void {
        if (self.dma_transfers > 0) {
            self.temperature += 200;
        } else {
            self.temperature += 50;
        }
        if (self.temperature > 100000) self.temperature = 100000;
    }

    pub fn checkThermal(self: *MockGpuState) !void {
        if (self.temperature >= self.thermal_halt) {
            return error.ThermalHalt;
        }
        if (self.temperature >= self.thermal_throttle) {
            self.temperature_ramp = @divTrunc(self.temperature_ramp, 2);
        }
    }
};

pub const MockExecutor = struct {
    gpu: MockGpuState,
    allocator: std.mem.Allocator,
    log: std.ArrayList(LogEntry),
    packet_count: usize,
    error_packet: ?usize,

    pub const LogEntry = struct {
        packet_index: usize,
        opcode: u8,
        opcode_name: []const u8,
        src: u64,
        dst: u64,
        size: u32,
        status: []const u8,
        detail: []const u8,
        detail_owned: bool,
    };

    pub fn init(allocator: std.mem.Allocator, vram_mb: u64) !MockExecutor {
        return MockExecutor{
            .gpu = try MockGpuState.init(allocator, vram_mb),
            .allocator = allocator,
            .log = std.ArrayList(LogEntry).init(allocator),
            .packet_count = 0,
            .error_packet = null,
        };
    }

    pub fn deinit(self: *MockExecutor) void {
        self.gpu.deinit(self.allocator);
        self.log.deinit();
    }

    pub fn execute(self: *MockExecutor, alkas: []const u8) !void {
        const packet_size = @sizeOf(alka_bin.MetrodPacket);
        var i: usize = 0;

        while (i + packet_size <= alkas.len) : (i += packet_size) {
            var packet: alka_bin.MetrodPacket = undefined;
            @memcpy(std.mem.asBytes(&packet), alkas[i .. i + packet_size]);

            if (packet.flags & 0x80 != 0) continue;

            try self.executePacket(&packet, self.packet_count);
            self.packet_count += 1;

            self.gpu.rampTemperature();
            try self.gpu.checkThermal();
        }
    }

    fn executePacket(self: *MockExecutor, packet: *const alka_bin.MetrodPacket, idx: usize) !void {
        const opcode_name = opcodeName(packet.op_code);
        var status: []const u8 = "OK";
        var detail: ?[]const u8 = null;

        switch (packet.op_code) {
            0x01 => {
                self.gpu.claimed = true;
                self.gpu.initialized = true;
                detail = try std.fmt.allocPrint(self.allocator, "GPU claimed, VRAM {d}MB ready", .{self.gpu.vram_size / (1024 * 1024)});
            },
            0x02 => {
                detail = try std.fmt.allocPrint(self.allocator, "Staked {d} bytes at 0x{x}", .{ packet.size, packet.src_addr });
            },
            0x03 => {
                try self.gpu.checkThermal();
                const vram_offset = packet.dst_addr % self.gpu.vram_size;
                if (packet.size > 0) {
                    const buf = try self.allocator.alloc(u8, packet.size);
                    defer self.allocator.free(buf);
                    @memset(buf, 0xAA);
                    try self.gpu.vramWrite(vram_offset, buf);
                }
                self.gpu.dma_transfers += 1;
                self.gpu.bytes_transferred += packet.size;
                self.gpu.metapage_value = packet.vessel_id;
                detail = try std.fmt.allocPrint(self.allocator, "DMA {d}B to VRAM 0x{x} (transfer #{d})", .{ packet.size, vram_offset, self.gpu.dma_transfers });
            },
            0x04 => {
                self.gpu.bar1_window_offset = packet.src_addr;
                detail = try std.fmt.allocPrint(self.allocator, "BAR1 window shifted to 0x{x}", .{packet.src_addr});
            },
            0x05 => {
                if (self.gpu.metapage_value != @as(u32, @truncate(packet.dst_addr))) {
                    status = "TIMEOUT";
                    detail = try std.fmt.allocPrint(self.allocator, "Fence: expected {d}, got {d}", .{ packet.dst_addr, self.gpu.metapage_value });
                    self.error_packet = idx;
                } else {
                    detail = try std.fmt.allocPrint(self.allocator, "Fence passed (value={d})", .{self.gpu.metapage_value});
                }
            },
            0x06 => {
                self.gpu.cycles_spent += 1;
                detail = "Memory barrier";
            },
            0x07 => {
                detail = try std.fmt.allocPrint(self.allocator, "Temp: {d} mC ({d} C)", .{ self.gpu.temperature, self.gpu.temperature / 1000 });
            },
            0x08 => {
                detail = try std.fmt.allocPrint(self.allocator, "Pulse pin={d} freq={d}Hz", .{ packet.src_addr, packet.size });
            },
            0x09 => {
                detail = try std.fmt.allocPrint(self.allocator, "Signal vector={d}", .{packet.src_addr});
            },
            0x0A => {
                self.gpu.cycles_spent += 100;
                detail = "Yielded";
            },
            0x0B => {
                detail = "FPGA reconfigure (simulated)";
            },
            0x0C => {
                detail = "State snapshotted";
            },
            0x0D => {
                detail = "State restored";
            },
            0x0E => {
                var value = if (packet.size > 0) packet.size else @as(u32, @truncate(packet.dst_addr));
                if (value == 0) value = 85000; // Default 85C
                self.gpu.thermal_halt = value;
                detail = try std.fmt.allocPrint(self.allocator, "Thermal halt set to {d} mC", .{value});
            },
            0x0F => {
                self.gpu.veiled = true;
                detail = "Device veiled from OS";
            },
            0x11 => {
                detail = try std.fmt.allocPrint(self.allocator, "Rhythm freq={d}Hz", .{packet.size});
            },
            0x14 => {
                detail = "Full state dump";
            },
            0x17 => {
                detail = "Echo read (non-intrusive)";
            },
            0x18 => {
                detail = "Bus locked (simulated)";
            },
            0x1B => {
                detail = "Fossilized to Option ROM";
            },
            0x1C => {
                detail = "Strike (simulated)";
            },
            0x1D => {
                self.gpu.temperature = 35000;
                self.gpu.temperature_ramp = 50;
                detail = "Emergency cool-down";
            },
            0x1E => {
                detail = "FPGA bitstream injected";
            },
            0x1F => {
                detail = "Secure erase (simulated)";
            },
            0x2A => {
                detail = "Cache invalidated";
            },
            0x2B => {
                detail = "Audit: no residue";
            },
            0x2C => {
                status = "DRY_RUN";
                detail = "Simulated only";
            },
            0x2D => {
                status = "MOCK";
                detail = "Mock hardware";
            },
            0x2E => {
                status = "PROVE";
                detail = "Formal verification passed";
            },
            0x2F => {
                detail = try std.fmt.allocPrint(self.allocator, "Watch target={d}", .{packet.src_addr});
            },
            0x30 => {
                detail = "Trace enabled";
            },
            0x31 => {
                const value = if (packet.size > 0) packet.size else @as(u32, @truncate(packet.dst_addr));
                self.gpu.thermal_throttle = value;
                detail = try std.fmt.allocPrint(self.allocator, "Guard threshold={d} mC", .{value});
            },
            0x32 => {
                self.gpu.isolated = true;
                detail = "Hardware isolated";
            },
            0x33 => {
                detail = "Cryptographic verification passed";
            },
            0x34 => {
                detail = try std.fmt.allocPrint(self.allocator, "Core {d} pinned", .{packet.src_addr});
            },
            0x35 => {
                detail = try std.fmt.allocPrint(self.allocator, "Bond RAM 0x{x} to GPU 0x{x}", .{ packet.src_addr, packet.dst_addr });
            },
            0x36 => {
                detail = try std.fmt.allocPrint(self.allocator, "DRAM refresh bank={d}", .{packet.src_addr});
            },
            0x37 => {
                detail = "Reset coordinated";
            },
            0x38 => {
                detail = "Dual-bank refresh";
            },
            0x39 => {
                detail = try std.fmt.allocPrint(self.allocator, "IMC channel={d}", .{packet.src_addr});
            },
            0x3A => {
                self.gpu.isolated = true;
                detail = "PCIe device seized";
            },
            0x3B => {
                const total = packet.dst_addr;
                const chunk = if (packet.size > 0) packet.size else 256 * 1024 * 1024;
                const drops = if (chunk > 0) (total + chunk - 1) / chunk else 0;
                detail = try std.fmt.allocPrint(self.allocator, "Tensor sliced: {d}MB → {d} drops of {d}MB", .{
                    total / (1024 * 1024), drops, chunk / (1024 * 1024),
                });
            },
            0x3C => {
                self.gpu.cycles_spent += 100;
                const ring_size = packet.dst_addr;
                const flags = packet.size;
                detail = try std.fmt.allocPrint(self.allocator, "Ring buffer {d}MB established (flags=0x{x}) — CPU exits, DMA loops", .{
                    ring_size / (1024 * 1024), flags,
                });
            },
            else => {
                status = "UNKNOWN";
                detail = try std.fmt.allocPrint(self.allocator, "Opcode 0x{x} not implemented", .{packet.op_code});
            },
        }

        try self.log.append(LogEntry{
            .packet_index = idx,
            .opcode = packet.op_code,
            .opcode_name = opcode_name,
            .src = packet.src_addr,
            .dst = packet.dst_addr,
            .size = packet.size,
            .status = status,
            .detail = detail orelse "",
            .detail_owned = detail != null,
        });

        self.gpu.cycles_spent += 10;
    }

    pub fn printReport(self: *MockExecutor) void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║          VITRIOL Mock Execution Report                  ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════╣\n", .{});

        for (self.log.items) |entry| {
            const status_icon = if (std.mem.eql(u8, entry.status, "OK")) "  " else if (std.mem.eql(u8, entry.status, "DRY_RUN")) "~~" else if (std.mem.eql(u8, entry.status, "MOCK")) "~~" else if (std.mem.eql(u8, entry.status, "PROVE")) "~~" else "!!";
            std.debug.print("║ [{s}] {s:>12} 0x{x:>10} → 0x{x:>10} {d:>8}B  {s}\n", .{
                status_icon,
                entry.opcode_name,
                entry.src,
                entry.dst,
                entry.size,
                entry.detail,
            });
        }

        std.debug.print("╠══════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Packets executed:  {d:>38} ║\n", .{self.packet_count});
        std.debug.print("║  DMA transfers:     {d:>38} ║\n", .{self.gpu.dma_transfers});
        std.debug.print("║  Bytes to VRAM:     {d:>38} ║\n", .{self.gpu.bytes_transferred});
        std.debug.print("║  Cycles spent:      {d:>38} ║\n", .{self.gpu.cycles_spent});
        std.debug.print("║  Final temperature: {d:>33} mC ║\n", .{self.gpu.temperature});
        std.debug.print("║  VRAM used:         {d:>38} ║\n", .{self.gpu.vram_size / (1024 * 1024)});
        std.debug.print("║  GPU claimed:       {s:>38} ║\n", .{if (self.gpu.claimed) "YES" else "NO"});
        std.debug.print("║  GPU veiled:        {s:>38} ║\n", .{if (self.gpu.veiled) "YES" else "NO"});
        std.debug.print("║  GPU isolated:      {s:>38} ║\n", .{if (self.gpu.isolated) "YES" else "NO"});
        std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
    }
};

fn opcodeName(code: u8) []const u8 {
    return switch (code) {
        0x01 => "CLAIM",
        0x02 => "STAKE",
        0x03 => "FLOW",
        0x04 => "SHIFT",
        0x05 => "FENCE",
        0x06 => "SYNC",
        0x07 => "SENSE",
        0x08 => "PULSE",
        0x09 => "SIGNAL",
        0x0A => "YIELD",
        0x0B => "RECAST",
        0x0C => "SNAP",
        0x0D => "REVERT",
        0x0E => "LIMIT",
        0x0F => "VEIL",
        0x11 => "RHYTHM",
        0x14 => "MOLT",
        0x17 => "ECHO",
        0x18 => "STASIS",
        0x1B => "FOSSILIZE",
        0x1C => "STRIKE",
        0x1D => "QUENCH",
        0x1E => "FORGE",
        0x1F => "VOID",
        0x2A => "FLUX",
        0x2B => "AUDIT",
        0x2C => "DRY_RUN",
        0x2D => "MOCK",
        0x2E => "PROVE",
        0x2F => "WATCH",
        0x30 => "TRACE",
        0x31 => "GUARD",
        0x32 => "ISOLATE",
        0x33 => "VERIFY",
        0x34 => "OSSIFY",
        0x35 => "BOND",
        0x36 => "STILL",
        0x37 => "RESONATE",
        0x38 => "OSCILLATE",
        0x39 => "IMC_HIJACK",
        0x3A => "OCCUPY",
        0x3B => "REFRACT",
        0x3C => "PIPE",
        else => "UNKNOWN",
    };
}
