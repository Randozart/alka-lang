const std = @import("std");
const spark_tools = @import("spark_tools");

// SPARK C ABI Bridge Integration Tests
// These tests verify that the Zig <-> SPARK Ada C ABI bridge works correctly.
// Each SPARK tool is formally verified by gnatprove before linking.

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
        .src_addr = 0x1000,
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
        .src_addr = 0x1001,
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
        .src_addr = 256 * 1024 * 1024 + 0x1000,
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
        .src_addr = 1_000_000,
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
        .src_addr = 0x1_0000_0000,
        .dst_addr = 0,
        .size = 0,
        .reserved = 0,
        .crc = 0,
    };

    try std.testing.expect(!spark_tools.validateSignal(&vial, &drop));
}
