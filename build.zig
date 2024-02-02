const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Setup Module
    const animate_mod = b.addModule("animate", .{
        .root_source_file = .{ .path = "src/main.zig" },
    });

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = .{ .path = "demo/demo.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    demo.root_module.addImport("animate", animate_mod);

    const run_demo = b.addRunArtifact(demo);

    const run_demo_step = b.step("demo", "Run demo");
    run_demo_step.dependOn(&run_demo.step);
}
