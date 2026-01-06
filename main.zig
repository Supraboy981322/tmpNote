const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const net = std.net;
const heap = std.heap;
const http = std.http;
const cTime = @cImport(
    @cInclude("time.h")
);

//embeded web-ui files
const web = struct {
    var new:[]const u8 = @embedFile("web/new_note.html");
    var view:[]const u8 = @embedFile("web/view_note.html");
};

//types
const ServerConn = struct {
    conn: net.Server.Connection,
    req: http.Server.Request,
    reqTime: []u8,
    params: []const u8,
};
const Note = struct {
    content: []u8,
    Encrypt: bool,
};

var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

var port:u16 = 7855;
var db = std.AutoHashMap([]u8, Note).init(heap.page_allocator);

pub fn main() !void {
    const addr = try net.Address.resolveIp("::", port);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    try stdout.print("listening on port {d}\n", .{port});
    try stdout.flush();

    while (true) {
        try hanConn(try server.accept());
    }
    db.deinit();
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
    var itr = mem.splitAny(u8, req.head.target[1..], "?");
    var reqPage:[]const u8 = itr.next().?;
    var params:[]const u8 = "";
    if (itr.peek() != null) params = itr.next().?;
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
        "\x1b[1;37m}\x1b[0m",
        "\n"
    };
    for (l) |p| try stdout.print("{s}", .{p});
    try stdout.flush();
    alloc.free(remAddr);

    const serverConn:ServerConn = ServerConn{
        .conn = conn,
        .req = req,
        .reqTime = curTime,
        .params = params,
    };

    const vp = enum { new, view, dash, invalid };
    const page = std.meta.stringToEnum(vp, reqPage) orelse vp.invalid;
    switch (page) {
        .new => { try newNote(serverConn); },
        .view => { try viewNote(serverConn); },
        else => {
            try req.server.out.print("HTTP/1.1 403 FORBIDDEN\r\n", .{});
            try req.server.out.print("\r\n", .{});
            try req.server.out.print("403 forbidden\n", .{});
            try req.server.out.flush();
        },
    }
}

fn newNote(serverConn:ServerConn) !void {
    const curTime = serverConn.reqTime;
    const req = serverConn.req;
    const params = serverConn.params;
    try stdout.print("{s}", .{params});
    try stdout.flush();

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

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


    
    try req.server.out.print("{s}", .{web.new});
    try req.server.out.flush();
}

fn viewNote(serverConn:ServerConn) !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const curTime = serverConn.reqTime;
    const req = serverConn.req;
    const params = serverConn.params;
    var pItr = mem.splitAny(u8, params, "&");
    var idR:[]const u8 = "";
    while (pItr.next()) |par| {
        var p = mem.splitAny(u8, par, "=");
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id")) {
                idR = try mem.Allocator.dupe(alloc, u8, pItr.next().?);
                break;
            } _ = p.next();
        }
    }
    
    const id:[]u8 = try mem.Allocator.dupe(alloc, u8, pItr.next().?);
    const note:Note = db.get(id) orelse return;
    const val:[]u8 = note.content;
    try stdout.print("{s}", .{val});
    try stdout.flush();

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

    try req.server.out.print("{s}", .{web.view});
    try req.server.out.flush();
}
