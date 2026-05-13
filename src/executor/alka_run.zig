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
const posix = std.posix;

pub const DEVICE_PATH = "/dev/vitriol";

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

pub const ApertureDesc = extern struct {
    bar: u8,
    physical_base: u64,
    size: u64,
    max_window: u64,
    is_prefetchable: u8,
    requires_sliding_window: u8,
    name: [64]u8,
};

pub const ThermalDesc = extern struct {
    halt_at: u32,
    throttle_at: u32,
    sensor_path: [64]u8,
};

pub const VesselDesc = extern struct {
    vendor_id: u16,
    device_id: u16,
    bus: u8,
    slot: u8,
    function: u8,
    aperture_count: u8,
    name: [64]u8,
    apertures: [8]ApertureDesc,
    thermal: ThermalDesc,
    dma_capable: u8,
    isolated: u8,
};

pub const VialDesc = extern struct {
    vessel_count: u32,
    vessels: [16]VesselDesc,
};

pub const ExecResult = extern struct {
    status: u32,
    packets_executed: u32,
    packets_total: u32,
    cycles_spent: u64,
    bytes_transferred: u64,
    thermal_peak: u32,
    error_packet: u32,
    error_msg: [256]u8,
};

pub const ExecuteRequest = extern struct {
    packets: [*]const u8,
    packet_count: u32,
    packet_size: u32,
    result: *ExecResult,
};

pub const ExecuteSafeRequest = extern struct {
    packets: [*]const u8,
    packet_count: u32,
    packet_size: u32,
    azoth_packets: [*]const u8,
    azoth_count: u32,
    result: *ExecResult,
};

pub const MapBarRequest = extern struct {
    vessel_id: u8,
    bar: u8,
    offset: u64,
    size: u64,
};

pub const UnmapBarRequest = extern struct {
    vessel_id: u8,
    bar: u8,
};

pub const ExecutionError = error{
    DeviceNotFound,
    PermissionDenied,
    IoctlFailed,
    LoadVialFailed,
    ExecutionFailed,
    ThermalThrottle,
    CrcFailure,
    Timeout,
    InvalidBinary,
};

fn ioctlNone(fd: posix.fd_t, request: u32) !void {
    const rc = posix.system.ioctl(fd, request, 0);
    if (posix.errno(rc) != .SUCCESS) return ExecutionError.IoctlFailed;
}

fn ioctlRead(fd: posix.fd_t, request: u32, value: *u32) !void {
    const rc = posix.system.ioctl(fd, request, @intFromPtr(value));
    if (posix.errno(rc) != .SUCCESS) return ExecutionError.IoctlFailed;
}

fn ioctlWrite(fd: posix.fd_t, request: u32, ptr: *anyopaque) !void {
    const rc = posix.system.ioctl(fd, request, @intFromPtr(ptr));
    if (posix.errno(rc) != .SUCCESS) return ExecutionError.IoctlFailed;
}

fn ioctlReadWrite(fd: posix.fd_t, request: u32, ptr: *anyopaque) !void {
    const rc = posix.system.ioctl(fd, request, @intFromPtr(ptr));
    if (posix.errno(rc) != .SUCCESS) return ExecutionError.IoctlFailed;
}

pub const Executor = struct {
    fd: posix.fd_t,
    vial_loaded: bool,

    pub fn open() !Executor {
        const fd = posix.open(DEVICE_PATH, .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
            error.AccessDenied => return ExecutionError.PermissionDenied,
            error.FileNotFound => return ExecutionError.DeviceNotFound,
            else => return ExecutionError.DeviceNotFound,
        };
        return Executor{ .fd = fd, .vial_loaded = false };
    }

    pub fn close(self: *Executor) void {
        posix.close(self.fd);
    }

    pub fn loadVial(self: *Executor, vial: *const VialDesc) !void {
        try ioctlWrite(self.fd, VITRIOL_IOC_LOAD_VIAL, @constCast(vial));
        self.vial_loaded = true;
    }

    pub fn execute(self: *Executor, packets: []const Drop) !ExecResult {
        var result: ExecResult = std.mem.zeroInit(ExecResult, .{});
        var req = ExecuteRequest{
            .packets = @ptrCast(packets.ptr),
            .packet_count = @intCast(packets.len),
            .packet_size = @sizeOf(Drop),
            .result = &result,
        };
        try ioctlReadWrite(self.fd, VITRIOL_IOC_EXECUTE, &req);
        try checkResult(&result);
        return result;
    }

    pub fn executeSafe(self: *Executor, alkas: []const Drop, azoth: []const Drop) !ExecResult {
        var result: ExecResult = std.mem.zeroInit(ExecResult, .{});
        var req = ExecuteSafeRequest{
            .packets = @ptrCast(alkas.ptr),
            .packet_count = @intCast(alkas.len),
            .packet_size = @sizeOf(Drop),
            .azoth_packets = @ptrCast(azoth.ptr),
            .azoth_count = @intCast(azoth.len),
            .result = &result,
        };
        try ioctlReadWrite(self.fd, VITRIOL_IOC_EXECUTE_SAFE, &req);
        try checkResult(&result);
        return result;
    }

    pub fn readThermal(self: *Executor) !u32 {
        var temp: u32 = 0;
        try ioctlRead(self.fd, VITRIOL_IOC_READ_THERMAL, &temp);
        return temp;
    }

    pub fn getState(self: *Executor) !ExecResult {
        var result: ExecResult = std.mem.zeroInit(ExecResult, .{});
        try ioctlRead(self.fd, VITRIOL_IOC_GET_STATE, @ptrCast(&result.status));
        return result;
    }

    pub fn setSafety(self: *Executor, level: u32) !void {
        try ioctlWrite(self.fd, VITRIOL_IOC_SET_SAFETY, @ptrCast(&level));
    }

    pub fn mapBar(self: *Executor, req: MapBarRequest) !void {
        try ioctlWrite(self.fd, VITRIOL_IOC_MAP_BAR, @constCast(&req));
    }

    pub fn unmapBar(self: *Executor, req: UnmapBarRequest) !void {
        try ioctlWrite(self.fd, VITRIOL_IOC_UNMAP_BAR, @constCast(&req));
    }

    pub fn heartbeat(self: *Executor) !void {
        try ioctlNone(self.fd, VITRIOL_IOC_HEARTBEAT);
    }

    pub fn queryOps(self: *Executor) !u64 {
        var ops: u64 = 0;
        try ioctlRead(self.fd, VITRIOL_IOC_QUERY_OPS, @ptrCast(&ops));
        return ops;
    }

    fn checkResult(result: *const ExecResult) !void {
        switch (result.status) {
            0 => {},
            1 => return ExecutionError.ExecutionFailed,
            2 => return ExecutionError.ThermalThrottle,
            3 => return ExecutionError.Timeout,
            4 => return ExecutionError.CrcFailure,
            else => return ExecutionError.ExecutionFailed,
        }
    }
};

