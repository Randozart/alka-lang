// SMT-LIB2 Generator for Alka Proof Engine
//
// Translates Alka recipes + Vial constraints into Z3-compatible SMT-LIB2 format.
// Checks: no double-CLAIM, FLOW ≤ aperture, thermal limits, FENCE/SIGNAL pairing.

const std = @import("std");
const alkac = @import("../compiler/alkac.zig");
const alka_bin = @import("../codegen/alka_bin.zig");
const instructions = @import("../instructions/mod.zig");

pub const ProofFailure = struct {
    counterexample: []const u8,
    instruction_index: usize,
};

pub const ProofResult = union(enum) {
    proved: void,
    failed: ProofFailure,
    err_msg: []const u8,
};

fn evalOperand(op: alka_bin.Operand) u64 {
    return switch (op) {
        .literal => |v| v,
        .memory_size => |m| m.value,
        .identifier => 0,
        .indexed => |idx| idx.index,
    };
}

fn roundUpToNearest(n: u64, multiple: u64) u64 {
    return (n + multiple - 1) / multiple;
}

pub fn generateSmtLib(program: alkac.Program, vial: alkac.Vial, allocator: std.mem.Allocator) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    const w = buf.writer();

    try w.print("; Alka Proof Engine -- SMT-LIB2\n", .{});
    try w.print("; Program: {d} instructions\n\n", .{program.instructions.items.len});
    try w.print("(set-logic QF_BV)\n", .{});
    try w.print("(set-option :produce-models true)\n\n", .{});
    try w.print("(define-sort Addr () (_ BitVec 64))\n", .{});
    try w.print("(define-sort Size () (_ BitVec 32))\n\n", .{});

    // Vial constants: aperture bounds
    var vessel_idx: usize = 0;
    var it = vial.vessels.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        const vessel = entry.value_ptr.*;
        try w.print("; {s}\n", .{name});
        if (vessel.pci_id) |p| {
            try w.print("(define-const VENDOR_{d} (_ BitVec 16) #x{x:0>4})\n", .{vessel_idx, p.vendor});
            try w.print("(define-const DEVICE_{d} (_ BitVec 16) #x{x:0>4})\n", .{vessel_idx, p.device});
        }
        for (vessel.apertures.items, 0..) |ap, ai| {
            if (ap.max_window) |mw| {
                try w.print("(define-const WIN_{d}_{d} (_ BitVec 32) #x{x:0>8})\n", .{vessel_idx, ai, mw});
            } else if (ap.size) |s| {
                try w.print("(define-const WIN_{d}_{d} (_ BitVec 32) #x{x:0>8})\n", .{vessel_idx, ai, s});
            }
            if (ap.size) |s| {
                try w.print("(define-const AP_SIZE_{d}_{d} (_ BitVec 32) #x{x:0>8})\n", .{vessel_idx, ai, s});
            }
        }
        vessel_idx += 1;
    }
    try w.print("\n", .{});

    // Instruction-level constraints
    var claimed: ?usize = null;
    var thermal_limited: bool = false;

    for (program.instructions.items, 0..) |instr, i| {
        const op = instructions.getInstructionByName(instr.name);
        const name = if (op) |o| o.name else instr.name;

        if (std.mem.eql(u8, name, "CLAIM")) {
            if (claimed) |prev| {
                try w.print("(assert false) ; Double CLAIM at step {d}, already claimed at step {d}\n", .{i, prev});
            }
            claimed = i;
            try w.print("; CLAIM valid at step {d}\n", .{i});
        }

        if (std.mem.eql(u8, name, "FLOW") and instr.operands.items.len >= 3) {
            const size = evalOperand(instr.operands.items[2]);
            try w.print("(declare-const flow_{d}_ok Bool)\n", .{i});
            try w.print("(assert (= flow_{d}_ok (bvule #x{x:0>8} WIN_0_0)))\n", .{i, size});
            try w.print("(assert flow_{d}_ok) ; FLOW {d} bytes fits in aperture\n", .{i, size});
            if (!thermal_limited) {
                try w.print("(assert false) ; FLOW at step {d} without prior LIMIT\n", .{i});
            }
        }

        if (std.mem.eql(u8, name, "REFRACT") and instr.operands.items.len >= 3) {
            const chunk = evalOperand(instr.operands.items[2]);
            try w.print("(declare-const refr_{d}_ok Bool)\n", .{i});
            try w.print("(assert (= refr_{d}_ok (bvule #x{x:0>8} WIN_0_0)))\n", .{i, chunk});
            try w.print("(assert refr_{d}_ok) ; REFRACT chunk {d} bytes fits in aperture\n", .{i, chunk});
        }

        if (std.mem.eql(u8, name, "LIMIT")) {
            thermal_limited = true;
            try w.print("; Thermal limit set at step {d}\n", .{i});
        }

        if (std.mem.eql(u8, name, "FENCE")) {
            var has_signal_after = false;
            for (program.instructions.items[i+1..]) |next| {
                const next_op = instructions.getInstructionByName(next.name);
                if (next_op) |no| {
                    if (std.mem.eql(u8, no.name, "SIGNAL")) has_signal_after = true;
                }
            }
            if (!has_signal_after) {
                try w.print("(assert false) ; FENCE at step {d} without subsequent SIGNAL\n", .{i});
            }
        }
    }

    try w.print("\n(check-sat)\n", .{});

    return buf.toOwnedSlice();
}

pub fn runZ3(smt_input: []const u8, allocator: std.mem.Allocator) !ProofResult {
    const tmp_path = "/tmp/alka_proof.smt2";
    try std.fs.cwd().writeFile(.{ .sub_path = tmp_path, .data = smt_input });

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "z3", "-smt2", tmp_path },
    });

    const stdout_str = result.stdout;
    const stderr_str = result.stderr;

    if (std.mem.indexOf(u8, stdout_str, "sat") != null and std.mem.indexOf(u8, stdout_str, "unsat") == null) {
        return ProofResult{ .proved = {} };
    } else if (std.mem.indexOf(u8, stdout_str, "unsat") != null) {
        return ProofResult{ .failed = .{
            .counterexample = stdout_str,
            .instruction_index = 0,
        } };
    }

    if (result.term == .Exited) {
        const code = result.term.Exited;
        if (code == 127 or std.mem.indexOf(u8, stderr_str, "not found") != null) {
            return ProofResult{ .err_msg = "Z3 solver not found. Install: sudo apt install z3" };
        }
        if (std.mem.indexOf(u8, stderr_str, "error") != null) {
            return ProofResult{ .err_msg = stderr_str };
        }
        if (code != 0) {
            return ProofResult{ .err_msg = stderr_str };
        }
    }

    return ProofResult{ .err_msg = stdout_str };
}
