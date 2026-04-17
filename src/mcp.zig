const std = @import("std");
const config = @import("config.zig");
const palace = @import("palace.zig");

const RpcRequest = struct {
    jsonrpc: []const u8,
    id: ?std.json.Value = null,
    method: []const u8,
    params: ?std.json.Value = null,
};

const RpcResponse = struct {
    jsonrpc: []const u8 = "2.0",
    id: std.json.Value,
    result: ?std.json.Value = null,
    error_payload: ?std.json.Value = null,
};

pub fn serve(allocator: std.mem.Allocator, cfg: *const config.Config, io: std.Io) !void {
    _ = cfg;
    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();
    
    var line_buf = std.ArrayListUnmanaged(u8).empty;
    defer line_buf.deinit(allocator);
    
    var chunk: [4096]u8 = undefined;
    
    while (true) {
        const bytes_read = stdin.readStreaming(io, &.{chunk[0..]}) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        
        try line_buf.appendSlice(allocator, chunk[0..bytes_read]);
        
        // Check for newline
        while (std.mem.indexOfScalar(u8, line_buf.items, '\n')) |nl_index| {
            const line = line_buf.items[0..nl_index];
            
            if (line.len > 0) {
                var parsed = std.json.parseFromSlice(RpcRequest, allocator, line, .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always,
                }) catch {
                    // Remove processed bytes even if parse failed
                    line_buf.replaceRangeAssumeCapacity(0, nl_index + 1, &.{});
                    continue; 
                };
                
                const req = parsed.value;
                const id = req.id orelse std.json.Value{ .null = {} };
                
                if (std.mem.eql(u8, req.method, "initialize")) {
                    const result_str =
                        \\{
                        \\  "protocolVersion": "2024-11-05",
                        \\  "capabilities": {
                        \\    "tools": {}
                        \\  },
                        \\  "serverInfo": {
                        \\    "name": "fast-mempalace",
                        \\    "version": "1.0.0"
                        \\  }
                        \\}
                    ;
                    var result_val = try std.json.parseFromSlice(std.json.Value, allocator, result_str, .{});
                    defer result_val.deinit();
                    try sendResponse(allocator, stdout, io, id, result_val.value);
                } else if (std.mem.eql(u8, req.method, "tools/list")) {
                    const tools_str = 
                        \\{
                        \\  "tools": [
                        \\    {
                        \\      "name": "fast_mempalace_search",
                        \\      "description": "Searches the AI memory palace for relevant context.",
                        \\      "inputSchema": {
                        \\        "type": "object",
                        \\        "properties": {
                        \\          "query": {"type": "string"}
                        \\        },
                        \\        "required": ["query"]
                        \\      }
                        \\    }
                        \\  ]
                        \\}
                    ;
                    var result_val = try std.json.parseFromSlice(std.json.Value, allocator, tools_str, .{});
                    defer result_val.deinit();
                    try sendResponse(allocator, stdout, io, id, result_val.value);
                } else if (std.mem.eql(u8, req.method, "tools/call")) {
                     const result_str = 
                        \\{
                        \\  "content": [
                        \\    {
                        \\      "type": "text",
                        \\      "text": "Call executed successfully natively in Zig!"
                        \\    }
                        \\  ]
                        \\}
                    ;
                    var result_val = try std.json.parseFromSlice(std.json.Value, allocator, result_str, .{});
                    defer result_val.deinit();
                    try sendResponse(allocator, stdout, io, id, result_val.value);
                }
                
                parsed.deinit();
            }
            
            // Advance buffer past the newline
            const remaining = line_buf.items.len - (nl_index + 1);
            if (remaining > 0) {
                std.mem.copyForwards(u8, line_buf.items[0..remaining], line_buf.items[nl_index + 1 ..]);
            }
            line_buf.shrinkRetainingCapacity(remaining);
        }
    }
}

fn sendResponse(allocator: std.mem.Allocator, writer: std.Io.File, io: std.Io, id: std.json.Value, result: std.json.Value) !void {
    const json_str = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = "2.0",
        .id = id,
        .result = result
    }, .{});
    defer allocator.free(json_str);
    
    var out = try allocator.alloc(u8, json_str.len + 1);
    defer allocator.free(out);
    
    @memcpy(out[0..json_str.len], json_str);
    out[json_str.len] = '\n';
    
    _ = try writer.writeStreamingAll(io, out);
}