pub fn loadAlkasFile(allocator: std.mem.Allocator, path: []const u8) ![]const Drop {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024 * 64);
    errdefer allocator.free(data);

    if (data.len % @sizeOf(Drop) != 0) {
        return ExecutionError.InvalidBinary;
    }

    const count = data.len / @sizeOf(Drop);
    const aligned: [*]align(@alignOf(Drop)) const u8 = @alignCast(data.ptr);
    const packets: [*]const Drop = @ptrCast(aligned);
    return packets[0..count];
}

pub fn run(
    allocator: std.mem.Allocator,
    alkas_path: []const u8,
    azoth_path: ?[]const u8,
    vial: ?*const VialDesc,
    safe_mode: bool,
) !ExecResult {
    var executor = try Executor.open();
    defer executor.close();

    if (vial) |v| {
        try executor.loadVial(v);
    }

    const alkas = try loadAlkasFile(allocator, alkas_path);
    defer allocator.free(@as([*]const u8, @ptrCast(alkas.ptr))[0 .. alkas.len * @sizeOf(Drop)]);

    if (safe_mode and azoth_path != null) {
        const azoth = try loadAlkasFile(allocator, azoth_path.?);
        defer allocator.free(@as([*]const u8, @ptrCast(azoth.ptr))[0 .. azoth.len * @sizeOf(Drop)]);
        return try executor.executeSafe(alkas, azoth);
    }

    return try executor.execute(alkas);
}

// IOCTL number computation (matches Linux _IO/_IOW/_IOR/_IOWR macros)
// _IO(type, nr) = ((type)<<8 | (nr))
// _IOW(type, nr, size) = ((1)<<30 | ((type)<<8) | (nr) | ((sizeof(size))<<16))
// _IOR(type, nr, size) = ((2)<<30 | ((type)<<8) | (nr) | ((sizeof(size))<<16))
// _IOWR(type, nr, size) = ((3)<<30 | ((type)<<8) | (nr) | ((sizeof(size))<<16))

const VITRIOL_IOC_MAGIC: u32 = 'V';

fn _IO(nr: u32) u32 {
    return (VITRIOL_IOC_MAGIC << 8) | nr;
}

fn _IOC_DIR_WRITE() u32 { return 1; }
fn _IOC_DIR_READ() u32 { return 2; }
fn _IOC_DIR_READWRITE() u32 { return 3; }

fn _IOW(nr: u32, comptime T: type) u32 {
    return (_IOC_DIR_WRITE() << 30) | (VITRIOL_IOC_MAGIC << 8) | nr | (@sizeOf(T) << 16);
}

fn _IOR(nr: u32, comptime T: type) u32 {
    return (_IOC_DIR_READ() << 30) | (VITRIOL_IOC_MAGIC << 8) | nr | (@sizeOf(T) << 16);
}

fn _IOWR(nr: u32, comptime T: type) u32 {
    return (_IOC_DIR_READWRITE() << 30) | (VITRIOL_IOC_MAGIC << 8) | nr | (@sizeOf(T) << 16);
}

const VITRIOL_IOC_LOAD_VIAL = _IOW(1, VialDesc);
const VITRIOL_IOC_EXECUTE = _IOWR(2, ExecuteRequest);
const VITRIOL_IOC_EXECUTE_SAFE = _IOWR(3, ExecuteSafeRequest);
const VITRIOL_IOC_GET_STATE = _IOR(4, ExecResult);
const VITRIOL_IOC_SET_SAFETY = _IOW(5, u32);
const VITRIOL_IOC_READ_THERMAL = _IOR(6, u32);
const VITRIOL_IOC_MAP_BAR = _IOW(7, MapBarRequest);
const VITRIOL_IOC_UNMAP_BAR = _IOW(8, UnmapBarRequest);
const VITRIOL_IOC_HEARTBEAT = _IO(9);
const VITRIOL_IOC_QUERY_OPS = _IOR(10, u64);
