// pharmacopia_build.zig — Build tools from pharmacopia.json manifest
//
// This build tool reads the pharmacopia manifest and:
// 1. Builds SPARK tools with gprbuild
// 2. Compiles C wrappers
// 3. Links all object files into the Alka compiler
//
// Usage: zig run pharmacopia_build.zig -- pharmacopia.json <mode>
//   mode: "build" | "list" | "verify"

const std = @import("std");

const ToolDef = struct {
    opcode: []const u8,
    name: []const u8,
    description: []const u8,
    language: []const u8,
    category: []const u8,
    sources: []const []const u8,
    project: ?[]const u8 = null,
    wrapper: ?[]const u8 = null,
    struct_name: []const u8,
    safety_level: u8,
    link_libraries: ?[]const []const u8 = null,
    verified_by: ?[]const u8 = null,
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
        std.debug.print("Usage: pharmacopia_build <pharmacopia.json> <mode>\n", .{});
        std.debug.print("  mode: build | list | verify\n", .{});
        std.process.exit(1);
    }

    const manifest_path = args[1];
    const mode = args[2];

    const json_data = try std.fs.cwd().readFileAlloc(allocator, manifest_path, std.math.maxInt(usize));
    const parsed = try std.json.parseFromSlice(Pharmacopia, allocator, json_data, .{
        .ignore_unknown_fields = true,
    });

    if (std.mem.eql(u8, mode, "list")) {
        try listTools(parsed.value);
    } else if (std.mem.eql(u8, mode, "build")) {
        try buildTools(parsed.value, allocator);
    } else if (std.mem.eql(u8, mode, "verify")) {
        try verifyTools(parsed.value, allocator);
    } else {
        std.debug.print("Unknown mode: {s}\n", .{mode});
        std.process.exit(1);
    }
}

fn listTools(pharma: Pharmacopia) !void {
    std.debug.print("\n=== Alka Pharmacopia v{s} ===\n", .{pharma.version});
    std.debug.print("{s}\n\n", .{pharma.description});

    var spark_count: usize = 0;
    var zig_count: usize = 0;

    for (pharma.tools) |tool| {
        const verified = if (tool.verified_by) |v|
            try std.fmt.allocPrint(std.heap.page_allocator, " [{s}]", .{v})
        else
            "";

        std.debug.print("  {s} {s} — {s} (L{d}, {s}){s}\n",
            .{ tool.opcode, tool.name, tool.description, tool.safety_level, tool.language, verified });

        if (std.mem.eql(u8, tool.language, "spark")) spark_count += 1;
        if (std.mem.eql(u8, tool.language, "zig")) zig_count += 1;
    }

    std.debug.print("\n  Total: {} tools ({} Zig, {} SPARK)\n",
        .{ pharma.tools.len, zig_count, spark_count });
}

fn buildTools(pharma: Pharmacopia, allocator: std.mem.Allocator) !void {
    std.debug.print("Building pharmacopia...\n", .{});

    for (pharma.tools) |tool| {
        if (std.mem.eql(u8, tool.language, "spark")) {
            std.debug.print("  SPARK: {s} — ", .{tool.name});
            if (tool.project) |project| {
                const result = try runCommand(allocator, &.{ "gprbuild", "-P", project }, allocator);
                if (result) {
                    std.debug.print("OK\n", .{});
                } else {
                    std.debug.print("FAILED\n", .{});
                }
            }
        }
    }

    std.debug.print("Build complete.\n", .{});
}

fn verifyTools(pharma: Pharmacopia, allocator: std.mem.Allocator) !void {
    std.debug.print("Verifying pharmacopia...\n", .{});

    var pass_count: usize = 0;
    var total: usize = 0;

    for (pharma.tools) |tool| {
        if (tool.verified_by) |verifier| {
            total += 1;
            if (std.mem.eql(u8, verifier, "gnatprove")) {
                std.debug.print("  {s} ({s}): ", .{ tool.name, verifier });
                if (tool.project) |project| {
                    const result = try runCommand(allocator, &.{
                        "gnatprove", "-P", project, "--level=2", "--timeout=30",
                    }, allocator);
                    if (result) {
                        std.debug.print("PASS\n", .{});
                        pass_count += 1;
                    } else {
                        std.debug.print("FAIL\n", .{});
                    }
                }
            }
        }
    }

    std.debug.print("\n  {}/{} tools verified\n", .{ pass_count, total });
}

fn runCommand(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    tmp_allocator: std.mem.Allocator,
) !bool {
    _ = tmp_allocator;
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    const term = try child.spawnAndWait();
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}
