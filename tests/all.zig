const std = @import("std");
const parser = @import("src/parser/parser.zig");
const compiler = @import("src/compiler/compiler.zig");
const codegen = @import("src/codegen/codegen.zig");

test "Parse simple CLAIM instruction" {
    const source = "CLAIM GPU_MAIN;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    try std.testing.expect(program.instructions.len == 1);
    try std.testing.expect(program.instructions.items[0] == .claim);
}

test "Parse FLOW instruction" {
    const source = "FLOW src -> dst 256MB;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    try std.testing.expect(program.instructions.len == 1);
    try std.testing.expect(program.instructions.items[0] == .flow);
}

test "Parse REQUIRE directive" {
    const source = "REQUIRE my_vial.alkavl;\nCLAIM GPU;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    try std.testing.expect(program.requires.len == 1);
    try std.testing.expectEqualStrings("my_vial.alkavl", program.requires.items[0]);
}

test "Parse Vial with Vessel definition" {
    const source =
        \\Vessel GPU {
        \\    PCI_ID: 10de:1b82;
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const vial = try parser.parseVial(source, &arena);
    try std.testing.expect(vial.vessels.contains("GPU"));
}

test "Codegen emits 32-byte packets" {
    const source = "CLAIM GPU_MAIN;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    const vial = try parser.parseVial("Vessel GPU_MAIN { }", &arena);

    const binary = try codegen.emitMetrod(program, vial, &arena);
    try std.testing.expect(binary.len == 32);
}

test "Metrod packet has correct opcodes" {
    const source = "CLAIM GPU_MAIN;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    const vial = try parser.parseVial("Vessel GPU_MAIN { }", &arena);

    const binary = try codegen.emitMetrod(program, vial, &arena);

    const packet = @as(*const codegen.MetrodPacket, @alignCast(binary.ptr));
    try std.testing.expectEqual(codegen.OpCodes.CLAIM, packet.op_code);
}