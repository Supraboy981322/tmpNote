const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const net = std.net;
const http = std.http;
const cTime = @cImport(
    @cInclude("time.h")
);

const web = struct {
    var new:[]const u8 = @embedFile("web/new_note.html");
    var view:[]const u8 = @embedFile("web/view_note.html");
};

var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

var port:u16 = 7855;

pub fn main() !void {
    const addr = try net.Address.resolveIp("::", port);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    try stdout.print("listening on port {d}\n", .{port});
    try stdout.flush();

    while (true) {
        try hanConn(try server.accept());
    }
}

pub fn hanConn(conn: net.Server.Connection) !void {
    defer conn.stream.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();


    const timeStamp = cTime.time(null);
    const locTime = cTime.localtime(&timeStamp);
    const format = "%a, %d %b %Y %H:%M:%S GMT";
    var time_buf:[40]u8 = undefined;
    const time_len = cTime.strftime(&time_buf, time_buf.len, format, locTime);
    const curTime = time_buf[0..time_len];
    
    const remAddr:[]const u8 = try std.fmt.allocPrint(alloc, "{d}", .{conn.address.in.sa.addr});

    var buf:[1024]u8 = undefined;
    var reader = conn.stream.reader(&buf);
    var writer = conn.stream.writer(&buf);
    var http_server = http.Server.init(reader.interface(), &writer.interface);
    var req = try http_server.receiveHead();
    var reqPage:[]const u8 = req.head.target[1..];
    if (std.mem.eql(u8, reqPage, "")) reqPage = "new";
    const l = [_][]const u8 {
        "\x1b[1;37m[\x1b[1;33mreq\x1b[1;37m]:\x1b[0m ",
        "\x1b[1;36mdate\x1b[1;37m{\x1b[0m",
        curTime,
        "\x1b[1;37m}\x1b[0m ",
        "\x1b[1;35maddr\x1b[1;37m{\x1b[0m",
        remAddr,
        "\x1b[1;37m}\x1b[0m ",
        "\x1b[1;34mpage\x1b[1;37m{\x1b[0m",
        reqPage,
        "\x1b[1;37m}\x1b[0m"
    };
    for (l) |p| try stdout.print("{s}", .{p});
    try stdout.print("\n", .{});
    try stdout.flush();
    alloc.free(remAddr);

    switch (req.head.method) {
        .GET => {},
        else => return,
    }

    const vp = enum { new, view, dash, invalid };
    const page = std.meta.stringToEnum(vp, reqPage) orelse vp.invalid;
    switch (page) {
        .new, .view => {},
        else => {
            try req.server.out.print("HTTP/1.1 403 FORBIDDEN\r\n", .{});
            try req.server.out.print("\r\n", .{});
            try req.server.out.print("403 forbidden\n", .{});
            try req.server.out.flush();
            return;
        },
    }
    const dateHeader = try fmt.allocPrint(alloc, "date: {s}", .{curTime});
    const headers = [_][]const u8 {
        "HTTP/1.1 200 OK",
        "Content-Type: text/html",
        "x-content-type-options: nosniff", 
        "server: homebrew zig http server",
        dateHeader,
        ""
    };for (headers) |h| {
        try req.server.out.print("{s}\r\n", .{h});
        try req.server.out.flush();
    } alloc.free(dateHeader);
    
    switch (page) {
        .new => { try req.server.out.print("{s}", .{web.new}); },
        .view => { try req.server.out.print("{s}", .{web.view}); },
        else => {
            try req.server.out.print("HTTP/1.1 404 FORBIDDEN", .{});
            try req.server.out.flush();
            return;
        },
    }
    try req.server.out.flush();
}
