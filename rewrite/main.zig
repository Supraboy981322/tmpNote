const std = @import("std");
const zh = @import("zig_http");
const web = @import("web.zig");
const DB = @import("db.zig");
const types = @import("types.zig");
const api = @import("api.zig");
const State = @import("state.zig");

const PORT:u16 = 9284;

const HandleResult:type = zh.types.HandleResult;
const Connection:type = zh.types.Connection;
const assert = std.debug.assert;

pub fn main(init:std.process.Init) !u8 {
    const log:zh.types.Log = .default;
    log.info("foo",.{});

    var key:[32]u8 = undefined;
    try init.io.randomSecure(&key);

    const db:DB = try .init(init.gpa);

    var state:State = try .init(.{}, db, key);
    defer state.deinit(init.io);

    const addr:std.Io.net.IpAddress = try .parse("::1", PORT);
    var server:zh.Server = try .init(init.io, init.gpa, &addr, &handler, log, &state);

    switch (server.listen()) {
        .ok => |why| std.log.info(
            "server stopped with reason: {t}", .{why}
        ),
        .err => |err| std.log.err(
            "server stopped with error ({t}): {s}",
            .{ err.err, err.msg orelse "[no message]"}
        ),
        .fatal => |info| std.debug.panic(
            "server halted fatally ({t}): {?s}",
            .{info.err, info.msg}
        ),
    }

    return 0;
}

pub fn handler(conn:*Connection) !HandleResult {
    const log = conn.log;

    log.request("connection", .{});

    if (try web.hlp.handleBots(conn)) |handled| return handled;

    const page = try conn.tokenizePage();
    if (page) |path| {
        if (std.mem.eql(u8, path[0], "api"))
            return try api.handle(conn, path);
    }

    return try web.handle(conn, page orelse &.{"index"});
}



test " " {
    _ = State;
    _ = web;
    _ = types;
    _= DB;
    _ = @import("helpers.zig");
    _ = @import("web_helpers.zig");
    _ = @import("api.zig");
}
