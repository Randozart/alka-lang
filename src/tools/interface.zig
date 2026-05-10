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