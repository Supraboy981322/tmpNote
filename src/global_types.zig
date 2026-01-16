const std = @import("std");
const config = @import("conf.zig").conf;

pub var conf:config = undefined;

//global allocator (scoped allocation is dumb)
pub const alloc = std.heap.page_allocator;

pub const note_errs = error {
    no_key_found,
    note_not_found,
    note_too_large,
    invalid_escape,
};

pub const ServerConn = struct {
    conn: std.net.Server.Connection,
    req: std.http.Server.Request,
    reqPage: []const u8,
    reqTime: []u8,
    params: []const u8,
    conf: config,
};

pub const log_lvl = enum {
    debug,
    info,
    req,
    warn,
    err,
    bad, //invalid
};

pub const Note = struct {
    content: []u8,
    is_file: bool,
    encrypt: bool, //might do this at some point
};
