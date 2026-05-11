const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main compiler binary
    const exe = b.addExecutable(.{
        .name = "alka",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Alka compiler");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Generate vitriol.h header for kernel module
    const header_step = b.step("header", "Generate vitriol.h IOCTL header");
    const header_gen = b.addExecutable(.{
        .name = "gen_header",
        .root_source_file = b.path("src/tools/header_gen.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const header_run = b.addRunArtifact(header_gen);
    header_run.addArg(b.pathJoin(&.{ b.install_path.?, "include", "vitriol_alka.h" }));
    header_step.dependOn(&header_run.step);
}
