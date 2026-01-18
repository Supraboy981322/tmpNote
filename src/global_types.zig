//imports
const std = @import("std");
const config = @import("conf.zig").conf;

//config (imported by a few scripts and set at startup)
pub var conf:config = undefined;

//global allocator (scoped allocation is dumb)
pub const alloc = std.heap.page_allocator;

//used by more than one file
pub const note_errs = error {
    no_key_found,
    note_not_found,
    note_too_large,
    invalid_escape,
};

//struct with various information used as fn params
pub const ServerConn = struct {
    conn: std.net.Server.Connection,
    req: std.http.Server.Request,
    reqPage: []const u8,
    reqTime: []u8,
    params: []const u8,
    conf: config,
    len_req: u64,
    respond_html: bool,
};

//log level
pub const log_lvl = enum {
    debug,
    info,
    req,
    warn,
    err,
    bad, //invalid
};

pub const File = struct {
    mime: []const u8,
    is_file: bool,
    size: usize, //might do this at some point
};

pub const Note = struct {
    content: []u8,
    file: File, //TODO: files
    encrypt: bool, //might do this at some point
};

pub const LW_Note = struct {
    is_file: bool,
    size: usize,
    mime: []const u8,
    cont: []const u8,
    prev: []const u8,
};

pub const Mime = struct {
    is_text: bool,
    mime: []const u8,
};
