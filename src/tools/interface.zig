const std = @import("std");

pub const ToolInterface = struct {
    pub const OpCode = @import("../../instructions/mod.zig").OpCode;
    pub const Context = struct {
        physical_addr: u64,
        pci_bus: u8,
        pci_device: u8,
        pci_function: u8,
        bar_base: u64,
        aperture_size: u64,
        thermal_limit: u64,
        current_temp: u64,
    };

    pub const Result = struct {
        success: bool,
        cycles_spent: u64,
        bytes_transferred: u64,
        error_message: ?[]const u8,
    };

    pub const ValidateError = error{
        VesselNotFound,
        ApertureOverflow,
        ThermalLimitExceeded,
        InvalidAlignment,
        ProhibitedRange,
    };

    pub const ValidateResult = struct {
        allowed: bool,
        injected_operations: []const []const u8,
        reason: ?[]const u8,
    };

    pub fn validate(
        code: OpCode,
        operands: []const u64,
        ctx: Context,
    ) ValidateError!ValidateResult {
        _ = code;
        _ = operands;
        _ = ctx;
        return ValidateResult{ .allowed = true, .injected_operations = &.{} };
    }

    pub fn execute(
        code: OpCode,
        operands: []const u64,
        ctx: Context,
    ) Result {
        _ = code;
        _ = operands;
        _ = ctx;
        return Result{ .success = false, .cycles_spent = 0, .bytes_transferred = 0, .error_message = "Not implemented" };
    }
};