const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "alkac",
        .root_source_file = "src/main.zig",
    });

    exe.addModule("compiler", b.createModule(.{
        .source_file = "src/compiler/compiler.zig",
    }));

    exe.addModule("parser", b.createModule(.{
        .source_file = "src/parser/parser.zig",
    }));

    exe.addModule("codegen", b.createModule(.{
        .source_file = "src/codegen/codegen.zig",
    }));

    b.installArtifact(exe);

    const tests = b.addTest(.{
        .root_source_file = "tests/all.zig",
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(b.run(tests).step);
}