// ═══════════════════════════════════════════════════════════════════
// fast-mempalace/hooks.zig — Claude Code / Codex Hook Protocol
//
// Reads JSON from stdin, outputs JSON to stdout.
// Implements the session-start, stop, and precompact hooks
// that enable AI clients to auto-save context into the palace.
//
// Protocol: https://mempalaceofficial.com/guide/hooks.html
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const db = @import("db.zig");
const wakeup = @import("wakeup.zig");

const Allocator = std.mem.Allocator;

// Use POSIX read/write via libc — works identically on macOS and Linux and
// avoids macOS-only symbols like __stdinp/__stdoutp that BSD libc uses.
const c_posix = @cImport({
    @cInclude("unistd.h");
});

const STDIN_FD: c_int = 0;
const STDOUT_FD: c_int = 1;

const STOP_BLOCK_REASON =
    \\AUTO-SAVE checkpoint (Fast MemPalace). Save this session's key content:
    \\1. fast_mempalace_diary_write — session summary
    \\2. fast_mempalace_add_drawer — verbatim quotes, decisions, code snippets
    \\3. fast_mempalace_kg_add — entity relationships (optional)
    \\Continue conversation after saving.
;

const PRECOMPACT_BLOCK_REASON =
    \\COMPACTION IMMINENT (Fast MemPalace). Save ALL session content before context is lost:
    \\1. fast_mempalace_diary_write — thorough session summary
    \\2. fast_mempalace_add_drawer — ALL verbatim quotes, decisions, code, context
    \\3. fast_mempalace_kg_add — entity relationships (optional)
    \\Be thorough — after compaction, detailed context will be lost.
;

/// Process a hook invocation. Reads JSON from stdin, writes JSON to stdout.
pub fn processHook(database: *db.Database, allocator: Allocator) !void {
    var input_buf: [1024 * 1024]u8 = undefined;
    const n = c_posix.read(STDIN_FD, &input_buf, input_buf.len);
    const bytes_read: usize = if (n > 0) @intCast(n) else 0;

    if (bytes_read == 0) {
        writeStdout("{\"error\":\"No input received on stdin\"}\n");
        return;
    }

    const input = input_buf[0..bytes_read];

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, input, .{}) catch {
        writeStdout("{\"error\":\"Invalid JSON on stdin\"}\n");
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;

    const hook_name = if (root.get("hook")) |h| (switch (h) {
        .string => |s| s,
        else => "unknown",
    }) else "unknown";

    if (std.mem.eql(u8, hook_name, "session-start")) {
        try handleSessionStart(database, allocator);
    } else if (std.mem.eql(u8, hook_name, "stop")) {
        handleStop();
    } else if (std.mem.eql(u8, hook_name, "precompact")) {
        handlePrecompact();
    } else {
        writeStdout("{\"error\":\"Unknown hook type\"}\n");
    }
}

fn handleSessionStart(database: *db.Database, allocator: Allocator) !void {
    const context = try wakeup.generate(database, null, allocator);
    defer allocator.free(context);

    const escaped = try jsonEscape(context, allocator);
    defer allocator.free(escaped);

    const response = try std.fmt.allocPrint(allocator, "{{\"result\":\"continue\",\"context\":\"{s}\"}}\n", .{escaped});
    defer allocator.free(response);

    writeStdout(response);
}

fn handleStop() void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{{\"result\":\"block\",\"reason\":\"{s}\"}}\n", .{STOP_BLOCK_REASON}) catch return;
    writeStdout(msg);
}

fn handlePrecompact() void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{{\"result\":\"block\",\"reason\":\"{s}\"}}\n", .{PRECOMPACT_BLOCK_REASON}) catch return;
    writeStdout(msg);
}

fn writeStdout(msg: []const u8) void {
    _ = c_posix.write(STDOUT_FD, msg.ptr, msg.len);
}

fn jsonEscape(text: []const u8, allocator: Allocator) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    for (text) |byte| {
        switch (byte) {
            '"' => {
                try result.append(allocator, '\\');
                try result.append(allocator, '"');
            },
            '\\' => {
                try result.append(allocator, '\\');
                try result.append(allocator, '\\');
            },
            '\n' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 'n');
            },
            '\r' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 'r');
            },
            '\t' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 't');
            },
            else => try result.append(allocator, byte),
        }
    }

    return result.toOwnedSlice(allocator);
}
