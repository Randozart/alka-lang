const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{ .name = "alka", .target = target });

    exe.addRootSourceFile("src/main.zig");

    b.installArtifact(exe);
}