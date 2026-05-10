const std = @import("std");
const parser = @import("parser/parser.zig");
const compiler = @import("compiler/compiler.zig");
const codegen = @import("codegen/codegen.zig");

extern "c" var __argc: c_int;
extern "c" var __argv: [*c][*:0]u8;

pub fn main() !void {
    const argc = @as(usize, @intCast(__argc));
    const argv: [][*:0]u8 = @as([*][*:0]u8, @ptrCast(__argv))[0..argc];

    if (argc < 3) {
        std.debug.print("Alka Compiler v0.1.0\n", .{});
        std.debug.print("Usage: alkac <source.alka> <vial.alkavl>\n", .{});
        std.debug.print("Output: <source>.alkab (Metrod binary)\n", .{});
        return;
    }

    const source_path = std.mem.sliceTo(argv[1], 0);
    const vial_path = std.mem.sliceTo(argv[2], 0);

    std.debug.print("Compiling: {s} with {s}\n", .{ source_path, vial_path });

    const source = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, source_path, std.math.maxInt(usize));
    defer std.heap.page_allocator.free(source);

    const vial_data = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, vial_path, std.math.maxInt(usize));
    defer std.heap.page_allocator.free(vial_data);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const parsed_program = try parser.parseAlka(source, &arena);
    const parsed_vial = try parser.parseVial(vial_data, &arena);

    try compiler.validate(parsed_program, parsed_vial);

    const binary = try codegen.emitMetrod(parsed_program, parsed_vial, &arena);

    const out_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.alkab", .{ source_path });
    defer std.heap.page_allocator.free(out_path);

    try std.fs.cwd().writeFile(out_path, binary);

    std.debug.print("Emitted: {s} ({} bytes)\n", .{ out_path, binary.len });
}