const std = @import("std");
const zh = @import("zig_http");
const DB = @import("db.zig");

pub const hlp = @import("web_helpers.zig");

const Connection:type = zh.types.Connection;
const HandleResult:type = zh.types.HandleResult;
const assert = std.debug.assert;

pub fn handle(conn:*Connection, requested_path:[]const []const u8) !HandleResult {
    assert(!std.mem.eql(u8, requested_path[0], "api"));
    try resolvePage(conn, requested_path) orelse {
        return try conn.sendStringClosing("<h1>404... (not found)", .{ .status = .not_found });
    };
    return .done(.{});
}

pub fn resolvePage(conn:*Connection, path:[]const []const u8) !?void {
    if (path.len != 1) return null;

    const Pages = enum {
        index, new,
        view,
        @"script.js",
    };

    const ContentEmbeds = enum {
        file_or_plain_text,
        is_deleted,
        server_name,
        server_info,
        note_info
    };
    _ = ContentEmbeds;

    const match = std.meta.stringToEnum(Pages, path[0]) orelse return null;
    var raw, const content_type = switch (match) {
        .index, .new => .{ @embedFile("web/new_note.html"), "text/html" },
        .view => .{ @embedFile("web/view_note.html"), "text/html" },
        .@"script.js" => .{ @embedFile("web/script.js"), "application/javascript" },
    };

    try conn.beginResponse(.ok, .fromMap(.{
        .{ "Content-Type", content_type }
    }));

    inline for ([_][]const u8{
        "<!-- style.css -->",
    }) |embed| if (std.mem.cut(u8, raw, embed)) |halves| {
        try conn.writer.interface.writeAll(halves[0]);
        const filename = embed[5..embed.len-4];
        try conn.writer.interface.writeAll(@embedFile("web/" ++ filename));
        raw = raw[halves[0].len+embed.len..];
    };

    //while (std.mem.cut(u8, raw, "<!-- ")) |halves| {
    //    defer raw = raw[std.mem.find(u8, raw, " -->").?+" -->".len..];
    //    try conn.writer.interface.writeAll(halves[0]);
    //    const stuff = std.mem.cut(u8, halves[1], " -->").?;
    //    const what = stuff[0];

    //    const content_embed = std.meta.stringToEnum(ContentEmbeds, what);
    //    const str = switch (content_embed.?) {
    //        .server_info => "{}",
    //        else => "",
    //    };
    //    try conn.writer.interface.writeAll(str);
    //}
    try conn.writer.interface.writeAll(raw);
    try conn.writer.interface.flush();
}
