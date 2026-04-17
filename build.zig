const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_macos = target.result.os.tag == .macos;

    // ── Main executable ──
    const exe = b.addExecutable(.{
        .name = "fast-mempalace",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // SQLite3 (system library)
    exe.root_module.linkSystemLibrary("sqlite3", .{});

    // sqlite-vec extension (compiled from source)
    exe.root_module.addCSourceFile(.{
        .file = b.path("lib/sqlite-vec.c"),
        .flags = &[_][]const u8{ "-O3", "-fomit-frame-pointer", "-DSQLITE_CORE" },
    });

    // Include paths for C headers
    exe.root_module.addIncludePath(b.path("lib"));
    exe.root_module.addIncludePath(b.path("lib/llama.cpp/include"));
    exe.root_module.addIncludePath(b.path("lib/llama.cpp/ggml/include"));

    // Llama.cpp library paths (cmake output)
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/src"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src/ggml-cpu"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src/ggml-blas"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src/ggml-metal"));

    // Core llama.cpp + ggml (present on all platforms)
    exe.root_module.linkSystemLibrary("llama", .{});
    exe.root_module.linkSystemLibrary("ggml", .{});
    exe.root_module.linkSystemLibrary("ggml-base", .{});
    exe.root_module.linkSystemLibrary("ggml-cpu", .{});
    exe.root_module.linkSystemLibrary("c++", .{});

    if (is_macos) {
        // macOS: link Metal backend + Accelerate BLAS, and the system frameworks
        // llama.cpp's Metal backend depends on.
        exe.root_module.linkSystemLibrary("ggml-blas", .{});
        exe.root_module.linkSystemLibrary("ggml-metal", .{});

        exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        exe.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });

        exe.root_module.linkFramework("Accelerate", .{});
        exe.root_module.linkFramework("Metal", .{});
        exe.root_module.linkFramework("MetalKit", .{});
        exe.root_module.linkFramework("MetalPerformanceShaders", .{});
        exe.root_module.linkFramework("Foundation", .{});
    }

    // ── Llama.cpp Static Libraries ──
    // These must be pre-built via cmake before running `zig build`.
    // First-time setup:
    //   macOS:  cmake -S lib/llama.cpp -B lib/llama.cpp/build \
    //             -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON \
    //             -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF
    //   Linux:  cmake -S lib/llama.cpp -B lib/llama.cpp/build \
    //             -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF \
    //             -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF
    //   cmake --build lib/llama.cpp/build -j

    b.installArtifact(exe);

    // ── Run step ──
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run fast-mempalace");
    run_step.dependOn(&run_cmd.step);

    // ── Tests ──
    const test_step = b.step("test", "Run unit tests");

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    unit_tests.root_module.linkSystemLibrary("sqlite3", .{});
    unit_tests.root_module.addCSourceFile(.{
        .file = b.path("lib/sqlite-vec.c"),
        .flags = &[_][]const u8{ "-O3", "-fomit-frame-pointer", "-DSQLITE_CORE" },
    });
    unit_tests.root_module.addIncludePath(b.path("lib"));
    if (is_macos) {
        unit_tests.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        unit_tests.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    }

    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
