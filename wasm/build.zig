const std = @import("std");

pub fn build(b: *std.Build) void {
    var cpu_features = std.Target.Cpu.Feature.Set.empty;
    cpu_features.addFeature(@intFromEnum(std.Target.wasm.Feature.atomics));
    cpu_features.addFeature(@intFromEnum(std.Target.wasm.Feature.bulk_memory));

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_features_add = cpu_features,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.export_symbol_names = &.{ //
        "init",
        "loop",
        "input",
        "score",
        "setAiBehavior",
        "img_size",
        "img_buffer",
        "img_buffer_size",
    };

    const exe = b.addExecutable(.{
        .name = "wasm",
        .root_module = exe_mod,
    });

    exe.entry = .disabled;
    exe.import_symbols = true;
    exe.import_memory = true;
    exe.shared_memory = true;
    // Must match WasmWorker's memoryOptions (1 page = 65536 bytes).
    // initial_memory <= JS initial pages * 65536
    // max_memory must equal JS maximum pages * 65536 exactly (shared memory requirement)
    exe.initial_memory = 2 * 1024 * 1024; // 2 MB  — JS default initial is 100 pages (6.4 MB)
    exe.max_memory = 500 * 65536; // 500 pages — matches JS default maximum

    const zignal = b.dependency("zignal", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zignal", zignal.module("zignal"));

    b.installArtifact(exe);
}
