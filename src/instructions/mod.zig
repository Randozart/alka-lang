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

pub const OpCode = enum(u8) {
    CLAIM = 0x01,
    STAKE = 0x02,
    FLOW = 0x03,
    SHIFT = 0x04,
    FENCE = 0x05,
    SYNC = 0x06,
    SENSE = 0x07,
    PULSE = 0x08,
    SIGNAL = 0x09,
    YIELD = 0x0A,
    RECAST = 0x0B,
    SNAP = 0x0C,
    REVERT = 0x0D,
    LIMIT = 0x0E,
    RHYTHM = 0x11,
    ECHO = 0x17,
    STASIS = 0x18,
    PERSIST = 0x1B,
    POKE = 0x1C,
    RESET = 0x1D,
    INJECT = 0x1E,
    WIPE = 0x1F,
    FLUX = 0x2A,
    AUDIT = 0x2B,
    DRY_RUN = 0x2C,
    MOCK = 0x2D,
    PROVE = 0x2E,
    WATCH = 0x2F,
    TRACE = 0x30,
    GUARD = 0x31,
    ISOLATE = 0x32,
    VERIFY = 0x33,
    AFFINITY = 0x34,
    TUNNEL = 0x35,
    SUSPEND = 0x36,
    COORDINATE = 0x37,
    DIRECT = 0x39,
    BIND = 0x3A,
    SLICE = 0x3B,
    PIPE = 0x3C,
};

pub const Category = enum {
    CORE,
    TRANSMUTATION,
    DISSOLUTION,
    PULSE,
    SOLIDIFICATION,
    FORGING,
    CALCINATION,
    TESTING,
    MONITORING,
    SAFETY,
};

pub const Instruction = struct {
    op_code: OpCode,
    name: []const u8,
    category: Category,
    description: []const u8,
};

pub const instruction_set: []const Instruction = &[_]Instruction{
    .{ .op_code = .CLAIM, .name = "CLAIM", .category = .CORE, .description = "Take ownership of hardware node" },
    .{ .op_code = .STAKE, .name = "STAKE", .category = .CORE, .description = "Reserve memory region" },
    .{ .op_code = .FLOW, .name = "FLOW", .category = .CORE, .description = "DMA transfer" },
    .{ .op_code = .SHIFT, .name = "SHIFT", .category = .CORE, .description = "Remap BAR window" },
    .{ .op_code = .FENCE, .name = "FENCE", .category = .CORE, .description = "Wait for condition" },
    .{ .op_code = .SYNC, .name = "SYNC", .category = .CORE, .description = "Memory barrier" },
    .{ .op_code = .SENSE, .name = "SENSE", .category = .CORE, .description = "Read sensor" },
    .{ .op_code = .PULSE, .name = "PULSE", .category = .CORE, .description = "Timing signal" },
    .{ .op_code = .SIGNAL, .name = "SIGNAL", .category = .CORE, .description = "Trigger interrupt" },
    .{ .op_code = .YIELD, .name = "YIELD", .category = .CORE, .description = "Cooperative yield" },
    .{ .op_code = .RECAST, .name = "RECAST", .category = .CORE, .description = "Reconfigure device" },
    .{ .op_code = .SNAP, .name = "SNAP", .category = .CORE, .description = "Serialize state" },
    .{ .op_code = .REVERT, .name = "REVERT", .category = .CORE, .description = "Restore state" },
    .{ .op_code = .LIMIT, .name = "LIMIT", .category = .CORE, .description = "Enforce constraint" },
    .{ .op_code = .RHYTHM, .name = "RHYTHM", .category = .PULSE, .description = "Timing constraint" },
    .{ .op_code = .ECHO, .name = "ECHO", .category = .CORE, .description = "Non-intrusive introspection" },
    .{ .op_code = .STASIS, .name = "STASIS", .category = .PULSE, .description = "Bus-level locking" },
    .{ .op_code = .PERSIST, .name = "PERSIST", .category = .SOLIDIFICATION, .description = "Store in memory indefinitely" },
    .{ .op_code = .POKE, .name = "POKE", .category = .DISSOLUTION, .description = "Write pattern to address" },
    .{ .op_code = .RESET, .name = "RESET", .category = .CALCINATION, .description = "Reset subsystem to known state" },
    .{ .op_code = .INJECT, .name = "INJECT", .category = .FORGING, .description = "Load firmware/config" },
    .{ .op_code = .WIPE, .name = "WIPE", .category = .CALCINATION, .description = "Securely erase region" },
    .{ .op_code = .FLUX, .name = "FLUX", .category = .TRANSMUTATION, .description = "Cache invalidation" },
    .{ .op_code = .AUDIT, .name = "AUDIT", .category = .TESTING, .description = "Post-instruction residue check" },
    .{ .op_code = .DRY_RUN, .name = "DRY_RUN", .category = .TESTING, .description = "Simulate without executing" },
    .{ .op_code = .MOCK, .name = "MOCK", .category = .TESTING, .description = "Use mock hardware" },
    .{ .op_code = .PROVE, .name = "PROVE", .category = .TESTING, .description = "Formal verification" },
    .{ .op_code = .WATCH, .name = "WATCH", .category = .MONITORING, .description = "Real-time monitoring" },
    .{ .op_code = .TRACE, .name = "TRACE", .category = .MONITORING, .description = "Execution trace" },
    .{ .op_code = .GUARD, .name = "GUARD", .category = .SAFETY, .description = "Runtime safety sentinel" },
    .{ .op_code = .ISOLATE, .name = "ISOLATE", .category = .SAFETY, .description = "Complete hardware isolation" },
    .{ .op_code = .VERIFY, .name = "VERIFY", .category = .SAFETY, .description = "Cryptographic state verification" },
    .{ .op_code = .AFFINITY, .name = "AFFINITY", .category = .CORE, .description = "Pin resource to target" },
    .{ .op_code = .TUNNEL, .name = "TUNNEL", .category = .CORE, .description = "Direct channel between endpoints" },
    .{ .op_code = .SUSPEND, .name = "SUSPEND", .category = .CORE, .description = "Pause auto-behavior" },
    .{ .op_code = .COORDINATE, .name = "COORDINATE", .category = .PULSE, .description = "Coordinate devices" },
    .{ .op_code = .DIRECT, .name = "DIRECT", .category = .DISSOLUTION, .description = "Bypass OS, access controller" },
    .{ .op_code = .BIND, .name = "BIND", .category = .CORE, .description = "Bind to device with force" },
    .{ .op_code = .SLICE, .name = "SLICE", .category = .CORE, .description = "Split region into chunks" },
    .{ .op_code = .PIPE, .name = "PIPE", .category = .CORE, .description = "Continuous DMA ring buffer" },
};

pub fn getInstructionByName(name: []const u8) ?*const Instruction {
    for (instruction_set, 0..) |*instr, i| {
        if (std.mem.eql(u8, instr.name, name)) {
            return &instruction_set[i];
        }
    }
    return null;
}

pub fn getInstructionByCode(code: OpCode) ?*const Instruction {
    for (instruction_set, 0..) |*instr, i| {
        if (instr.op_code == code) {
            return &instruction_set[i];
        }
    }
    return null;
}