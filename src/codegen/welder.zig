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
const alka_bin = @import("alka_bin.zig");
const instructions = @import("../instructions/mod.zig");

/// The Welder stitches pre-compiled binary blobs from the Pharmacopeia
/// into a single contiguous AlkaSol binary stream.
///
/// Each instruction is emitted as a fixed-size Drop (32 bytes).
/// Future versions will support variable-length packets and blob inlining.
pub const Welder = struct {
    pub const WeldError = error{
        UnknownInstruction,
        BufferOverflow,
        InvalidOperand,
    };

    /// Weld a complete program into a binary AlkaSol solution.
    pub fn weldSolution(
        program: anytype,
        out: *std.ArrayList(u8),
    ) WeldError!void {
        for (program.instructions.items) |instr| {
            const inst_def = instructions.getInstructionByName(instr.name) orelse {
                return WeldError.UnknownInstruction;
            };

            const packet = try emitInstruction(inst_def.op_code, instr.operands);
            _ = out.appendSlice(std.mem.asBytes(&packet)) catch return WeldError.BufferOverflow;
        }
    }

    /// Emit a single Drop from opcode + operands.
    fn emitInstruction(
        op_code: instructions.OpCode,
        operands: std.ArrayList(alka_bin.Operand),
    ) WeldError!alka_bin.Drop {
        var packet = std.mem.zeroInit(alka_bin.Drop, .{
            .op_code = @intFromEnum(op_code),
            .flags = 0,
            .vessel_id = 0,
            .src_addr = 0,
            .dst_addr = 0,
            .size = 0,
            .reserved = 0,
            .crc = 0,
        });

        if (operands.items.len >= 1) {
            packet.src_addr = alka_bin.evalOperand(operands.items[0]);
        }
        if (operands.items.len >= 2) {
            packet.dst_addr = alka_bin.evalOperand(operands.items[1]);
        }
        if (operands.items.len >= 3) {
            packet.size = @truncate(alka_bin.evalOperand(operands.items[2]));
        }

        packet.crc = alka_bin.computeCrc(&packet);
        return packet;
    }

    /// Post-precipitation optimization pass on the welded binary.
    /// Performs CRC verification, dead-code stripping (DRY_RUN, MOCK),
    /// and peephole optimization for redundant SYNC sequences.
    pub fn refineBinary(binary: []u8, allocator: std.mem.Allocator) ![]u8 {
        var refined = std.ArrayList(u8).init(allocator);
        errdefer refined.deinit();

        var i: usize = 0;
        var prev_was_sync = false;
        while (i + @sizeOf(alka_bin.Drop) <= binary.len) : (i += @sizeOf(alka_bin.Drop)) {
            var packet: alka_bin.Drop = undefined;
            @memcpy(std.mem.asBytes(&packet), binary[i .. i + @sizeOf(alka_bin.Drop)]);

            // CRC verification
            const computed_crc = alka_bin.computeCrc(&packet);
            if (packet.crc != computed_crc) continue;

            // Dead-code stripping: skip DRY_RUN (0x2C) and MOCK (0x2D) packets
            if (packet.op_code == 0x2C or packet.op_code == 0x2D) continue;

            // Peephole: strip redundant consecutive SYNC packets
            if (packet.op_code == 0x06) {
                if (prev_was_sync) continue;
                prev_was_sync = true;
            } else {
                prev_was_sync = false;
            }

            try refined.appendSlice(binary[i .. i + @sizeOf(alka_bin.Drop)]);
        }
        return refined.toOwnedSlice();
    }
};