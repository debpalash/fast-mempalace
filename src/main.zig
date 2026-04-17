// ═══════════════════════════════════════════════════════════════════
// mempalace — Local-first AI Memory System (Zig 0.16)
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const db = @import("db.zig");
const palace = @import("palace.zig");
const miner = @import("miner.zig");
const searcher = @import("searcher.zig");
const embedder = @import("embedder.zig");
const knowledge = @import("knowledge.zig");
const config = @import("config.zig");
const mcp = @import("mcp.zig");

/// Zig 0.16 "Juicy Main" — receives allocator, args, IO from the runtime.
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var cfg = config.load(allocator, init.io) catch config.Config{};
    defer cfg.deinit(allocator);

    embedder.initGlobal(cfg.model_path) catch |err| {
        std.debug.print("Failed to initialize embedder context with model {s}: {}\n", .{cfg.model_path, err});
        return err;
    };
    defer embedder.deinitGlobal();

    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_it.deinit();
    _ = args_it.next(); // skip argv[0] (program name)

    const command = args_it.next() orelse {
        printUsage();
        return;
    };

    if (std.mem.eql(u8, command, "init")) {
        try cmdInit(&cfg);
    } else if (std.mem.eql(u8, command, "mine")) {
        const path = args_it.next() orelse {
            std.debug.print("Usage: mempalace mine <path> [wing]\n", .{});
            return;
        };
        const wing = args_it.next() orelse cfg.default_wing;
        try cmdMine(init.io, path, wing, &cfg, allocator);
    } else if (std.mem.eql(u8, command, "search")) {
        const query = args_it.next() orelse {
            std.debug.print("Usage: mempalace search <query>\n", .{});
            return;
        };
        try cmdSearch(query, &cfg, allocator, init.io);
    } else if (std.mem.eql(u8, command, "stats")) {
        try cmdStats(&cfg, allocator);
    } else if (std.mem.eql(u8, command, "kg")) {
        const subject = args_it.next();
        try cmdKnowledgeGraph(subject, &cfg, allocator);
    } else if (std.mem.eql(u8, command, "mcp")) {
        try mcp.serve(allocator, &cfg, init.io);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\  🏛️  mempalace — Local-first AI Memory System
        \\
        \\  Usage:
        \\    mempalace init                  Initialize palace database
        \\    mempalace mine <path> [wing]    Mine files into the palace
        \\    mempalace search <query>        Semantic search
        \\    mempalace stats                 Palace statistics
        \\    mempalace kg [subject]          Query knowledge graph
        \\
    , .{});
}

fn openDb(cfg: *const config.Config) !db.Database {
    return db.Database.open(cfg.database_path.ptr);
}

fn cmdInit(cfg: *const config.Config) !void {
    std.debug.print("Initializing MemPalace database...\n", .{});
    var database = try openDb(cfg);
    defer database.close();
    database.createPalaceSchema();
    std.debug.print("✓ Palace is ready.\n", .{});
}

fn cmdMine(io: std.Io, path: [:0]const u8, wing_name: []const u8, cfg: *const config.Config, allocator: std.mem.Allocator) !void {
    var database = try openDb(cfg);
    defer database.close();
    database.createPalaceSchema();

    var pal = palace.Palace.init(&database, allocator);

    std.debug.print("Mining '{s}' into wing '{s}'...\n", .{ path, wing_name });

    var stats: miner.MineStats = undefined;

    // We can't easily stat via std.Io yet, so try opening as a file
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch null;
    if (file != null) {
        file.?.close(io);
        stats = try miner.mineConversation(&pal, path, wing_name, io, allocator);
    } else {
        stats = try miner.mineDirectory(&pal, path, .{ .wing_name = wing_name }, io, allocator);
    }

    std.debug.print(
        \\✓ Mining complete.
        \\  Files processed: {}
        \\  Drawers created: {}
        \\  Files skipped:   {}
        \\  Bytes processed: {}
        \\
    , .{ stats.files_processed, stats.drawers_created, stats.files_skipped, stats.bytes_processed });
}

fn cmdSearch(query: [:0]const u8, cfg: *const config.Config, allocator: std.mem.Allocator, io: std.Io) !void {
    var database = try openDb(cfg);
    defer database.close();

    var pal = palace.Palace.init(&database, allocator);

    std.debug.print("Searching for: '{s}'\n\n", .{query});

    const q_vec = try embedder.embed(query, allocator);
    defer allocator.free(q_vec);

    const results = try searcher.searchHybrid(&pal, query, q_vec, .{}, allocator, io);
    defer {
        for (results) |res| {
            allocator.free(res.content);
            allocator.free(res.source_path);
            allocator.free(res.wing_name);
            allocator.free(res.room_name);
        }
        allocator.free(results);
    }

    if (results.len == 0) {
        std.debug.print("No results found in the palace.\n", .{});
        return;
    }

    for (results, 0..) |res, i| {
        std.debug.print("─── Result {d} ───\n", .{i + 1});
        std.debug.print("Wing: {s}  Room: {s}  Score: {d:.4}\n", .{ res.wing_name, res.room_name, res.score });
        std.debug.print("Source: {s}\n", .{res.source_path});

        const len = @min(res.content.len, 200);
        std.debug.print("{s}...\n\n", .{res.content[0..len]});
    }
}

fn cmdStats(cfg: *const config.Config, allocator: std.mem.Allocator) !void {
    var database = try openDb(cfg);
    defer database.close();

    var pal = palace.Palace.init(&database, allocator);

    const stat_str = try pal.stats(allocator);
    defer allocator.free(stat_str);

    std.debug.print("{s}\n", .{stat_str});
}

fn cmdKnowledgeGraph(subject: ?[:0]const u8, cfg: *const config.Config, allocator: std.mem.Allocator) !void {
    var database = try openDb(cfg);
    defer database.close();

    var graph = knowledge.Graph.init(&database, allocator);

    const results = try graph.query(subject, null);
    defer {
        for (results) |r| {
            allocator.free(r.subject);
            allocator.free(r.predicate);
            allocator.free(r.object);
        }
        allocator.free(results);
    }

    if (results.len == 0) {
        std.debug.print("No knowledge graph entries found.\n", .{});
        return;
    }

    for (results) |r| {
        std.debug.print("{s} —[{s}]→ {s}  (confidence: {d:.2})\n", .{
            r.subject, r.predicate, r.object, r.confidence,
        });
    }
}

