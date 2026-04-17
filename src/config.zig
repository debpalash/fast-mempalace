const std = @import("std");

pub const Config = struct {
    default_wing: [:0]const u8 = "default",
    database_path: [:0]const u8 = "fast-mempalace.db",
    model_path: [:0]const u8 = "lib/minilm.gguf",
    auto_accept_entities: bool = false,
    ignore_patterns: [][]const u8 = &[_][]const u8{},

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.ignore_patterns) |pat| {
            allocator.free(pat);
        }
        allocator.free(self.ignore_patterns);

        if (!std.mem.eql(u8, self.default_wing, "default")) {
            allocator.free(self.default_wing);
        }
        if (!std.mem.eql(u8, self.database_path, "fast-mempalace.db")) {
            allocator.free(self.database_path);
        }
        if (!std.mem.eql(u8, self.model_path, "lib/minilm.gguf")) {
            allocator.free(self.model_path);
        }
    }
};

/// Attempt to load config from the current directory. Tries `fast-mempalace.yaml`
/// first, then falls back to `mempalace.yaml` for drop-in compatibility with the
/// legacy Python package. Returns defaults if neither exists.
pub fn load(allocator: std.mem.Allocator, io: std.Io) !Config {
    var file = std.Io.Dir.cwd().openFile(io, "fast-mempalace.yaml", .{}) catch |err1| blk: {
        if (err1 != error.FileNotFound) return err1;
        break :blk std.Io.Dir.cwd().openFile(io, "mempalace.yaml", .{}) catch |err2| {
            if (err2 == error.FileNotFound) return Config{};
            return err2;
        };
    };
    defer file.close(io);

    const stat = try file.stat(io);
    if (stat.size > 10 * 1024 * 1024) return error.FileTooLarge; // arbitrary 10mb limit

    const contents = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(contents);
    
    _ = try file.readPositionalAll(io, contents, 0);

    var cfg = Config{};
    var patterns = std.ArrayListUnmanaged(String).empty;
    defer {
        for (patterns.items) |p| {
            allocator.free(p);
        }
        patterns.deinit(allocator);
    }
    
    var in_ignore_patterns = false;
    var line_it = std.mem.splitScalar(u8, contents, '\n');
    
    while (line_it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0 or line[0] == '#') continue;
        
        if (std.mem.startsWith(u8, line, "default_wing:")) {
            in_ignore_patterns = false;
            const val = extractYamlValue(line["default_wing:".len..]);
            if (val.len > 0 and !std.mem.eql(u8, val, "default")) {
                cfg.default_wing = try allocator.dupeZ(u8, val);
            }
        } else if (std.mem.startsWith(u8, line, "database_path:")) {
            in_ignore_patterns = false;
            const val = extractYamlValue(line["database_path:".len..]);
            if (val.len > 0 and !std.mem.eql(u8, val, "fast-mempalace.db")) {
                cfg.database_path = try allocator.dupeZ(u8, val);
            }
        } else if (std.mem.startsWith(u8, line, "model_path:")) {
            in_ignore_patterns = false;
            const val = extractYamlValue(line["model_path:".len..]);
            if (val.len > 0 and !std.mem.eql(u8, val, "lib/minilm.gguf")) {
                cfg.model_path = try allocator.dupeZ(u8, val);
            }
        } else if (std.mem.startsWith(u8, line, "auto_accept_entities:")) {
            in_ignore_patterns = false;
            const val = extractYamlValue(line["auto_accept_entities:".len..]);
            if (std.mem.eql(u8, val, "true")) cfg.auto_accept_entities = true;
        } else if (std.mem.startsWith(u8, line, "ignore_patterns:")) {
            in_ignore_patterns = true;
        } else if (in_ignore_patterns and std.mem.startsWith(u8, raw_line, "  -")) {
            const val = extractYamlValue(std.mem.trim(u8, raw_line, " \r\t-"));
            if (val.len > 0) {
                try patterns.append(allocator, try allocator.dupe(u8, val));
            }
        } else {
            // Unrecognized line or exiting block
            if (!std.mem.startsWith(u8, raw_line, " ")) {
                in_ignore_patterns = false;
            }
        }
    }
    
    if (patterns.items.len > 0) {
        var ignored = try allocator.alloc([]const u8, patterns.items.len);
        for (patterns.items, 0..) |pat, i| {
            ignored[i] = try allocator.dupe(u8, pat);
        }
        cfg.ignore_patterns = ignored;
    }
    
    return cfg;
}

const String = []const u8;

fn extractYamlValue(input: []const u8) []const u8 {
    var val = std.mem.trim(u8, input, " \r\t\"");
    if (val.len >= 2 and val[0] == '\'' and val[val.len - 1] == '\'') {
        val = val[1 .. val.len - 1];
    }
    return val;
}
