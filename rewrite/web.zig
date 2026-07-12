const std = @import("std");
const zh = @import("zig_http");
const DB = @import("db.zig");

pub const hlp = @import("web_helpers.zig");

const Connection:type = zh.types.Connection;
const HandleResult:type = zh.types.HandleResult;
const assert = std.debug.assert;

pub fn handle(conn:*Connection, requested_path:[]const []const u8) !HandleResult {
    assert(!std.mem.eql(u8, requested_path[0], "api"));
    _ = .{ conn };
    return try conn.sendStringClosing(
        "<h1>TODO: web</h1>", .{ .status = .not_implemented }
    );
}
