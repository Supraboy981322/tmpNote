const std = @import("std");
const hlp = @import("helpers.zig");
const config = @import("conf.zig").conf;
const glob_types = @import("global_types.zig");
const web_hlp = @import("web_helpers.zig");
const c = @cImport({
    @cInclude("time.h");
});

//structs from std
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const net = std.net;
const heap = std.heap;
const http = std.http;

//structs from helpers
const log = hlp.log;

const web = @import("web_helpers.zig").web;

//types
const note_errs = glob_types.note_errs;
const ServerConn = glob_types.ServerConn;
const Note = glob_types.Note;

//print to stdout (defaulting to stderr is stupid)
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

const globAlloc = glob_types.alloc;

//database
var db = std.StringHashMap(Note).init(globAlloc);

pub fn main() !void {
    glob_types.conf = config.read(globAlloc) catch unreachable;
    const conf = glob_types.conf;
    defer db.deinit();

    //get server addr
    const addr = net.Address.resolveIp("::", conf.port) catch |e| {
        try log.errf("failed to resolve ip: {t}", .{e}); return;
    };

    //initialize server 
    var server = addr.listen(.{ .reuse_address = true }) catch |e| {
        try log.errf("failed to listen on port '{d}': {t}", .{conf.port, e});
        return;
    }; defer server.deinit();

    //log port
    try log.info("{s} is listening on port {d}", .{conf.name, conf.port});

    //wait for connections
    while (true) {
        const acc = server.accept() catch continue;
        hanConn(acc, conf) catch continue;
    }
}

//handles incoming connections
pub fn hanConn(conn: net.Server.Connection, conf:config) !void {
    defer conn.stream.close();

    //scoped allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    //get time (uses C's time lib)
    const timeStamp = c.time(null);
    const locTime = c.localtime(&timeStamp);
    //define proper HTTP spec format for time header 
    const format = "%a, %d %b %Y %H:%M:%S GMT";
    //create a buffer for time formatting 
    var time_buf:[40]u8 = undefined;
    //actually format it
    const time_len = c.strftime(&time_buf, time_buf.len, format, locTime);
    //set the current time 
    const curTime = time_buf[0..time_len];
   
    //get remote conn addr
    var remAddr:[]const u8 = undefined;
    const addrRaw = conn.address.in.sa.addr;
    remAddr = std.fmt.allocPrint(alloc, "{d}", .{addrRaw}) catch return;
    defer alloc.free(remAddr);

    //buffer to hold stream data
    var buf:[1024]u8 = undefined;
    //get stream reader and writer interfaces
    var reader = conn.stream.reader(&buf);
    var writer = conn.stream.writer(&buf);
    var http_server = http.Server.init(reader.interface(), &writer.interface);

    //get the requested page
    var req = http_server.receiveHead() catch |e| {
        try log.err("failed to receive html head {t}", .{e});
        return; //return on err (a netcat cmd could cause problems otherwise)
    };
    var itr = mem.splitAny(u8, req.head.target[1..], "?"); //remove query params
    //check the request page, defaults to "/new" if none
    const reqPage:[]const u8 = if (itr.first().len < 1) conf.default_page else blk: {
        itr.reset() ; break :blk itr.first();
    };
    const params = if (itr.next()) |p| p else ""; //set the params 

    //log the request
    try log.req(curTime, remAddr, reqPage); 

    //struct passed to handler fn
    const serverConn:ServerConn = ServerConn{
        .conn = conn,
        .req = req,
        .reqPage = reqPage,
        .reqTime = curTime,
        .params = params,
        .conf = conf,
        .len_req = 0,
        .respond_html = false,
    };

    var target = mem.tokenizeSequence(u8, reqPage, "/");
    if (target.next()) |t| if (mem.eql(u8, t, "api")) {
        if (target.next()) |t2| web_hlp.handle_api(serverConn, t2, &db) else {
            web.send_err(404, "Not Found", serverConn);
        }
    } else web_hlp.handle_web(serverConn, &db);
    req.server.out.flush() catch {};
}
