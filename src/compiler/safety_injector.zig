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
const alkac = @import("../compiler/alkac.zig");

pub const SafetyRule = struct {
    condition: SafetyCondition,
    inject_before: ?[]const u8,
    inject_after: ?[]const u8,
    inject_operands: []const u64,
};

pub const SafetyCondition = enum {
    before_flow,
    after_flow,
    before_claim,
    after_claim,
    before_occupy,
    before_stake,
    after_stake,
    before_forge,
    before_strike,
    before_bond,
    after_bond,
    thermal_check,
    barrier_required,
};

pub const Injector = struct {
    rules: std.ArrayList(SafetyRule),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Injector {
        var rules = std.ArrayList(SafetyRule).init(allocator);
        rules.appendSlice(&.{
            SafetyRule{
                .condition = .before_claim,
                .inject_before = "GUARD",
                .inject_after = null,
                .inject_operands = &.{ 0x01 },
            },
            SafetyRule{
                .condition = .before_flow,
                .inject_before = "FENCE",
                .inject_after = "SYNC",
                .inject_operands = &.{},
            },
            SafetyRule{
                .condition = .after_flow,
                .inject_before = null,
                .inject_after = "SYNC",
                .inject_operands = &.{},
            },
            SafetyRule{
                .condition = .before_occupy,
                .inject_before = "ISOLATE",
                .inject_after = null,
                .inject_operands = &.{},
            },
            SafetyRule{
                .condition = .before_stake,
                .inject_before = "LIMIT",
                .inject_after = null,
                .inject_operands = &.{ 0x02 },
            },
            SafetyRule{
                .condition = .before_forge,
                .inject_before = "GUARD",
                .inject_after = null,
                .inject_operands = &.{ 0x03 },
            },
            SafetyRule{
                .condition = .before_strike,
                .inject_before = "GUARD",
                .inject_after = "AUDIT",
                .inject_operands = &.{ 0x04 },
            },
            SafetyRule{
                .condition = .before_bond,
                .inject_before = "FENCE",
                .inject_after = null,
                .inject_operands = &.{},
            },
            SafetyRule{
                .condition = .after_bond,
                .inject_before = null,
                .inject_after = "VERIFY",
                .inject_operands = &.{},
            },
        }) catch {};

        return Injector{
            .rules = rules,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Injector) void {
        self.rules.deinit();
    }

    pub fn inject(
        self: *Injector,
        program: *alkac.Program,
        vial: *const alkac.Vial,
    ) !void {
        _ = vial;
        var new_instructions = std.ArrayList(alkac.Instruction).init(self.allocator);
        errdefer new_instructions.deinit();

        for (program.instructions.items) |instr| {
            for (self.rules.items) |rule| {
                if (self.matchesCondition(instr.name, rule.condition)) {
                    if (rule.inject_before) |before_name| {
                        var before_instr = alkac.Instruction{
                            .name = try self.allocator.dupe(u8, before_name),
                            .operands = std.ArrayList(alka_bin.Operand).init(self.allocator),
                            .force_claim = false,
                            .chain_override = false,
                        };
                        for (rule.inject_operands) |op| {
                            try before_instr.operands.append(.{ .literal = op });
                        }
                        try new_instructions.append(before_instr);
                    }
                }
            }

            var cloned = alkac.Instruction{
                .name = try self.allocator.dupe(u8, instr.name),
                .operands = std.ArrayList(alka_bin.Operand).init(self.allocator),
                .force_claim = false,
                .chain_override = false,
            };
            for (instr.operands.items) |op| {
                try cloned.operands.append(op);
            }
            try new_instructions.append(cloned);

            for (self.rules.items) |rule| {
                if (self.matchesCondition(instr.name, rule.condition)) {
                    if (rule.inject_after) |after_name| {
                        var after_instr = alkac.Instruction{
                            .name = try self.allocator.dupe(u8, after_name),
                            .operands = std.ArrayList(alka_bin.Operand).init(self.allocator),
                            .force_claim = false,
                            .chain_override = false,
                        };
                        for (rule.inject_operands) |op| {
                            try after_instr.operands.append(.{ .literal = op });
                        }
                        try new_instructions.append(after_instr);
                    }
                }
            }
        }

        program.instructions.deinit();
        program.instructions = new_instructions;
    }

    pub fn injectThermalChecks(
        self: *Injector,
        program: *alkac.Program,
        vial: *const alkac.Vial,
    ) !void {
        var it = vial.vessels.iterator();
        while (it.next()) |entry| {
            const vessel = entry.value_ptr;
            if (vessel.thermal) |thermal| {
                if (thermal.throttle_at) |_| {
                    var sense_instr = alkac.Instruction{
                        .name = try self.allocator.dupe(u8, "SENSE"),
                        .operands = std.ArrayList(alka_bin.Operand).init(self.allocator),
                        .force_claim = false,
                        .chain_override = false,
                    };
                    try sense_instr.operands.append(.{ .literal = 0x07 });
                    try program.instructions.insert(0, sense_instr);

                    var limit_instr = alkac.Instruction{
                        .name = try self.allocator.dupe(u8, "LIMIT"),
                        .operands = std.ArrayList(alka_bin.Operand).init(self.allocator),
                        .force_claim = false,
                        .chain_override = false,
                    };
                    try limit_instr.operands.append(.{ .literal = thermal.throttle_at.? });
                    try program.instructions.insert(1, limit_instr);
                }
            }
        }
    }

    fn matchesCondition(self: *Injector, instr_name: []const u8, condition: SafetyCondition) bool {
        _ = self;
        return switch (condition) {
            .before_flow, .after_flow => std.mem.eql(u8, instr_name, "FLOW"),
            .before_claim => std.mem.eql(u8, instr_name, "CLAIM"),
            .after_claim => std.mem.eql(u8, instr_name, "CLAIM"),
            .before_occupy => std.mem.eql(u8, instr_name, "OCCUPY"),
            .before_stake, .after_stake => std.mem.eql(u8, instr_name, "STAKE"),
            .before_forge => std.mem.eql(u8, instr_name, "FORGE"),
            .before_strike => std.mem.eql(u8, instr_name, "STRIKE"),
            .before_bond, .after_bond => std.mem.eql(u8, instr_name, "BOND"),
            .thermal_check => false,
            .barrier_required => false,
        };
    }
};
