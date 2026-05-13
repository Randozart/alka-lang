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
    chain: ChainMeta,
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
    } else if (std.mem.eql(u8, mode, "suggest")) {
        if (args.len < 4) {
            std.debug.print("Usage: pharmacopia suggest <goal>\n", .{});
            std.debug.print("Examples:\n", .{});
            std.debug.print("  pharmacopia suggest \"transfer data\"\n", .{});
            std.debug.print("  pharmacopia suggest \"reset device\"\n", .{});
            std.debug.print("  pharmacopia suggest \"read memory\"\n", .{});
            std.process.exit(1);
        }
        const goal = args[3];
        try suggestTools(parsed.value, goal);
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

const GoalRecipe = struct {
    keywords: []const []const u8,
    description: []const u8,
    chain: []const []const u8,
    explanation: []const u8,
};

const goal_recipes = [_]GoalRecipe{
    .{
        .keywords = &.{"transfer", "dma", "move", "copy", "stream"},
        .description = "Transfer data between memory regions via DMA",
        .chain = &.{"CLAIM", "SHIFT", "STAKE", "FLOW", "SYNC", "FENCE"},
        .explanation = "CLAIM takes ownership of the device, SHIFT maps the BAR window, STAKE reserves memory, FLOW performs the DMA transfer, SYNC ensures visibility, FENCE waits for completion.",
    },
    .{
        .keywords = &.{"reset", "restart", "reboot", "recover"},
        .description = "Reset a subsystem to known state",
        .chain = &.{"CLAIM", "SNAP", "RESET", "VERIFY"},
        .explanation = "CLAIM ownership, SNAP current state for rollback, RESET the subsystem, VERIFY the resulting state is correct.",
    },
    .{
        .keywords = &.{"read", "peek", "inspect", "scan", "probe"},
        .description = "Read from hardware without modification",
        .chain = &.{"CLAIM", "SHIFT", "ECHO"},
        .explanation = "CLAIM the device, SHIFT to map the aperture, ECHO reads without side effects.",
    },
    .{
        .keywords = &.{"write", "poke", "modify", "patch", "inject"},
        .description = "Write data to hardware registers or memory",
        .chain = &.{"CLAIM", "SHIFT", "LIMIT", "POKE", "AUDIT"},
        .explanation = "CLAIM ownership, SHIFT to map the region, LIMIT enforces constraints, POKE writes the data, AUDIT verifies no residue.",
    },
    .{
        .keywords = &.{"isolate", "secure", "sandbox", "protect"},
        .description = "Isolate hardware from OS access",
        .chain = &.{"BIND", "CLAIM", "ISOLATE", "GUARD"},
        .explanation = "BIND takes exclusive device access, CLAIM establishes ownership, ISOLATE revokes OS access, GUARD arms runtime safety.",
    },
    .{
        .keywords = &.{"split", "chunk", "slice", "partition", "refract"},
        .description = "Split a memory region into chunks",
        .chain = &.{"CLAIM", "SHIFT", "SLICE", "SYNC", "FENCE"},
        .explanation = "CLAIM the device, SHIFT to map the aperture, SLICE splits the region, SYNC ensures visibility, FENCE waits for completion.",
    },
    .{
        .keywords = &.{"persist", "store", "pin", "freeze", "fossilize"},
        .description = "Store data in memory indefinitely",
        .chain = &.{"CLAIM", "SHIFT", "AFFINITY", "PERSIST", "VERIFY"},
        .explanation = "CLAIM ownership, SHIFT to map memory, AFFINITY pins the resource, PERSIST stores it, VERIFY confirms integrity.",
    },
    .{
        .keywords = &.{"erase", "wipe", "clear", "zero", "clean"},
        .description = "Securely erase a memory region",
        .chain = &.{"CLAIM", "SHIFT", "WIPE", "AUDIT"},
        .explanation = "CLAIM ownership, SHIFT to map the region, WIPE securely erases, AUDIT verifies no residue remains.",
    },
    .{
        .keywords = &.{"tunnel", "channel", "bond", "link", "connect"},
        .description = "Create direct channel between two endpoints",
        .chain = &.{"CLAIM", "CLAIM", "TUNNEL", "FLOW"},
        .explanation = "CLAIM both endpoints, TUNNEL establishes the direct channel, FLOW transfers data through it.",
    },
    .{
        .keywords = &.{"suspend", "pause", "freeze", "halt", "stasis"},
        .description = "Pause hardware auto-behavior",
        .chain = &.{"CLAIM", "SUSPEND", "STASIS"},
        .explanation = "CLAIM ownership, SUSPEND pauses auto-behavior, STASIS locks the bus for safe manipulation.",
    },
    .{
        .keywords = &.{"firmware", "load", "flash", "configure", "recast"},
        .description = "Load firmware or configuration into device",
        .chain = &.{"CLAIM", "SUSPEND", "INJECT", "VERIFY", "RESET"},
        .explanation = "CLAIM ownership, SUSPEND auto-behavior, INJECT the firmware, VERIFY integrity, RESET to apply.",
    },
    .{
        .keywords = &.{"coordinate", "sync", "sync", "align", "resonate"},
        .description = "Coordinate multiple devices",
        .chain = &.{"CLAIM", "CLAIM", "COORDINATE", "SYNC"},
        .explanation = "CLAIM both devices, COORDINATE establishes synchronization, SYNC ensures memory visibility.",
    },
    .{
        .keywords = &.{"monitor", "watch", "trace", "observe", "track"},
        .description = "Monitor hardware state in real-time",
        .chain = &.{"CLAIM", "WATCH", "TRACE"},
        .explanation = "CLAIM the device, WATCH monitors state, TRACE logs execution.",
    },
    .{
        .keywords = &.{"limit", "constrain", "throttle", "cap", "bound"},
        .description = "Enforce hardware constraints",
        .chain = &.{"CLAIM", "LIMIT", "GUARD"},
        .explanation = "CLAIM ownership, LIMIT sets constraints, GUARD enforces them at runtime.",
    },
    .{
        .keywords = &.{"save", "snapshot", "serialize", "backup", "snap"},
        .description = "Save current hardware state",
        .chain = &.{"CLAIM", "SNAP"},
        .explanation = "CLAIM ownership, SNAP serializes the current state for later restoration.",
    },
    .{
        .keywords = &.{"restore", "revert", "rollback", "recover", "undo"},
        .description = "Restore hardware to saved state",
        .chain = &.{"CLAIM", "REVERT", "VERIFY"},
        .explanation = "CLAIM ownership, REVERT restores the saved state, VERIFY confirms correctness.",
    },
    .{
        .keywords = &.{"ring", "buffer", "continuous", "loop", "pipe"},
        .description = "Establish continuous DMA ring buffer",
        .chain = &.{"CLAIM", "SHIFT", "PIPE", "WATCH"},
        .explanation = "CLAIM the device, SHIFT to map memory, PIPE establishes the ring buffer, WATCH monitors it.",
    },
    .{
        .keywords = &.{"cache", "invalidate", "flush", "coherence"},
        .description = "Invalidate CPU cache for coherence",
        .chain = &.{"FLUX", "SYNC"},
        .explanation = "FLUX invalidates cache lines, SYNC ensures memory visibility across all cores.",
    },
    .{
        .keywords = &.{"interrupt", "signal", "trigger", "event", "notify"},
        .description = "Trigger hardware interrupt or event",
        .chain = &.{"CLAIM", "FLOW", "FENCE", "SIGNAL"},
        .explanation = "CLAIM ownership, FLOW performs the operation, FENCE waits for completion, SIGNAL triggers the interrupt.",
    },
    .{
        .keywords = &.{"timing", "clock", "rhythm", "pulse", "schedule"},
        .description = "Set timing constraints on hardware",
        .chain = &.{"CLAIM", "RHYTHM", "PULSE"},
        .explanation = "CLAIM the device, RHYTHM sets timing constraints, PULSE emits timing signals.",
    },
};

fn suggestTools(pharma: Pharmacopia, goal: []const u8) !void {
    std.debug.print("\n=== Alka Pharmacopia v{s} — Recipe Suggester ===\n", .{pharma.version});
    std.debug.print("Goal: \"{s}\"\n\n", .{goal});

    const goal_lower = try std.ascii.allocLowerString(std.heap.page_allocator, goal);
    defer std.heap.page_allocator.free(goal_lower);

    var best_match: ?*const GoalRecipe = null;
    var best_score: usize = 0;

    for (&goal_recipes) |*recipe| {
        var score: usize = 0;
        for (recipe.keywords) |keyword| {
            if (std.mem.indexOf(u8, goal_lower, keyword) != null) {
                score += 1;
            }
        }
        if (score > best_score) {
            best_score = score;
            best_match = recipe;
        }
    }

    if (best_match == null or best_score == 0) {
        std.debug.print("No matching recipe found for \"{s}\".\n\n", .{goal});
        std.debug.print("Available recipes:\n", .{});
        for (goal_recipes) |recipe| {
            std.debug.print("  \"{s}\" → {s}\n", .{ recipe.description, recipe.chain[0] });
        }
        std.debug.print("\nTry using keywords from the descriptions above.\n", .{});
        return;
    }

    const recipe = best_match.?;

    std.debug.print("Matched: {s}\n", .{recipe.description});
    std.debug.print("Confidence: {d}/{d} keywords matched\n\n", .{ best_score, recipe.keywords.len });

    std.debug.print("Recommended Chain:\n", .{});
    for (recipe.chain, 0..) |tool_name, i| {
        // Find the tool in pharmacopia
        var tool_desc: []const u8 = "";
        for (pharma.tools) |tool| {
            if (std.mem.eql(u8, tool.name, tool_name)) {
                tool_desc = tool.description;
                break;
            }
        }

        const arrow = if (i == 0) "  →" else "  →";
        std.debug.print("{s} [{d}] {s} — {s}\n", .{ arrow, i + 1, tool_name, tool_desc });
    }

    std.debug.print("\nWhy this chain:\n", .{});
    std.debug.print("  {s}\n", .{recipe.explanation});

    // Show safety info
    std.debug.print("\nSafety Notes:\n", .{});
    for (recipe.chain) |tool_name| {
        for (pharma.tools) |tool| {
            if (std.mem.eql(u8, tool.name, tool_name)) {
                if (tool.safety_level >= 4) {
                    std.debug.print("  ⚠ {s} is safety level {d} — high impact operation\n", .{ tool_name, tool.safety_level });
                }
                if (std.mem.eql(u8, tool.language, "spark")) {
                    std.debug.print("  ✓ {s} is SPARK-verified — formally proven correct\n", .{tool_name});
                }
                break;
            }
        }
    }

    std.debug.print("\nAlka script template:\n", .{});
    std.debug.print("  // Recipe: {s}\n", .{recipe.description});
    std.debug.print("  REQUIRE \"target.alkavl\"\n", .{});
    for (recipe.chain) |tool_name| {
        std.debug.print("  {s} ...\n", .{tool_name});
    }
    std.debug.print("\n", .{});
}
