// Tool Chain Validator — validates instruction sequences against chain graph
//
// Loaded from pharmacopia.json via generate_chain_rules.zig at build time.
// Validates:
// 1. Pre-state requirements (errors if missing)
// 2. Post-state transitions (tracks state across chain)
// 3. Side-effect accumulation (thermal, memory, etc.)
// 4. Warnings for risky sequences (warns_if_before)
// 5. Suggestions for missing links (suggests_after)
//
// Override: --override flag suppresses warnings (not errors)

const std = @import("std");
const alkac = @import("alkac.zig");
const chain_rules = @import("chain_rules.zig");

pub const ChainError = error{
    PreStateUnsatisfied,
    ImpossibleSequence,
    SideEffectOverflow,
};

pub const ChainResult = struct {
    valid: bool,
    warnings: []const []const u8,
    errors: []const []const u8,
    suggestions: []const []const u8,
    final_states: []const []const u8,
    side_effects: []const []const u8,
};

pub const ChainConfig = struct {
    override: bool = false,
    max_thermal_effects: usize = 10,
    max_memory_effects: usize = 20,
};

pub fn validateChain(instrs: []const alkac.Instruction, allocator: std.mem.Allocator, config: ChainConfig) !ChainResult {
    var warnings = std.ArrayList([]const u8).init(allocator);
    var errors = std.ArrayList([]const u8).init(allocator);
    var suggestions = std.ArrayList([]const u8).init(allocator);
    var final_states = std.ArrayList([]const u8).init(allocator);
    var side_effects = std.ArrayList([]const u8).init(allocator);

    // Track which states have been established
    var active_states = std.StringHashMap(bool).init(allocator);
    defer active_states.deinit();

    // Track which instruction names have been seen (for warns_if_before)
    var seen_instructions = std.StringHashMap(bool).init(allocator);
    defer seen_instructions.deinit();

    // Track side-effect counts
    var thermal_count: usize = 0;
    var memory_count: usize = 0;

    for (instrs) |instr| {
        // Find the chain rule for this instruction
        const rule = findRuleByName(instr.name);
        if (rule == null) {
            // Unknown instruction — skip chain validation
            try seen_instructions.put(instr.name, true);
            continue;
        }

        const r = rule.?;

        // 1. Check pre-state requirements (ERRORS if missing)
        for (r.pre_state) |required_state| {
            const state_active = active_states.get(required_state) orelse false;
            if (!state_active) {
                const msg = try std.fmt.allocPrint(allocator, "{s} requires state '{s}' (not established)", .{ instr.name, required_state });
                try errors.append(msg);
            }
        }

        // 2. Check warns_if_before (WARNINGS if violated)
        for (r.warns_if_before) |warn_name| {
            const was_seen = seen_instructions.get(warn_name) orelse false;
            if (was_seen) {
                if (!config.override) {
                    const msg = try std.fmt.allocPrint(allocator, "{s} after {s} may be risky", .{ instr.name, warn_name });
                    try warnings.append(msg);
                }
            }
        }

        // 3. Add post-states to active states
        for (r.post_state) |state| {
            try active_states.put(state, true);
            try final_states.append(state);
        }

        // 4. Track side-effects
        for (r.side_effects) |effect| {
            try side_effects.append(effect);

            if (std.mem.indexOf(u8, effect, "thermal") != null) {
                thermal_count += 1;
                if (thermal_count > config.max_thermal_effects) {
                    const msg = try std.fmt.allocPrint(allocator, "Excessive thermal effects ({}) — consider cooling steps", .{thermal_count});
                    if (!config.override) {
                        try warnings.append(msg);
                    }
                }
            }
            if (std.mem.indexOf(u8, effect, "memory") != null) {
                memory_count += 1;
                if (memory_count > config.max_memory_effects) {
                    const msg = try std.fmt.allocPrint(allocator, "Excessive memory modifications ({}) — verify integrity", .{memory_count});
                    if (!config.override) {
                        try warnings.append(msg);
                    }
                }
            }
        }

        // 5. Add suggestions for next steps
        for (r.suggests_after) |suggested| {
            // Only suggest if not already seen
            const already_seen = seen_instructions.get(suggested) orelse false;
            if (!already_seen) {
                const msg = try std.fmt.allocPrint(allocator, "Consider {s} after {s}", .{ suggested, instr.name });
                try suggestions.append(msg);
            }
        }

        try seen_instructions.put(instr.name, true);
    }

    const has_errors = errors.items.len > 0;

    return ChainResult{
        .valid = !has_errors,
        .warnings = try warnings.toOwnedSlice(),
        .errors = try errors.toOwnedSlice(),
        .suggestions = try suggestions.toOwnedSlice(),
        .final_states = try final_states.toOwnedSlice(),
        .side_effects = try side_effects.toOwnedSlice(),
    };
}

fn findRuleByName(name: []const u8) ?*const chain_rules.ChainRule {
    for (&chain_rules.chain_rules) |*rule| {
        if (std.mem.eql(u8, rule.name, name)) {
            return rule;
        }
    }
    return null;
}
