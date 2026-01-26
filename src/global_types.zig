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
    typ: []const u8,
    is_file: bool,
    magic: Magic,
    size: usize,
};

pub const Note = struct {
    content: []u8,
    file: File,
    encrypt: bool, //might do this at some point
};

pub const LW_Note = struct {
    is_file: bool,
    size: usize,
    id:[]const u8,
    typ: []const u8,
    cont: []const u8,
    prev: []const u8,
    magic: Magic,
};

pub const Magic = struct {
    raw: []const u8,
    desc: []const u8,
    class: []const u8,
};

pub const File_Type = struct {
    is_text: bool,
    is_file: bool,
    magic: Magic,
    typ: []const u8,
};

pub const log_fmt = enum {
    txt,
    json,
    invalid,
};
