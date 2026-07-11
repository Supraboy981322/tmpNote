const std = @import("std");
const zh = @import("zig_http");

const PORT:u16 = 9284;

pub fn main(init:std.process.Init) !u8 {
    const log:zh.types.Log = .default;
    log.info("foo",.{});

    const addr:std.Io.net.IpAddress = try .parse("::1", PORT);
    var server:zh.Server = try .init(init.io, init.gpa, &addr, &handler, log);

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

pub fn handler(conn:*zh.types.Connection) !zh.types.HandleResult {
    const log = conn.log;

    log.request("connection", .{});

    return try conn.sendStringClosing("foo", .{ .status = .ok });
}
