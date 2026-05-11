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

pub const claim = @import("core/claim.zig");
pub const flow = @import("core/flow.zig");
pub const shift = @import("core/shift.zig");
pub const misc = @import("core/misc.zig");
pub const veil = @import("core/veil.zig");
pub const substrate = @import("substrate/");
pub const ossify = @import("substrate/ossify.zig");
pub const bond = @import("substrate/bond.zig");
pub const still = @import("substrate/still.zig");
pub const resonate = @import("substrate/resonate.zig");
pub const oscillate = @import("substrate/oscillate.zig");
pub const imc_hijack = @import("substrate/imc_hijack.zig");
pub const occupy = @import("substrate/occupy.zig");
pub const strike = @import("substrate/strike.zig");
pub const forging = @import("forging/");
pub const void_tool = @import("forging/void.zig");
pub const pulse = @import("pulse/");
pub const sense = @import("pulse/sense.zig");

pub const Tool = struct {
    pub const Context = @import("interface.zig").ToolInterface.Context;
    pub const Result = @import("interface.zig").ToolInterface.Result;
    pub const ValidateResult = @import("interface.zig").ToolInterface.ValidateResult;
    pub const ValidateError = @import("interface.zig").ToolInterface.ValidateError;

    pub const ValidateFn = *const fn (operands: []const u64, ctx: Context) ValidateError!ValidateResult;
    pub const ExecuteFn = *const fn (operands: []const u64, ctx: Context) Result;

    name: []const u8,
    description: []const u8,
    validate: ValidateFn,
    execute: ExecuteFn,
};

pub fn getTool(op_code: u8) ?Tool {
    return switch (op_code) {
        0x01 => Tool{ .name = "CLAIM", .description = "Stake hardware node", .validate = claim.CLAIM.validate, .execute = claim.CLAIM.execute },
        0x02 => Tool{ .name = "STAKE", .description = "Claim memory region", .validate = genericValidate, .execute = genericExecute },
        0x03 => Tool{ .name = "FLOW", .description = "DMA transfer", .validate = flow.FLOW.validate, .execute = flow.FLOW.execute },
        0x04 => Tool{ .name = "SHIFT", .description = "Remap BAR window", .validate = shift.SHIFT.validate, .execute = shift.SHIFT.execute },
        0x05 => Tool{ .name = "FENCE", .description = "Wait for condition", .validate = misc.FENCE.validate, .execute = misc.FENCE.execute },
        0x06 => Tool{ .name = "SYNC", .description = "Memory barrier", .validate = misc.SYNC.validate, .execute = misc.SYNC.execute },
        0x07 => Tool{ .name = "SENSE", .description = "Read sensor", .validate = sense.SENSE.validate, .execute = sense.SENSE.execute },
        0x08 => Tool{ .name = "PULSE", .description = "Timing signal", .validate = genericValidate, .execute = genericExecute },
        0x09 => Tool{ .name = "SIGNAL", .description = "Trigger interrupt", .validate = misc.SIGNAL.validate, .execute = misc.SIGNAL.execute },
        0x0A => Tool{ .name = "YIELD", .description = "Cooperative yield", .validate = misc.YIELD.validate, .execute = misc.YIELD.execute },
        0x0B => Tool{ .name = "RECAST", .description = "FPGA reconfigure", .validate = genericValidate, .execute = genericExecute },
        0x0C => Tool{ .name = "SNAP", .description = "Serialize state", .validate = genericValidate, .execute = genericExecute },
        0x0D => Tool{ .name = "REVERT", .description = "Restore state", .validate = genericValidate, .execute = genericExecute },
        0x0E => Tool{ .name = "LIMIT", .description = "Hard contract", .validate = genericValidate, .execute = genericExecute },
        0x0F => Tool{ .name = "VEIL", .description = "Hide from OS", .validate = veil.VEIL.validate, .execute = veil.VEIL.execute },
        0x1C => Tool{ .name = "STRIKE", .description = "Rowhammer/bit flipping", .validate = strike.STRIKE.validate, .execute = strike.STRIKE.execute },
        0x1F => Tool{ .name = "VOID", .description = "Secure substrate erase", .validate = void_tool.VOID.validate, .execute = void_tool.VOID.execute },
        0x34 => Tool{ .name = "OSSIFY", .description = "Pin CPU core to Alka", .validate = ossify.OSSIFY.validate, .execute = ossify.OSSIFY.execute },
        0x35 => Tool{ .name = "BOND", .description = "RAM-to-GPU direct tunnel", .validate = bond.BOND.validate, .execute = bond.BOND.execute },
        0x36 => Tool{ .name = "STILL", .description = "Manual DRAM refresh control", .validate = still.STILL.validate, .execute = still.STILL.execute },
        0x37 => Tool{ .name = "RESONATE", .description = "Coordinate reset for pure window", .validate = resonate.RESONATE.validate, .execute = resonate.RESONATE.execute },
        0x38 => Tool{ .name = "OSCILLATE", .description = "Dual-bank refresh coordination", .validate = oscillate.OSCILLATE.validate, .execute = oscillate.OSCILLATE.execute },
        0x39 => Tool{ .name = "IMC_HIJACK", .description = "Direct memory controller access", .validate = imc_hijack.IMC_HIJACK.validate, .execute = imc_hijack.IMC_HIJACK.execute },
        0x3A => Tool{ .name = "OCCUPY", .description = "Seize PCIe device - sever all OS access", .validate = occupy.OCCUPY.validate, .execute = occupy.OCCUPY.execute },
        else => null,
    };
}

fn genericValidate(operands: []const u64, ctx: Tool.Context) Tool.ValidateError!Tool.ValidateResult {
    _ = operands;
    _ = ctx;
    return Tool.ValidateResult{ .allowed = true, .injected_operations = &.{}, .reason = null };
}

fn genericExecute(operands: []const u64, ctx: Tool.Context) Tool.Result {
    _ = operands;
    _ = ctx;
    return Tool.Result{ .success = true, .cycles_spent = 10, .bytes_transferred = 0, .error_message = null };
}