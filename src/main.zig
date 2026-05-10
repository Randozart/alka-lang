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
    try alkac.compile(program, vial, &binary);

    const out_path = try std.fmt.allocPrint(allocator, "{s}.alkas", .{ source_path });
    defer allocator.free(out_path);

    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = binary.items });

    std.debug.print("Emitted: {s} ({} bytes, {} packets)\n", .{
        out_path,
        binary.items.len,
        binary.items.len / @sizeOf(alka_bin.MetrodPacket),
    });
}