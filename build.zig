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

    // Link SPARK Ada tools (formally verified via gnatprove + Z3)
    // Built with: gprbuild -P src/spark/vitriol_tools.gpr
    exe.addObjectFile(b.path("src/spark/obj/vitriol_types.o"));
    exe.addObjectFile(b.path("src/spark/obj/tool_shift.o"));
    exe.addObjectFile(b.path("src/spark/obj/tool_refract.o"));
    exe.addObjectFile(b.path("src/spark/obj/tool_flow.o"));
    exe.addObjectFile(b.path("src/spark/obj/tool_fence.o"));
    exe.addObjectFile(b.path("src/spark/obj/tool_signal.o"));

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
        .root_source_file = b.path("tests/all.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // SPARK integration tests (links SPARK Ada tools)
    const spark_tests = b.addTest(.{
        .root_source_file = b.path("tests/spark_integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    const spark_mod = b.createModule(.{ .root_source_file = b.path("src/tools/core/spark_bridge.zig") });
    spark_tests.root_module.addImport("spark_tools", spark_mod);

    // Link SPARK Ada tools for tests
    spark_tests.addObjectFile(b.path("src/spark/obj/vitriol_types.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/tool_shift.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/tool_refract.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/tool_flow.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/tool_fence.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/tool_signal.o"));
    spark_tests.addObjectFile(b.path("src/spark/obj/vitriol_tool_wrapper.o"));
    spark_tests.linkSystemLibrary("gnat");

    const run_spark_tests = b.addRunArtifact(spark_tests);
    const spark_test_step = b.step("test-spark", "Run SPARK C ABI integration tests");
    spark_test_step.dependOn(&run_spark_tests.step);

    // Generate vitriol.h header for kernel module
    const header_step = b.step("header", "Generate vitriol.h IOCTL header");
    const header_gen = b.addExecutable(.{
        .name = "gen_header",
        .root_source_file = b.path("src/tools/header_gen.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const header_run = b.addRunArtifact(header_gen);
    header_run.addArg(b.pathJoin(&.{ b.install_path, "include", "vitriol_alka.h" }));
    header_step.dependOn(&header_run.step);
}
