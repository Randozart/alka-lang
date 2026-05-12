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
pub const fence = @import("core/fence.zig");
pub const sync = @import("core/sync.zig");
pub const signal = @import("core/signal.zig");
pub const yield_tool = @import("core/yield.zig");
pub const veil = @import("core/veil.zig");
pub const snap = @import("core/snap.zig");
pub const revert = @import("core/revert.zig");
pub const stake = @import("core/stake.zig");
pub const echo = @import("core/echo.zig");
pub const limit = @import("core/limit.zig");
pub const substrate = @import("substrate/");
pub const ossify = @import("substrate/ossify.zig");
pub const bond = @import("substrate/bond.zig");
pub const still = @import("substrate/still.zig");
pub const resonate = @import("substrate/resonate.zig");
pub const oscillate = @import("substrate/oscillate.zig");
pub const imc_hijack = @import("substrate/imc_hijack.zig");
pub const occupy = @import("substrate/occupy.zig");
pub const strike = @import("substrate/strike.zig");
pub const refract = @import("core/refract.zig");
pub const pipe = @import("core/pipe.zig");
pub const forging = @import("forging/");
pub const void_tool = @import("forging/void.zig");
pub const recast = @import("forging/recast.zig");
pub const forge_tool = @import("forging/forge.zig");
pub const pulse_mod = @import("pulse/pulse.zig");
pub const sense = @import("pulse/sense.zig");
pub const stasis = @import("pulse/stasis.zig");
pub const rhythm = @import("pulse/rhythm.zig");
pub const flux = @import("transmutation/flux.zig");
pub const guard = @import("safety/guard.zig");
pub const audit = @import("testing/audit.zig");
pub const dry_run = @import("testing/dry_run.zig");
pub const mock = @import("testing/mock.zig");
pub const prove = @import("testing/prove.zig");
pub const molt = @import("solidification/molt.zig");
pub const fossilize = @import("solidification/fossilize.zig");
pub const quench = @import("calcination/quench.zig");
pub const isolate = @import("safety/isolate.zig");
pub const verify = @import("safety/verify.zig");
pub const watch = @import("monitoring/watch.zig");
pub const trace = @import("monitoring/trace.zig");

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
        0x02 => Tool{ .name = "STAKE", .description = "Claim memory region", .validate = stake.STAKE.validate, .execute = stake.STAKE.execute },
        0x03 => Tool{ .name = "FLOW", .description = "DMA transfer", .validate = flow.FLOW.validate, .execute = flow.FLOW.execute },
        0x04 => Tool{ .name = "SHIFT", .description = "Remap BAR window", .validate = shift.SHIFT.validate, .execute = shift.SHIFT.execute },
        0x05 => Tool{ .name = "FENCE", .description = "Wait for condition", .validate = fence.FENCE.validate, .execute = fence.FENCE.execute },
        0x06 => Tool{ .name = "SYNC", .description = "Memory barrier", .validate = sync.SYNC.validate, .execute = sync.SYNC.execute },
        0x07 => Tool{ .name = "SENSE", .description = "Read sensor", .validate = sense.SENSE.validate, .execute = sense.SENSE.execute },
        0x08 => Tool{ .name = "PULSE", .description = "Timing signal", .validate = pulse_mod.PULSE.validate, .execute = pulse_mod.PULSE.execute },
        0x09 => Tool{ .name = "SIGNAL", .description = "Trigger interrupt", .validate = signal.SIGNAL.validate, .execute = signal.SIGNAL.execute },
        0x0A => Tool{ .name = "YIELD", .description = "Cooperative yield", .validate = yield_tool.YIELD.validate, .execute = yield_tool.YIELD.execute },
        0x0B => Tool{ .name = "RECAST", .description = "FPGA reconfigure", .validate = recast.RECAST.validate, .execute = recast.RECAST.execute },
        0x0C => Tool{ .name = "SNAP", .description = "Serialize state", .validate = snap.SNAP.validate, .execute = snap.SNAP.execute },
        0x0D => Tool{ .name = "REVERT", .description = "Restore state", .validate = revert.REVERT.validate, .execute = revert.REVERT.execute },
        0x0E => Tool{ .name = "LIMIT", .description = "Hard contract", .validate = limit.LIMIT.validate, .execute = limit.LIMIT.execute },
        0x0F => Tool{ .name = "VEIL", .description = "Hide from OS", .validate = veil.VEIL.validate, .execute = veil.VEIL.execute },
        0x11 => Tool{ .name = "RHYTHM", .description = "Timing constraint", .validate = rhythm.RHYTHM.validate, .execute = rhythm.RHYTHM.execute },
        0x14 => Tool{ .name = "MOLT", .description = "Full state dump", .validate = molt.MOLT.validate, .execute = molt.MOLT.execute },
        0x17 => Tool{ .name = "ECHO", .description = "Non-intrusive introspection", .validate = echo.ECHO.validate, .execute = echo.ECHO.execute },
        0x18 => Tool{ .name = "STASIS", .description = "Bus-level locking", .validate = stasis.STASIS.validate, .execute = stasis.STASIS.execute },
        0x1B => Tool{ .name = "FOSSILIZE", .description = "Substrate persistence", .validate = fossilize.FOSSILIZE.validate, .execute = fossilize.FOSSILIZE.execute },
        0x1C => Tool{ .name = "STRIKE", .description = "Rowhammer/bit flipping", .validate = strike.STRIKE.validate, .execute = strike.STRIKE.execute },
        0x1D => Tool{ .name = "QUENCH", .description = "Emergency power-state reset", .validate = quench.QUENCH.validate, .execute = quench.QUENCH.execute },
        0x1E => Tool{ .name = "FORGE", .description = "Bitstream injection", .validate = forge_tool.FORGE.validate, .execute = forge_tool.FORGE.execute },
        0x1F => Tool{ .name = "VOID", .description = "Secure substrate erase", .validate = void_tool.VOID.validate, .execute = void_tool.VOID.execute },
        0x2A => Tool{ .name = "FLUX", .description = "Cache invalidation", .validate = flux.FLUX.validate, .execute = flux.FLUX.execute },
        0x2B => Tool{ .name = "AUDIT", .description = "Post-instruction residue check", .validate = audit.AUDIT.validate, .execute = audit.AUDIT.execute },
        0x2C => Tool{ .name = "DRY_RUN", .description = "Simulate without executing", .validate = dry_run.DRY_RUN.validate, .execute = dry_run.DRY_RUN.execute },
        0x2D => Tool{ .name = "MOCK", .description = "Use mock hardware", .validate = mock.MOCK.validate, .execute = mock.MOCK.execute },
        0x2E => Tool{ .name = "PROVE", .description = "Formal verification", .validate = prove.PROVE.validate, .execute = prove.PROVE.execute },
        0x2F => Tool{ .name = "WATCH", .description = "Real-time monitoring", .validate = watch.WATCH.validate, .execute = watch.WATCH.execute },
        0x30 => Tool{ .name = "TRACE", .description = "Execution trace", .validate = trace.TRACE.validate, .execute = trace.TRACE.execute },
        0x31 => Tool{ .name = "GUARD", .description = "Runtime safety sentinel", .validate = guard.GUARD.validate, .execute = guard.GUARD.execute },
        0x32 => Tool{ .name = "ISOLATE", .description = "Complete hardware isolation", .validate = isolate.ISOLATE.validate, .execute = isolate.ISOLATE.execute },
        0x33 => Tool{ .name = "VERIFY", .description = "Cryptographic state verification", .validate = verify.VERIFY.validate, .execute = verify.VERIFY.execute },
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