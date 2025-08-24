const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spice_dep = b.dependency("spice", .{});
    const spice_mod = spice_dep.module("spice");

    // Server module
    const server_module = b.addModule("grpc-server", .{
        .root_source_file = b.path("src/server.zig"),
        .target = target,
        .optimize = optimize,
    });

    server_module.addImport("spice", spice_mod);
    // b.installArtifact(server_module);

    // Client executable
    const client_module = b.addModule("grpc-client", .{
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_module.addImport("spice", spice_mod);

    // Benchmark executable
    const benchmark = b.addExecutable(.{
        .name = "grpc-benchmark",
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark.root_module.addImport("spice", spice_mod);
    b.installArtifact(benchmark);

    // Benchmark run step
    const run_benchmark = b.addRunArtifact(benchmark);
    run_benchmark.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_benchmark.addArgs(args);
    }
    const benchmark_step = b.step("benchmark", "Run benchmarks");
    benchmark_step.dependOn(&run_benchmark.step);

    // Example executables
    const server_example = b.addExecutable(.{
        .name = "grpc-server-example",
        .root_source_file = b.path("examples/basic_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_example.root_module.addImport("grpc-server", server_module);
    b.installArtifact(server_example);

    const client_example = b.addExecutable(.{
        .name = "grpc-client-example",
        .root_source_file = b.path("examples/basic_client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_example.root_module.addImport("grpc-client", client_module);
    b.installArtifact(client_example);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("grpc-server", server_module);
    tests.root_module.addImport("grpc-client", client_module);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
