// Tool Chain Validator — validates instruction sequences against chain graph
//
// CHAIN_VALIDATION_TODO: This is a MINIMAL WORKING VERSION.
// The full implementation should:
// 1. Load chain metadata from pharmacopia.json at compile time
// 2. Build a directed graph of pre/post states
// 3. Validate all chains, not just the 6 hardcoded below
// 4. Implement --override flag to suppress warnings
// 5. Auto-inject suggestions for missing links
// 6. Track side-effects (thermal, memory) across the chain
//
// Current implementation validates 6 core chains:
// 1. FLOW requires CLAIM before it
// 2. SIGNAL requires FENCE before it
// 3. SLICE requires CLAIM before it
// 4. POKE requires CLAIM before it
// 5. TUNNEL requires CLAIM before it
// 6. PERSIST requires CLAIM before it

const std = @import("std");
const alkac = @import("alkac.zig");

pub const ChainError = error{
    PreStateUnsatisfied,
    WarnsIfBeforeViolated,
};

pub const ChainResult = struct {
    valid: bool,
    warnings: []const []const u8,
    errors: []const []const u8,
    suggestions: []const []const u8,
};

// CHAIN_VALIDATION_TODO: Replace hardcoded rules with pharmacopia.json metadata
const ChainRule = struct {
    name: []const u8,
    requires_before: []const u8,
    error_msg: []const u8,
    suggestion: []const u8,
};

const chain_rules = [_]ChainRule{
    .{ .name = "FLOW", .requires_before = "CLAIM", .error_msg = "FLOW requires CLAIM before it (vessel must be owned)", .suggestion = "Insert CLAIM before FLOW" },
    .{ .name = "SIGNAL", .requires_before = "FENCE", .error_msg = "SIGNAL requires FENCE before it (condition must be met)", .suggestion = "Insert FENCE before SIGNAL" },
    .{ .name = "SLICE", .requires_before = "CLAIM", .error_msg = "SLICE requires CLAIM before it (vessel must be owned)", .suggestion = "Insert CLAIM before SLICE" },
    .{ .name = "POKE", .requires_before = "CLAIM", .error_msg = "POKE requires CLAIM before it (vessel must be owned)", .suggestion = "Insert CLAIM before POKE" },
    .{ .name = "TUNNEL", .requires_before = "CLAIM", .error_msg = "TUNNEL requires CLAIM before it (both endpoints must be owned)", .suggestion = "Insert CLAIM before TUNNEL" },
    .{ .name = "PERSIST", .requires_before = "CLAIM", .error_msg = "PERSIST requires CLAIM before it (vessel must be owned)", .suggestion = "Insert CLAIM before PERSIST" },
};

pub fn validateChain(instrs: []const alkac.Instruction, allocator: std.mem.Allocator) !ChainResult {
    var warnings = std.ArrayList([]const u8).init(allocator);
    var errors = std.ArrayList([]const u8).init(allocator);
    var suggestions = std.ArrayList([]const u8).init(allocator);

    // Track which instruction names have been seen
    var seen = std.StringHashMap(bool).init(allocator);
    defer seen.deinit();

    for (instrs) |instr| {
        try seen.put(instr.name, true);

        // Check chain rules
        for (chain_rules) |rule| {
            if (std.mem.eql(u8, instr.name, rule.name)) {
                const required_seen = seen.get(rule.requires_before) orelse false;
                if (!required_seen) {
                    try errors.append(rule.error_msg);
                    try suggestions.append(rule.suggestion);
                }
            }
        }
    }

    const has_errors = errors.items.len > 0;

    return ChainResult{
        .valid = !has_errors,
        .warnings = try warnings.toOwnedSlice(),
        .errors = try errors.toOwnedSlice(),
        .suggestions = try suggestions.toOwnedSlice(),
    };
}
