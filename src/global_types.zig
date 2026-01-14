const std = @import("std");
const config = @import("conf.zig").conf;

pub const note_errs = error {
    note_not_found,
    note_too_large,
};

pub const ServerConn = struct {
    conn: std.net.Server.Connection,
    req: std.http.Server.Request,
    reqPage: []const u8,
    reqTime: []u8,
    params: []const u8,
    conf: config,
};
