//imports
const std = @import("std");
const config = @import("conf.zig").conf;
pub const compress = @cImport(@cInclude("compress.h"));

//config (imported by a few scripts and set at startup)
pub var conf:config = undefined;

//global allocator (scoped allocation is dumb)
pub const alloc = std.heap.page_allocator;

//used by more than one file
pub const note_errs = error {
    zero_len,
    no_key_found,
    note_not_found,
    note_too_large,
    invalid_escape,
};

pub const Encoding = struct {
    accepts: ?[][]const u8,
    picked: compression,
};

//struct with various information used as fn params
pub const ServerConn = struct {
    conn: std.net.Server.Connection,
    encoding: *Encoding,
    req: std.http.Server.Request,
    reqPage: []const u8,
    reqTime: []u8,
    params: []const u8,
    conf: config,
    len_req: u64,
    respond_html: bool,
};

pub const server_errs = error {
    UnknownType,
    FailedToCompress, 
};

//log level
pub const log_lvl = enum {
    @"0", @"1", @"2", @"3", @"4", //so the config can just have a number 
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
    compression: compression,
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

pub const compression = enum {
    br, brotli,
    gzip,
    none,
    unknown,
};

pub const compression_preference = [_]compression {
    .gzip,
    .br, .brotli,
    .none, //shouldn't be grabbed, but here just in case 
};
