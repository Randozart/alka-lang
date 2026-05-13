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

    const binary = try codegen.emitDrops(program, vial, &arena);
    try std.testing.expect(binary.len == 32);
}

test "Drop has correct opcodes" {
    const source = "CLAIM GPU_MAIN;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const program = try parser.parseAlka(source, &arena);
    const vial = try parser.parseVial("Vessel GPU_MAIN { }", &arena);

    const binary = try codegen.emitDrops(program, vial, &arena);

    const packet = @as(*const codegen.Drop, @alignCast(binary.ptr));
    try std.testing.expectEqual(codegen.OpCodes.CLAIM, packet.op_code);
}

// SPARK C ABI Bridge Integration Tests

test "SPARK SHIFT: valid page-aligned offset passes validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 4,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x1000, // 4KB aligned
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(spark_tools.validateShift(&vial, &drop));
}

test "SPARK SHIFT: non-aligned offset fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 4,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x1001, // Not 4KB aligned
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateShift(&vial, &drop));
}

test "SPARK SHIFT: offset exceeding aperture fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 4,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 256 * 1024 * 1024 + 0x1000, // Beyond aperture
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateShift(&vial, &drop));
}

test "SPARK SHIFT: execute returns success on valid input" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 4,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x1000,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    const result = spark_tools.executeShift(&vial, &drop);
    try std.testing.expect(result.success);
}

test "SPARK FLOW: valid DMA transfer passes validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = true,
    };
    var drop = spark_tools.Drop{
        .op_kind = 3,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x100000,
        .dst_addr = 0x200000,
        .size = 1024,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(spark_tools.validateFlow(&vial, &drop));
}

test "SPARK FLOW: zero size fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = true,
    };
    var drop = spark_tools.Drop{
        .op_kind = 3,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x100000,
        .dst_addr = 0x200000,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateFlow(&vial, &drop));
}

test "SPARK FLOW: non-DMA capable fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 256 * 1024 * 1024,
        .aperture_max = 256 * 1024 * 1024,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 3,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x100000,
        .dst_addr = 0x200000,
        .size = 1024,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateFlow(&vial, &drop));
}

test "SPARK FENCE: valid timeout passes validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 5,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 1_000_000, // 1 second timeout
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(spark_tools.validateFence(&vial, &drop));
}

test "SPARK FENCE: zero timeout fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 5,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateFence(&vial, &drop));
}

test "SPARK SIGNAL: valid signal ID passes validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 9,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 42,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(spark_tools.validateSignal(&vial, &drop));
}

test "SPARK SIGNAL: zero signal ID fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 9,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateSignal(&vial, &drop));
}

test "SPARK SIGNAL: 64-bit signal ID fails validation" {
    var vial = spark_tools.VialConstraints{
        .aperture_size = 0,
        .aperture_max = 0,
        .thermal_halt = 0,
        .thermal_throttle = 0,
        .dma_capable = false,
    };
    var drop = spark_tools.Drop{
        .op_kind = 9,
        .flags = 0,
        .vessel_id = 0,
        .src_addr = 0x1_0000_0000, // Exceeds 32-bit
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateSignal(&vial, &drop));
}