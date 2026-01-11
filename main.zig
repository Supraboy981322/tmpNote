const std = @import("std");
const hlp = @import("helpers.zig");
const cTime = @cImport(
    @cInclude("time.h")
);

//structs from std
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const net = std.net;
const heap = std.heap;
const http = std.http;

//structs from helpers
const log = hlp.log;

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

//global allocator (scoped allocation is dumb)
const globAlloc = heap.page_allocator;

//database
var db = std.StringHashMap(Note).init(globAlloc);

pub fn main() !void {
    defer db.deinit();

    //get server addr
    const addr = try net.Address.resolveIp("::", port);

    //initialize server 
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    //log port
    try log.info("listening on port {d}\n", .{port});
    try stdout.flush();

    //wait for connections
    while (true) {
        hanConn(server.accept() catch continue) catch continue;
    }
}

//handles incoming connections
pub fn hanConn(conn: net.Server.Connection) !void {
    defer conn.stream.close();

    //scoped allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    //get time (uses C's time lib)
    const timeStamp = cTime.time(null);
    const locTime = cTime.localtime(&timeStamp);
    //define proper HTTP spec format for time header 
    const format = "%a, %d %b %Y %H:%M:%S GMT";
    //create a buffer for time formatting 
    var time_buf:[40]u8 = undefined;
    //actually format it
    const time_len = cTime.strftime(&time_buf, time_buf.len, format, locTime);
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
    var req = http_server.receiveHead() catch return; //return on err (a netcat cmd could cause problems otherwise)
    var itr = mem.splitAny(u8, req.head.target[1..], "?"); //remove query params
    var reqPage:[]const u8 = itr.next().?; //get the page
    var params:[]const u8 = ""; //placeholder for params
    if (itr.peek() != null) params = itr.next().?; //set the params 
    if (std.mem.eql(u8, reqPage, "")) reqPage = "new"; //default to new note page

    //log the request
    try log.req(curTime, remAddr, reqPage); 

    //struct passed to handler fn
    const serverConn:ServerConn = ServerConn{
        .conn = conn,
        .req = req,
        .reqTime = curTime,
        .params = params,
    };

    //why can't I just switch on strings? 
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
            //403 everything else
            req.server.out.print("HTTP/1.1 403 FORBIDDEN\r\n", .{}) catch return;
            req.server.out.print("\r\n", .{}) catch return;
            req.server.out.print("403 forbidden\n", .{}) catch return;
            req.server.out.flush() catch return ;
        },
    }
}

fn newNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    _ = alloc; //may use later
    try hlp.sendHeaders(200, conn.reqTime, conn.req);
    conn.req.server.out.print("{s}", .{web.new}) catch return;
}

fn newNote(serverConn:ServerConn, alloc:mem.Allocator) ![]const u8 {
    //get needed vals from struct
    const curTime = serverConn.reqTime;
    const req = serverConn.req;

    //placeholder for note
    var note:[]u8 = "";
    //chk each header until 'note' header
    var hItr = req.iterateHeaders();
    while (hItr.next()) |h| {
        if (mem.eql(u8, h.name, "note")) {
            note = try alloc.dupe(u8, h.value); 
            break;
        }
    }

    //generate note id (freeing causes seg-fault)
    const id:[]u8 = try hlp.ranStr(16, alloc);

    //note struct
    const n:Note = .{
        .content = note,
        .Encrypt = false, //may add encryption later
    };

    //add the note to db
    db.put(id, n) catch { //on err
        //send headers (500 server err)
        hlp.sendHeaders(500, curTime, req) catch {}; //ignore err 
        return "failed to store note";
    };
   
    //send headers (200 OK)
    hlp.sendHeaders(200, curTime, req) catch {}; //ignore err

    return id;
}

fn viewNote(conn:ServerConn, alloc:mem.Allocator) ![]const u8 {
    //iterate over the headers 
    const params = conn.params;
    var pItr = mem.splitAny(u8, params, "&");
    var id:[]const u8 = "";
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id")) {
                //set id parameter
                id = try alloc.dupe(u8, p.next().?);
                break;
            } _ = p.next(); //skip value
        }
    } defer alloc.free(id);

    //default to invalid
    var note:[]const u8 = "key not found";
    if (db.get(id)) |n| {
        //set note and delete from db
        note = n.content;
        if (!db.remove(id)) {
            //send headers (500 server err)
            hlp.sendHeaders(500, conn.reqTime, conn.req) catch {}; //ignore err
            return "failed to remove from db";
        }
    }

    //send headers (200 OK)
    hlp.sendHeaders(200, conn.reqTime, conn.req) catch {}; //ignore err

    return note;
}

fn viewNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    const req = conn.req;
    const curTime = conn.reqTime;
    const respPage:[]const u8 = web.view;

    //get the note content 
    const note:[]const u8 = try viewNote(conn, alloc);

    //replace placeholder HTML comment with content
    const t:[]const u8 = "<!-- split here -->";
    const newSi = mem.replacementSize(u8, respPage, t, note);
    const newPage = try alloc.alloc(u8, newSi);
    _ = mem.replace(u8, respPage, t, note, newPage);
    defer alloc.free(newPage);

    //send headers (200 OK)
    hlp.sendHeaders(200, curTime, req) catch {}; //continue anyways if err
    
    //send HTML body and return if err
    req.server.out.print("{s}", .{newPage}) catch return;
    req.server.out.flush() catch return;
}
