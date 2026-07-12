const std = @import("std");
const zh = @import("zig_http");
const DB = @import("db.zig");

pub const hlp = @import("web_helpers.zig");

const Connection:type = zh.types.Connection;
const HandleResult:type = zh.types.HandleResult;
const assert = std.debug.assert;

pub fn handle(conn:*Connection, requested_path:[]const []const u8) !HandleResult {
    assert(!std.mem.eql(u8, requested_path[0], "api"));
    const content = resolvePage(conn, requested_path) orelse {
        return try conn.sendStringClosing("<h1>404... (not found)", .{ .status = .not_found });
    };
    return try conn.sendStringClosing(content, .{});
}

pub fn resolvePage(conn:*Connection, path:[]const []const u8) ?[]const u8 {
    if (path.len != 1) return null;

    const Pages = enum {
        index, new, @"index.html", @"new.html",
        view, @"view.html",
    };

    const RuntimeEmbeds = enum {
        file_or_plain_text,
        is_deleted,
        server_name,
        server_info,
        note_info
    };
    _ = .{ conn, RuntimeEmbeds };

    const match = std.meta.stringToEnum(Pages, path[0]) orelse return null;
    const raw = switch (match) {
        inline else => |which| comptime blk: {
            @setEvalBranchQuota(100000000);
            const page = switch (which) {
                .index, .new, .@"index.html", .@"new.html" => @embedFile("web/new_note.html"),
                .view, .@"view.html" => @embedFile("web/view_note.html"),
            };
            const comptime_embeds:[]const []const u8 = &.{
                "style.css", "script.js"
            };
            var res:[]const u8 = page;
            for (comptime_embeds) |file| {
                const str = "<!-- " ++ file ++ " -->";
                const halves = std.mem.cut(u8, res, str) orelse continue;
                res = halves[0] ++ @embedFile("web/" ++ file) ++ halves[1];
            }
            break :blk res;
        }
    };
    return raw;
}
