const std = @import("std");

const crypto = std.crypto;
const http = std.http;
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;

const glob_types = @import("global_types.zig");
const ServerConn = glob_types.ServerConn;
const note_errs = glob_types.note_errs;

var stdout_buf:[1024]u8 = undefined;
var stdout_wr = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

pub const send = struct {

    const Self = @This();

    pub fn headers(
        status:i16,
        curTime: []u8,
        req:http.Server.Request
    ) !void {
        try Self.headersWithType(status, curTime, req, null);
    }

    pub fn headersWithType(
        status:i16,
        curTime: []u8,
        req:http.Server.Request,
        content_type:?[]const u8
    ) !void {
        var gpa = heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const alloc = gpa.allocator();

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
            ) catch |e| blk: {
                try log.err("failed to allocate 'Content-Type' header: {t}", .{e});
                break :blk "Content-Type: text/html";
            },
            "x-content-type-options: nosniff", 
            "server: homebrew zig http server",
            fmt.allocPrint(alloc, "date: {s}", .{curTime}) catch |e| blk: {
                try log.err("failed to allocate 'date' header: {t}", .{e});
                break :blk "foo-bar-baz: foo bar baz";
            },
            ""
        }; defer for ([_]usize{ 1, 4, }) |i| alloc.free(heads[i]);

        for (heads) |h| {
            req.server.out.print("{s}\r\n", .{h}) catch return;
            req.server.out.flush() catch return;
        } 
    }
};

pub fn ranStr(len:usize, alloc: mem.Allocator) ![]u8 {
    const chars:[]const u8 = "qwertyuioplkjhgfdsazxcvbnmQWERTYUIOPKLJHGFDSAZXCVBNM1234567890";

    var pran = crypto.random;
    const buf = alloc.alloc(u8, len) catch |e| {
        try log.err("failed to allocate ranStr(len = {d}) buffer: {t}", .{len, e});
        return e;
    };
    for (buf) |*byte| {
        const i = pran.intRangeAtMost(usize, 0, chars.len-1);
        byte.* = chars[i];
    }

    return buf;
}

pub const log = struct {
    const Self = @This();

    pub fn req(
        curTime:[]const u8,
        remAddr:[]const u8,
        reqPage: []const u8
    ) !void {
        try Self.generic(
            "\x1b[1;37m[\x1b[1;33mreq\x1b[1;37m]:\x1b[0m",
            blk: {
                break :blk 
                    "\x1b[1;35maddr\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;34mpage\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;36mdate\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m";
            },
            .{remAddr, reqPage, curTime}
        );
    }
    pub fn generic(
        comptime tag:[]const u8,
        comptime msg:[]const u8,
        args:anytype
    ) !void {
        try stdout.print(tag++" "++msg++"\n", args);
        try stdout.flush();
    }
    pub fn deb(comptime msg:[]const u8, args:anytype) !void {
        if (glob_types.conf.log_level == 0) try Self.generic(
            "\x1b[1;37m[\x1b[1;34mdebug\x1b[1;37m]:\x1b[0m", msg, args
        );
    }
    pub fn err(comptime msg:[]const u8, args:anytype) !void {
        try Self.generic("\x1b[1;37m[\x1b[1;31merr\x1b[1;37m]:\x1b[0m", msg, args);
    }
    pub fn errf(comptime msg:[]const u8, args:anytype) !void {
        try log.err(msg, args);
        std.process.exit(1);
    }
    pub fn info(comptime msg:[]const u8, args:anytype) !void {
        try Self.generic("\x1b[1;37m[\x1b[1;35minfo\x1b[1;37m]:\x1b[0m", msg, args);
    }
};

pub fn sanitizeHTML(
    og:[]const u8,
    alloc:mem.Allocator,
    escapeAmper:bool
) ![]const u8 {
    const bad = [_][]const u8{"<", ">", "&", "\"", "'"};
    var new_note:[]const u8 = og;
    for (0.., bad) |i, char| {
        const reChar:[]const u8 = switch (i) {
            0 => "&lt;",
            1 => "&gt;",
            2 => if (escapeAmper) "&amp;" else "&",
            3 => "&quot;",
            4 => "&apos;",
            else => {
                try log.err("unknown escape: {s}", .{char});
                return note_errs.invalid_escape;
            },
        };
        const new_si = mem.replacementSize(u8, new_note, char, reChar);
        const tmp_note = alloc.alloc(u8, new_si) catch |e| {
            try log.err("failed to allocate buffer for escaped note: {t}", .{e});
            return e;
        };
        _ = mem.replace(u8, new_note, char, reChar, tmp_note);
        new_note = tmp_note;
    }

    return new_note;
}

pub fn gen_page(
    og:[]const u8,
    placeholders:[]const []const u8,
    replacements:[]const []const u8,
    alloc:mem.Allocator
) ![]const u8 {
    var respPage:[]const u8 = og;
    for (0.., placeholders) |i, plac| {
        //set the thing to replace with
        const replac_with = replacements[i];

        //calculate in-between page size
        const na_replac_si = mem.replacementSize(u8, respPage, plac, replac_with);

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
