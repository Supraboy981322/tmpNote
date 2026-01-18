//imports
const std = @import("std");
const glob_types = @import("global_types.zig");

//structs from std
const crypto = std.crypto;
const http = std.http;
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;

//structs other imports
const ServerConn = glob_types.ServerConn;
const note_errs = glob_types.note_errs;
const LW_Note = glob_types.LW_Note;
const Mime = glob_types.Mime;

//defaulting to stderr is stupid 
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

pub const send = struct {

    const Self = @This();

    //helper to send headers with default type ("text/html") 
    pub fn headers(
        status:i16,
        curTime: []u8,
        req:http.Server.Request
    ) !void { try Self.headersWithType(status, curTime, req, null); }

    //send headers
    pub fn headersWithType(
        status:i16,
        curTime: []u8,
        req:http.Server.Request,
        content_type:?[]const u8 //optional, null for "text/html"
    ) !void {
        //scoped allocator
        var gpa = heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const alloc = gpa.allocator();

        //array of headers
        const heads = [_][]const u8 {
            switch (status) {
                200 => "HTTP/1.1 200 OK",
                400 => "HTTP/1.1 400 Bad Request",
                403 => "HTTP/1.1 403 FORBIDDEN",
                404 => "HTTP/1.1 404 not found",
                411 => "HTTP/1.1 411 Length Required",
                413 => "HTTP/1.1 413 Content Too Large",
                else => "HTTP/1.1 500 Internal Server Error",
            },
            fmt.allocPrint(
                alloc, "Content-Type: {s}",
                .{content_type orelse "text/html"}
            ) catch |e| blk: { //just use text/html if alloc fails
                try log.err("failed to allocate 'Content-Type' header: {t}", .{e});
                break :blk "Content-Type: text/html";
            },
            "x-content-type-options: nosniff",
            "server: homebrew zig http server",
            fmt.allocPrint(alloc, "date: {s}", .{curTime}) catch |e| blk: {
                try log.err("failed to allocate 'date' header: {t}", .{e});
                break :blk "foo-bar-baz: foo bar baz"; //jargon if err
            },
            ""
        }; defer for ([_]usize{ 1, 4, }) |i| alloc.free(heads[i]); //only free alloc

        //send headers
        for (heads) |h| {
            req.server.out.print("{s}\r\n", .{h}) catch return;
            req.server.out.flush() catch return;
        }
    }
};

pub fn ranStr(len:usize, alloc: mem.Allocator) ![]u8 {
    //byte slice of alpha-numeric characters 
    const chars:[]const u8 = "qwertyuioplkjhgfdsazxcvbnmQWERTYUIOPKLJHGFDSAZXCVBNM1234567890";

    //alias for random
    var p_ran = crypto.random;

    //allocate a buffer
    const buf = alloc.alloc(u8, len) catch |e| {
        try log.err("failed to allocate ranStr(len = {d}) buffer: {t}", .{len, e});
        return e;
    };
    //fill buffer with random characters
    for (buf) |*byte| {
        const i = p_ran.intRangeAtMost(usize, 0, chars.len-1);
        byte.* = chars[i];
    }

    //return the buffer
    return buf;
}

pub const log = struct {

    const Self = @This();

    //generic logger
    pub fn generic(
        comptime tag:[]const u8,
        comptime msg:[]const u8,
        args:anytype
    ) !void {
        try stdout.print(tag++" "++msg++"\n", args);
        try stdout.flush();
    }

    //helper for formatted request
    pub fn req(
        curTime:[]const u8,
        remAddr:[]const u8,
        reqPage: []const u8
    ) !void {
        try Self.generic(
            "\x1b[1;37m[\x1b[1;33mreq\x1b[1;37m]:\x1b[0m",
            blk: { //message with a few fields
                break :blk 
                    "\x1b[1;35maddr\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;34mpage\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;36mdate\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m";
            },
            .{remAddr, reqPage, curTime}
        );
    }

    //debug logger
    pub fn deb(comptime msg:[]const u8, args:anytype) !void {
        //only log if debug (TODO: other log levels)
        if (glob_types.conf.log_level == 0) try Self.generic(
            "\x1b[1;37m[\x1b[1;34mdebug\x1b[1;37m]:\x1b[0m", msg, args
        );
    }

    //err logger
    pub fn err(comptime msg:[]const u8, args:anytype) !void {
        try Self.generic("\x1b[1;37m[\x1b[1;31merr\x1b[1;37m]:\x1b[0m", msg, args);
    }

    //err and exit
    pub fn errf(comptime msg:[]const u8, args:anytype) !void {
        try log.err(msg, args);
        std.process.exit(1);
    }

    //info logger
    pub fn info(comptime msg:[]const u8, args:anytype) !void {
        try Self.generic("\x1b[1;37m[\x1b[1;35minfo\x1b[1;37m]:\x1b[0m", msg, args);
    }
};

