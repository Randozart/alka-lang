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

// Tool Test Harness — Permanent Failure-Prevention Pattern
//
// Every tool in the Pharmacopia is validated against:
// 1. Empty inputs (zero operands)
// 2. Boundary values (max u64, zero, page-aligned)
// 3. Minimal valid context
// 4. Execute returns without crashing
//
// This ensures no tool can panic or segfault on malformed input.

const std = @import("std");
const tools = @import("tools");
const dispatch = tools.dispatch;
const interface = tools.interface;

const Tool = dispatch.Tool;
const Context = interface.ToolInterface.Context;
const ValidateResult = interface.ToolInterface.ValidateResult;

const default_ctx = Context{
    .physical_addr = 0,
    .pci_bus = 0,
    .pci_device = 0,
    .pci_function = 0,
    .bar_base = 0,
    .aperture_size = 256 * 1024 * 1024,
    .aperture_max = 256 * 1024 * 1024,
    .thermal_limit = 95,
    .current_temp = 45,
};

fn testToolEmpty(tool: Tool) !void {
    const empty: [0]u64 = .{};
    _ = tool.validate(empty[0..], default_ctx) catch {};
    _ = tool.execute(empty[0..], default_ctx);
}

fn testToolBoundary(tool: Tool) !void {
    const boundary = [_]u64{ 0, std.math.maxInt(u64), 0x1000, 0xFFFFFFFFFFFFFFFF };
    _ = tool.validate(boundary[0..], default_ctx) catch {};
    _ = tool.execute(boundary[0..], default_ctx);
}

fn testToolZero(tool: Tool) !void {
    const zeros = [_]u64{ 0, 0, 0 };
    _ = tool.validate(zeros[0..], default_ctx) catch {};
    _ = tool.execute(zeros[0..], default_ctx);
}

fn testToolApertureZero(tool: Tool) !void {
    const zero_ap_ctx = Context{
        .physical_addr = 0,
        .pci_bus = 0,
        .pci_device = 0,
        .pci_function = 0,
        .bar_base = 0,
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_limit = 0,
        .current_temp = 0,
    };
    const operands = [_]u64{ 0x1000, 0x2000, 1024 };
    _ = tool.validate(operands[0..], zero_ap_ctx) catch {};
    _ = tool.execute(operands[0..], zero_ap_ctx);
}

fn testToolThermalExtreme(tool: Tool) !void {
    const hot_ctx = Context{
        .physical_addr = 0,
        .pci_bus = 0,
        .pci_device = 0,
        .pci_function = 0,
        .bar_base = 0,
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_limit = 0,
        .current_temp = 150,
    };
    const operands = [_]u64{ 0x1000 };
    _ = tool.validate(operands[0..], hot_ctx) catch {};
    _ = tool.execute(operands[0..], hot_ctx);
}

test "All tools: empty input does not panic" {
    var tested: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try testToolEmpty(tool);
            tested += 1;
        }
    }
    try std.testing.expect(tested == dispatch.tool_count);
}

test "All tools: boundary values do not panic" {
    var tested: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try testToolBoundary(tool);
            tested += 1;
        }
    }
    try std.testing.expect(tested == dispatch.tool_count);
}

test "All tools: zero operands do not panic" {
    var tested: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try testToolZero(tool);
            tested += 1;
        }
    }
    try std.testing.expect(tested == dispatch.tool_count);
}

test "All tools: zero aperture context does not panic" {
    var tested: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try testToolApertureZero(tool);
            tested += 1;
        }
    }
    try std.testing.expect(tested == dispatch.tool_count);
}

test "All tools: thermal extreme context does not panic" {
    var tested: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try testToolThermalExtreme(tool);
            tested += 1;
        }
    }
    try std.testing.expect(tested == dispatch.tool_count);
}

test "SPARK tools: SHIFT rejects non-page-aligned" {
    const tool = dispatch.getTool(0x04).?;
    const operands = [_]u64{ 0x1001 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "SPARK tools: FLOW rejects zero size" {
    const tool = dispatch.getTool(0x03).?;
    const operands = [_]u64{ 0x100000, 0x200000, 0 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "SPARK tools: FENCE rejects zero timeout" {
    const tool = dispatch.getTool(0x05).?;
    const operands = [_]u64{ 0 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "SPARK tools: SIGNAL rejects zero ID" {
    const tool = dispatch.getTool(0x09).?;
    const operands = [_]u64{ 0 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "SPARK tools: REFRACT rejects zero total (dst_addr)" {
    const tool = dispatch.getTool(0x3B).?;
    const operands = [_]u64{ 0x100000, 0, 64 * 1024 * 1024 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "SPARK tools: REFRACT accepts valid chunk within aperture" {
    const tool = dispatch.getTool(0x3B).?;
    const operands = [_]u64{ 0x100000, 0x200000, 64 * 1024 * 1024 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(result.allowed);
}

test "SPARK tools: SHIFT exceeds aperture" {
    const tool = dispatch.getTool(0x04).?;
    const operands = [_]u64{ 256 * 1024 * 1024 + 0x1000 };
    const result = try tool.validate(operands[0..], default_ctx);
    try std.testing.expect(!result.allowed);
}

test "All tools: dispatch table completeness" {
    var count: usize = 0;
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i) != null) count += 1;
    }
    try std.testing.expectEqual(dispatch.tool_count, count);
}

test "All tools: info array matches dispatch" {
    var i: usize = 0;
    while (i < dispatch.all_tools.len) : (i += 1) {
        const info = dispatch.all_tools[i];
        const tool = dispatch.getTool(info.opcode);
        try std.testing.expect(tool != null);
        try std.testing.expectEqualStrings(info.name, tool.?.name);
    }
}

test "All tools: no null names or descriptions" {
    var i: u8 = 0;
    while (i < 0xFF) : (i += 1) {
        if (dispatch.getTool(i)) |tool| {
            try std.testing.expect(tool.name.len > 0);
            try std.testing.expect(tool.description.len > 0);
        }
    }
}
