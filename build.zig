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
    exe.addObjectFile(b.path("src/spark/obj/vitriol_tool_wrapper.o"));
    exe.linkSystemLibrary("gnat");

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Alka compiler");
    run_step.dependOn(&run_cmd.step);

    // Generate dispatch table from pharmacopia manifest
    const gen_dispatch = b.addExecutable(.{
        .name = "gen_dispatch",
        .root_source_file = b.path("build/generate_dispatch.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    const gen_dispatch_run = b.addRunArtifact(gen_dispatch);
    gen_dispatch_run.addFileArg(b.path("pharmacopia.json"));
    gen_dispatch_run.addFileArg(b.path("src/tools/dispatch_table.zig"));

    const dispatch_step = b.step("dispatch", "Generate dispatch table from pharmacopia.json");
    dispatch_step.dependOn(&gen_dispatch_run.step);

    // Pharmacopia CLI tools
    const pharma_exe = b.addExecutable(.{
        .name = "pharmacopia",
        .root_source_file = b.path("build/pharmacopia_build.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    b.installArtifact(pharma_exe);

    const pharma_list = b.addRunArtifact(pharma_exe);
    pharma_list.addFileArg(b.path("pharmacopia.json"));
    pharma_list.addArg("list");
    const list_step = b.step("list", "List all tools in pharmacopia");
    list_step.dependOn(&pharma_list.step);

    const pharma_verify = b.addRunArtifact(pharma_exe);
    pharma_verify.addFileArg(b.path("pharmacopia.json"));
    pharma_verify.addArg("verify");
    const verify_step = b.step("verify", "Verify SPARK tools with gnatprove");
    verify_step.dependOn(&pharma_verify.step);

    // Test step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // SPARK integration tests
    const spark_tests = b.addTest(.{
        .root_source_file = b.path("tests/spark_integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    const spark_mod = b.createModule(.{ .root_source_file = b.path("src/tools/core/spark_bridge.zig") });
    spark_tests.root_module.addImport("spark_tools", spark_mod);

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

    // Tool harness tests — all 43 tools validated against edge cases
    const harness_tests = b.addTest(.{
        .root_source_file = b.path("tests/tool_harness.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tools_mod = b.createModule(.{ .root_source_file = b.path("src/tools/mod.zig") });
    harness_tests.root_module.addImport("tools", tools_mod);

    harness_tests.addObjectFile(b.path("src/spark/obj/vitriol_types.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/tool_shift.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/tool_refract.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/tool_flow.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/tool_fence.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/tool_signal.o"));
    harness_tests.addObjectFile(b.path("src/spark/obj/vitriol_tool_wrapper.o"));
    harness_tests.linkSystemLibrary("gnat");

    const run_harness_tests = b.addRunArtifact(harness_tests);
    const harness_test_step = b.step("test-harness", "Run tool harness edge-case tests");
    harness_test_step.dependOn(&run_harness_tests.step);

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