//escape html special characters in web ui
pub fn sanitizeHTML(
    og:[]const u8,
    alloc:mem.Allocator,
    escapeAmper:bool
) ![]const u8 {
    //bad chars
    const bad = [_][]const u8{ "<", ">", "&", "\"", "'" };
    //start with original
    var new_note:[]const u8 = og;
    //replace each instance of each bad char
    for (0.., bad) |i, char| {
        //set replacement char
        const reChar:[]const u8 = switch (i) {
            0 => "&lt;",
            1 => "&gt;",
            2 => if (escapeAmper) "&amp;" else "&", //acceptable ternary replacement
            3 => "&quot;",
            4 => "&apos;", //single quote
            else => {
                try log.err("unknown escape: {s}", .{char});
                return note_errs.invalid_escape;
            },
        };
        //allocate new note size
        const new_si = mem.replacementSize(u8, new_note, char, reChar);
        const tmp_note = alloc.alloc(u8, new_si) catch |e| {
            try log.err("failed to allocate buffer for escaped note: {t}", .{e});
            return e;
        };
        //replace all instances of char
        _ = mem.replace(u8, new_note, char, reChar, tmp_note);
        new_note = tmp_note; //replace note
    }
 
    return new_note;
}

//helper to replace placeholder comments
pub fn gen_page(
    og:[]const u8,
    placeholders:[]const []const u8,
    replacements:[]const []const u8,
    alloc:mem.Allocator
) ![]const u8 {
    //start with original page
    var respPage:[]const u8 = og;
    //iterate through each placeholder
    for (0.., placeholders) |i, plac| {
        //set the thing to replace with
        const replac_with = replacements[i];

        //calculate in-between page size
        const na_replac_si = mem.replacementSize(
            u8, respPage, plac, replac_with
        );

        //allocate in-between page
        const between = alloc.alloc(u8, na_replac_si) catch |e| {
            try log.err("failed to allocate replacement size: {t}", .{e});
//            send.headersWithType(500, curTime, req, "text/plain") catch {};
            return e;
        };

        //replace placeholders 
        _ = mem.replace(u8, respPage, plac, replac_with, between);
        //replace response page with in-between
        respPage = between;

    }

    return respPage;
}

pub fn lazy_lw_note(msg:[]const u8) LW_Note {
    return LW_Note{
        .cont = msg, 
        .is_file = false,
        .mime = "text/error",
        .size = msg.len,
        .prev = msg,
    };
}

fn chk_mime_all(b_s:[]const u8) []const u8 {
    if (b_s.len == 16) {
        if (mem.eql(u8, b_s, "SQLite format 3\x00")) {
            return "SQLite format 3";
        }
    }
    switch (b_s.len) {
        0 => return "",

        1 => return "",

        2 => return switch (std.meta.stringToEnum(
            enum {
                BM, MZ, unknown
            }, b_s
        ) orelse .unknown){
            .BM => "BMP",
            .MZ => "Windows Executable",
            .unknown => "",
        },

        3 => return "",

        4 => return switch (std.meta.stringToEnum(
            enum {
                @"\x89PNG", @"\x7fELF", @"\xff\xd8\xff\xfe0", @"%PDF",
                @"\x50\x4b\x03\x04",
                unknown
            }, b_s
        ) orelse .unknown){
            .@"%PDF" => "PDF",
            .@"\x89PNG" => "PNG",
            .@"\x7fELF" => "ELF",
            .@"\x50\x4b\x03\x04" => "zip",
            .@"\xff\xd8\xff\xfe0" => "jpeg",
            .unknown => "",
        },

        5 => return "",

        6 => return switch (std.meta.stringToEnum(
            enum {
                GIF87a, GIF89a, unknown
            }, b_s
        ) orelse .unknown) {
            .GIF87a => "GIF",
            .GIF89a => "GIF",
            .unknown => "",
        },

        else => return "",
    }
}

pub fn chk_mime(b_s:[]const u8) Mime {
    var is_text:bool = true;
    for (b_s) |b| {
        if (!std.ascii.isAscii(b)) { is_text = false ; break; }
    }
    log.deb("is_text == {}", .{is_text}) catch {};
    var mime:[]const u8 = if (is_text) "text/plain" else "";
    for (0..10) |i| {
        if (mime.len > 0) break;
        if (b_s.len <= i) return Mime{ .is_text = false, .mime = "unknown" };
        mime = chk_mime_all(b_s[0..i]);
    }
    log.deb("{s}", .{mime}) catch {};
    return Mime{
        .is_text = true,
        .mime = mime
    };
}
