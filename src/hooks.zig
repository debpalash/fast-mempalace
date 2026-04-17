// ═══════════════════════════════════════════════════════════════════
// mempalace/hooks.zig — Claude Code / Codex Hook Protocol
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

const c_io = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

const STOP_BLOCK_REASON =
    \\AUTO-SAVE checkpoint (MemPalace). Save this session's key content:
    \\1. mempalace_diary_write — session summary
    \\2. mempalace_add_drawer — verbatim quotes, decisions, code snippets
    \\3. mempalace_kg_add — entity relationships (optional)
    \\Continue conversation after saving.
;

const PRECOMPACT_BLOCK_REASON =
    \\COMPACTION IMMINENT (MemPalace). Save ALL session content before context is lost:
    \\1. mempalace_diary_write — thorough session summary
    \\2. mempalace_add_drawer — ALL verbatim quotes, decisions, code, context
    \\3. mempalace_kg_add — entity relationships (optional)
    \\Be thorough — after compaction, detailed context will be lost.
;

/// Process a hook invocation. Reads JSON from stdin, writes JSON to stdout.
pub fn processHook(database: *db.Database, allocator: Allocator) !void {
    // Read stdin via C stdio (__stdinp on macOS)
    var input_buf: [1024 * 1024]u8 = undefined;
    const stdin_handle = c_io.__stdinp;
    const bytes_read = c_io.fread(&input_buf, 1, input_buf.len, stdin_handle);

    if (bytes_read == 0) {
        cPuts("{\"error\":\"No input received on stdin\"}\n");
        return;
    }

    const input = input_buf[0..bytes_read];

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, input, .{}) catch {
        cPuts("{\"error\":\"Invalid JSON on stdin\"}\n");
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
        cPuts("{\"error\":\"Unknown hook type\"}\n");
    }
}

fn handleSessionStart(database: *db.Database, allocator: Allocator) !void {
    const context = try wakeup.generate(database, null, allocator);
    defer allocator.free(context);

    // Build JSON response with escaped context
    const escaped = try jsonEscape(context, allocator);
    defer allocator.free(escaped);

    const response = try std.fmt.allocPrint(allocator, "{{\"result\":\"continue\",\"context\":\"{s}\"}}\n", .{escaped});
    defer allocator.free(response);

    std.debug.print("{s}", .{response});
}

fn handleStop() void {
    std.debug.print("{{\"result\":\"block\",\"reason\":\"{s}\"}}\n", .{STOP_BLOCK_REASON});
}

fn handlePrecompact() void {
    std.debug.print("{{\"result\":\"block\",\"reason\":\"{s}\"}}\n", .{PRECOMPACT_BLOCK_REASON});
}

fn cPuts(msg: [*:0]const u8) void {
    _ = c_io.fputs(msg, c_io.__stdoutp);
}

fn jsonEscape(text: []const u8, allocator: Allocator) ![]u8 {
    // Worst case: every byte needs escaping (2x)
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
