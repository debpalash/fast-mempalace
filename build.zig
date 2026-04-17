const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    // Llama.cpp libraries
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/src"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src/ggml-blas"));
    exe.root_module.addLibraryPath(b.path("lib/llama.cpp/build/ggml/src/ggml-metal"));
    
    exe.root_module.linkSystemLibrary("llama", .{});
    exe.root_module.linkSystemLibrary("ggml", .{});
    exe.root_module.linkSystemLibrary("ggml-base", .{});
    exe.root_module.linkSystemLibrary("ggml-cpu", .{});
    exe.root_module.linkSystemLibrary("ggml-blas", .{});
    exe.root_module.linkSystemLibrary("ggml-metal", .{});
    exe.root_module.linkSystemLibrary("c++", .{});

    // Homebrew paths for macOS
    if (target.result.os.tag == .macos) {
        exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        exe.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        
        // Link frameworks required by MLX/Llama.cpp Metal backend
        exe.root_module.linkFramework("Accelerate", .{});
        exe.root_module.linkFramework("Metal", .{});
        exe.root_module.linkFramework("MetalKit", .{});
        exe.root_module.linkFramework("MetalPerformanceShaders", .{});
        exe.root_module.linkFramework("Foundation", .{});
    }

    // ── Llama.cpp Static Libraries ──
    // These must be pre-built via cmake before running `zig build`.
    // First-time setup (documented in README):
    //   cd lib/llama.cpp && mkdir -p build && cd build
    //   cmake .. -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release && cmake --build . -j8

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
    if (target.result.os.tag == .macos) {
        unit_tests.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        unit_tests.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    }

    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
