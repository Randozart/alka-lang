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
const alka_bin = @import("codegen/alka_bin.zig");
const alkac = @import("compiler/alkac.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Alka Compiler v1.0\n", .{});
        std.debug.print("Usage: alka <source.alka> <vial.alkavl> [-o output.alkab]\n", .{});
        return;
    }

    const source_path = args[1];
    const vial_path = args[2];

    std.debug.print("Compiling: {s} + {s}\n", .{ source_path, vial_path });

    const source = try std.fs.cwd().readFileAlloc(allocator, source_path, std.math.maxInt(usize));
    defer allocator.free(source);

    const vial_data = try std.fs.cwd().readFileAlloc(allocator, vial_path, std.math.maxInt(usize));
    defer allocator.free(vial_data);

    const program = try alkac.parseProgram(source, allocator);
    const vial = try alkac.parseVial(vial_data, allocator);

    try alkac.analyzeWithTools(program, vial, allocator);

    var binary = std.ArrayList(u8).init(allocator);
    try alkac.compile(program, vial, &binary, allocator);

    const out_path = try std.fmt.allocPrint(allocator, "{s}.alkas", .{ source_path });
    defer allocator.free(out_path);

    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = binary.items });

    std.debug.print("Emitted: {s} ({} bytes, {} packets)\n", .{
        out_path,
        binary.items.len,
        binary.items.len / @sizeOf(alka_bin.MetrodPacket),
    });
}