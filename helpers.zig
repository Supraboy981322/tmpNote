const std = @import("std");

const crypto = std.crypto;
const http = std.http;
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;

pub fn sendHeaders(status:i16, curTime: []u8, req:http.Server.Request) !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const dateHeader = try fmt.allocPrint(alloc, "date: {s}", .{curTime});
    defer alloc.free(dateHeader);

    const headers = [_][]const u8 {
        switch (status) {
            400 => "HTTP/1.1 400 Bad Request",
            200 => "HTTP/1.1 200 OK",
            403 => "HTTP/1.1 403 FORBIDDEN",
            404 => "HTTP/1.1 404 not found",
            else => "HTTP/1.1 500 Internal Server Error",
        },
        "Content-Type: text/html",
        "x-content-type-options: nosniff", 
        "server: homebrew zig http server",
        dateHeader,
        ""
    };

    for (headers) |h| {
        req.server.out.print("{s}\r\n", .{h}) catch return;
        req.server.out.flush() catch return;
    }
}

pub fn ranStr(len:usize, alloc: mem.Allocator) ![]u8 {
    const chars:[]const u8 = "qwertyuioplkjhgfdsazxcvbnmQWERTYUIOPKLJHGFDSAZXCVBNM1234567890";

    var pran = crypto.random;
    const buf = try alloc.alloc(u8, len);
    for (buf) |*byte| {
        const i = pran.intRangeAtMost(usize, 0, chars.len-1);
        byte.* = chars[i];
    }

    return buf;
}
