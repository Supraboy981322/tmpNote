const std = @import("std");
const hlp = @import("helpers.zig");
const cTime = @cImport(
    @cInclude("time.h")
);

const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const net = std.net;
const heap = std.heap;
const http = std.http;

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

const globAlloc = heap.page_allocator;
var db = std.StringHashMap(Note).init(globAlloc);

pub fn main() !void {
    defer db.deinit();
    const addr = try net.Address.resolveIp("::", port);
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    try stdout.print("listening on port {d}\n", .{port});
    try stdout.flush();

    while (true) {
        hanConn(server.accept() catch continue) catch continue;
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
   
    var remAddr:[]const u8 = undefined;
    const addrRaw = conn.address.in.sa.addr;
    remAddr = std.fmt.allocPrint(alloc, "{d}", .{addrRaw}) catch return;
    defer alloc.free(remAddr);

    var buf:[1024]u8 = undefined;
    var reader = conn.stream.reader(&buf);
    var writer = conn.stream.writer(&buf);
    var http_server = http.Server.init(reader.interface(), &writer.interface);
    var req = http_server.receiveHead() catch return;
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

    const serverConn:ServerConn = ServerConn{
        .conn = conn,
        .req = req,
        .reqTime = curTime,
        .params = params,
    };

    const vp = enum { new, view, dash, api_view, api_new, invalid };
    const page = std.meta.stringToEnum(vp, reqPage) orelse vp.invalid;
    switch (page) {
        .new => { try newNotePage(serverConn, globAlloc); },
        .view => { try viewNotePage(serverConn, globAlloc); },
        .api_view => {
            const note:[]const u8 = try viewNote(serverConn, globAlloc);
            req.server.out.print("{s}", .{note}) catch return;
            req.server.out.flush() catch return;
        },
        .api_new => { 
            const id:[]const u8 = try newNote(serverConn, globAlloc);
            req.server.out.print("{s}", .{id}) catch return;
            req.server.out.flush() catch return;
        },
        else => {
            req.server.out.print("HTTP/1.1 403 FORBIDDEN\r\n", .{}) catch return;
            req.server.out.print("\r\n", .{}) catch return;
            req.server.out.print("403 forbidden\n", .{}) catch return;
            req.server.out.flush() catch return ;
        },
    }
}

fn newNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    _ = alloc;
    try hlp.sendHeaders(200, conn.reqTime, conn.req);
    conn.req.server.out.print("{s}", .{web.new}) catch return;
}

fn newNote(serverConn:ServerConn, alloc:mem.Allocator) ![]const u8 {
    const curTime = serverConn.reqTime;
    const req = serverConn.req;

    var note:[]const u8 = "";
    var hItr = req.iterateHeaders();
    while (hItr.next()) |h| {
        if (mem.eql(u8, h.name, "note")) { note = h.value ; break; }
    }
   
    const cont:[]u8 = try alloc.dupe(u8, note);
    defer alloc.free(cont);

    const id:[]u8 = try hlp.ranStr(16, globAlloc);
    defer alloc.free(id);

    const n:Note = .{
        .content = cont,
        .Encrypt = false,
    };

    db.put(id, n) catch {
        hlp.sendHeaders(500, curTime, req) catch {};
        return "failed to store note";
    };
    
    hlp.sendHeaders(200, curTime, req) catch return id;

    try stdout.print("{s}\n", .{n.content});
    try stdout.flush();
    return try alloc.dupe(u8, id);
}

fn viewNote(conn:ServerConn, alloc:mem.Allocator) ![]const u8 {
    const params = conn.params;
    var pItr = mem.splitAny(u8, params, "&");
    var idR:[]const u8 = "";
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id")) {
                idR = try globAlloc.dupe(u8, p.next().?);
                break;
            } _ = p.next();
        }
    } defer globAlloc.free(idR);

    const id:[]u8 = try globAlloc.dupe(u8, idR);

    var note:[]const u8 = "key not found";
    if (db.get(id)) |n| {
        note = try globAlloc.dupe(u8, n.content);
        if (!db.remove(id)) {
            hlp.sendHeaders(500, conn.reqTime, conn.req) catch {};
            return "failed to remove from db";
        }
    }

    try hlp.sendHeaders(200, conn.reqTime, conn.req);
    return try alloc.dupe(u8, note);
}

fn viewNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    const curTime = conn.reqTime;
    const respPage:[]const u8 = web.view;

    const note:[]const u8 = try viewNote(conn, alloc);
    const t:[]const u8 = "<!-- split here -->";
    const newSi = mem.replacementSize(u8, respPage, t, note);
    const newPage = try alloc.alloc(u8, newSi);
    _ = mem.replace(u8, respPage, t, note, newPage);
    defer alloc.free(newPage);

    const req = conn.req;
    try hlp.sendHeaders(200, curTime, req);
    req.server.out.print("{s}", .{newPage}) catch return;
    req.server.out.flush() catch return;
}
