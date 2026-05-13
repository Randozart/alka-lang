// generate_chain_rules.zig — Reads pharmacopia.json and generates chain_rules.zig
//
// This build tool parses the pharmacopia manifest and emits a Zig source file
// containing chain validation metadata: pre/post states, side effects, warnings,
// and suggestions for each tool.
//
// Usage: zig run generate_chain_rules.zig -- pharmacopia.json src/compiler/chain_rules.zig

const std = @import("std");

const ChainMeta = struct {
    pre_state: []const []const u8,
    post_state: []const []const u8,
    side_effects: []const []const u8,
    suggests_after: []const []const u8,
    warns_if_before: []const []const u8,
};

const ToolDef = struct {
    opcode: []const u8,
    name: []const u8,
    safety_level: u8,
    chain: ChainMeta,
};

const Pharmacopia = struct {
    version: []const u8,
    tools: []ToolDef,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: generate_chain_rules <pharmacopia.json> <output.zig>\n", .{});
        std.process.exit(1);
    }

    const manifest_path = args[1];
    const output_path = args[2];

    const json_data = try std.fs.cwd().readFileAlloc(allocator, manifest_path, std.math.maxInt(usize));
    const parsed = try std.json.parseFromSlice(Pharmacopia, allocator, json_data, .{
        .ignore_unknown_fields = true,
    });

    var out = std.ArrayList(u8).init(allocator);
    const w = out.writer();

    try w.writeAll(
        \\// Auto-generated chain rules — DO NOT EDIT
        \\// Generated from pharmacopia.json by generate_chain_rules.zig
        \\//
        \\// To regenerate: zig build chain-rules
        \\
        \\const std = @import("std");
        \\
        \\pub const ChainRule = struct {
        \\    opcode: u8,
        \\    name: []const u8,
        \\    pre_state: []const []const u8,
        \\    post_state: []const []const u8,
        \\    side_effects: []const []const u8,
        \\    suggests_after: []const []const u8,
        \\    warns_if_before: []const []const u8,
        \\    safety_level: u8,
        \\};
        \\
        \\
    );

    try w.print("pub const chain_rules: [{}]ChainRule = .{{\n", .{parsed.value.tools.len});

    for (parsed.value.tools) |tool| {
        try w.writeAll("    .{\n");
        try w.print("        .opcode = {s},\n", .{tool.opcode});
        try w.print("        .name = \"{s}\",\n", .{tool.name});
        try w.print("        .safety_level = {},\n", .{tool.safety_level});

        // pre_state
        try w.writeAll("        .pre_state = &.{");
        for (tool.chain.pre_state, 0..) |state, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("\"{s}\"", .{state});
        }
        try w.writeAll("},\n");

        // post_state
        try w.writeAll("        .post_state = &.{");
        for (tool.chain.post_state, 0..) |state, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("\"{s}\"", .{state});
        }
        try w.writeAll("},\n");

        // side_effects
        try w.writeAll("        .side_effects = &.{");
        for (tool.chain.side_effects, 0..) |effect, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("\"{s}\"", .{effect});
        }
        try w.writeAll("},\n");

        // suggests_after
        try w.writeAll("        .suggests_after = &.{");
        for (tool.chain.suggests_after, 0..) |name, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("\"{s}\"", .{name});
        }
        try w.writeAll("},\n");

        // warns_if_before
        try w.writeAll("        .warns_if_before = &.{");
        for (tool.chain.warns_if_before, 0..) |name, i| {
            if (i > 0) try w.writeAll(", ");
            try w.print("\"{s}\"", .{name});
        }
        try w.writeAll("},\n");

        try w.writeAll("    },\n");
    }

    try w.writeAll("};\n");

    try w.print("\npub const chain_rule_count: usize = {};\n", .{parsed.value.tools.len});

    // Generate lookup function
    try w.writeAll("\npub fn getChainRule(opcode: u8) ?*const ChainRule {\n");
    try w.writeAll("    for (&chain_rules) |*rule| {\n");
    try w.writeAll("        if (rule.opcode == opcode) return rule;\n");
    try w.writeAll("    }\n");
    try w.writeAll("    return null;\n");
    try w.writeAll("}\n");

    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = out.items });

    std.debug.print("Generated chain rules: {s} ({} tools)\n", .{ output_path, parsed.value.tools.len });
}
