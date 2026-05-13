// generate_dispatch.zig — Reads pharmacopia.json and generates dispatch_table.zig
//
// This build tool parses the pharmacopia manifest and emits a Zig source file
// containing the getTool() dispatch switch. Each tool is imported from its
// declared source path, and the switch maps opcode -> Tool struct.
//
// Usage: zig run generate_dispatch.zig -- pharmacopia.json src/tools/dispatch_table.zig

const std = @import("std");

const ToolDef = struct {
    opcode: []const u8,
    name: []const u8,
    description: []const u8,
    language: []const u8,
    category: []const u8,
    sources: []const []const u8,
    wrapper: ?[]const u8 = null,
    struct_name: []const u8,
    safety_level: u8,
};

const Pharmacopia = struct {
    version: []const u8,
    description: []const u8,
    tools: []ToolDef,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: generate_dispatch <pharmacopia.json> <output.zig>\n", .{});
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
        \\// Auto-generated dispatch table — DO NOT EDIT
        \\// Generated from pharmacopia.json by generate_dispatch.zig
        \\//
        \\// To regenerate: zig build dispatch
        \\
        \\const std = @import("std");
        \\const interface = @import("interface.zig");
        \\
        \\pub const Tool = struct {
        \\    pub const Context = interface.ToolInterface.Context;
        \\    pub const Result = interface.ToolInterface.Result;
        \\    pub const ValidateResult = interface.ToolInterface.ValidateResult;
        \\    pub const ValidateError = interface.ToolInterface.ValidateError;
        \\
        \\    pub const ValidateFn = *const fn (operands: []const u64, ctx: Context) ValidateError!ValidateResult;
        \\    pub const ExecuteFn = *const fn (operands: []const u64, ctx: Context) Result;
        \\
        \\    name: []const u8,
        \\    description: []const u8,
        \\    validate: ValidateFn,
        \\    execute: ExecuteFn,
        \\};
        \\
        \\
    );

    // Collect unique imports: key = struct_name, value = import_path
    var import_map = std.StringArrayHashMap([]const u8).init(allocator);
    defer {
        var it = import_map.iterator();
        while (it.next()) |entry| allocator.free(entry.value_ptr.*);
        import_map.deinit();
    }

    for (parsed.value.tools) |tool| {
        // Determine the correct import path
        const import_path: []const u8 = if (tool.wrapper) |wrapper_path|
            // SPARK tools use their wrapper file
            try std.fmt.allocPrint(allocator, "{s}", .{wrapper_path})
        else
            // Zig tools use category/struct_name.zig (lowercase)
            blk: {
                var lower_buf: [64]u8 = undefined;
                const lower_name = std.ascii.lowerString(&lower_buf, tool.struct_name);
                break :blk try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ tool.category, lower_name });
            };

        // Only add if not already present
        if (import_map.get(tool.struct_name) == null) {
            try import_map.put(tool.struct_name, try allocator.dupe(u8, import_path));
        }
    }

    // Write imports
    var it = import_map.iterator();
    while (it.next()) |entry| {
        try w.print("const mod_{s} = @import(\"{s}\");\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    try w.writeAll("\n");

    // Write getTool function
    try w.writeAll("pub fn getTool(op_code: u8) ?Tool {\n");
    try w.writeAll("    return switch (op_code) {\n");

    for (parsed.value.tools) |tool| {
        try w.print("        {s} => Tool{{ .name = \"{s}\", .description = \"{s}\", .validate = mod_{s}.{s}.validate, .execute = mod_{s}.{s}.execute }},\n",
            .{ tool.opcode, tool.name, tool.description, tool.struct_name, tool.struct_name, tool.struct_name, tool.struct_name });
    }

    try w.writeAll("        else => null,\n");
    try w.writeAll("    };\n");
    try w.writeAll("}\n");

    // Write tool count
    try w.print("\npub const tool_count: usize = {};\n", .{parsed.value.tools.len});

    // Write tool info array for pharmacopia listing
    try w.writeAll("\npub const ToolInfo = struct {\n");
    try w.writeAll("    opcode: u8,\n");
    try w.writeAll("    name: []const u8,\n");
    try w.writeAll("    description: []const u8,\n");
    try w.writeAll("    language: []const u8,\n");
    try w.writeAll("    category: []const u8,\n");
    try w.writeAll("    safety_level: u8,\n");
    try w.writeAll("};\n\n");

    try w.writeAll("pub const all_tools: [tool_count]ToolInfo = .{\n");
    for (parsed.value.tools) |tool| {
        try w.print("    .{{ .opcode = {s}, .name = \"{s}\", .description = \"{s}\", .language = \"{s}\", .category = \"{s}\", .safety_level = {} }},\n",
            .{ tool.opcode, tool.name, tool.description, tool.language, tool.category, tool.safety_level });
    }
    try w.writeAll("};\n");

    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = out.items });

    std.debug.print("Generated dispatch table: {s} ({} tools)\n", .{ output_path, parsed.value.tools.len });
}
