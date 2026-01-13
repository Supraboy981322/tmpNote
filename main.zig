const std = @import("std");
const hlp = @import("helpers.zig");
const config = @import("conf.zig").conf;
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
    conf: config,
};
const Note = struct {
    content: []u8,
    Encrypt: bool, //might do this at some point
};

//print to stdout (defaulting to stderr is stupid)
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

//global allocator (scoped allocation is dumb)
const globAlloc = heap.page_allocator;

//database
var db = std.StringHashMap(Note).init(globAlloc);

pub fn main() !void {
    const conf = try config.read(globAlloc);
    defer db.deinit();

    //get server addr
    const addr = try net.Address.resolveIp("::", conf.port);

    //initialize server 
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    //log port
    try log.info("{s} is listening on port {d}", .{conf.name, conf.port});
    try stdout.flush();

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
        try log.errf("{any}", .{e});
        return; //return on err (a netcat cmd could cause problems otherwise)
    };
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
        .conf = conf,
    };

    //why can't I just switch on strings? 
    const vp = enum { new, view, dash, api_view, api_new, invalid };
    const page = std.meta.stringToEnum(vp, reqPage) orelse vp.invalid;
    switch (page) {
        //new note web page
        .new => { try newNotePage(serverConn, globAlloc); },

        //view note web page 
        .view => { try viewNotePage(serverConn, globAlloc); },

        .api_view => {
            const note:[]const u8 = try viewNote(serverConn, globAlloc, true);
            defer req.server.out.flush() catch {};
            req.server.out.print("{s}", .{note}) catch return;
        },
        .api_new => { 
            const id:[]const u8 = try newNote(serverConn, globAlloc);
            defer req.server.out.flush() catch {};
            if (mem.eql(u8, id, "")) return;
            req.server.out.print("{s}", .{id}) catch return;
        },
        else => {
            //404 everything else
            req.server.out.print("HTTP/1.1 404 Not Found\r\n", .{}) catch return;
            req.server.out.print("\r\n", .{}) catch return;
            req.server.out.print("404 not found\n", .{}) catch return;
            req.server.out.flush() catch return ;
        },
    }
    req.server.out.flush() catch {};
}

fn newNote(serverConn:ServerConn, alloc:mem.Allocator) ![]const u8 {
    //get needed vals from struct
    const curTime = serverConn.reqTime;
    const req = serverConn.req;
    const conf = serverConn.conf;

    //make sure the 'Content-Length' header isn't larger than the maximum note size
    if (req.head.content_length) |si| if (si > conf.max_note_size) {
        hlp.send.headersWithType(400, curTime, req, "text/plain") catch {};
        req.server.out.print("note exceeds configured limit", .{}) catch {};
        return "";
    };

    //placeholder for note
    var note:[]u8 = "";

    //chk each header until 'note' header
    var hItr = req.iterateHeaders();
    while (hItr.next()) |h| {
        if (mem.eql(u8, h.name, "note")) {
            note = alloc.dupe(u8, h.value) catch {
                hlp.send.headersWithType(400, curTime, req, "text/plain") catch {};
                req.server.out.print("bad note", .{}) catch {};
                return "";
            };
            break;
        }
    } if (mem.eql(u8, note, "")) {
        const len_s:?u64 = req.head.content_length;
        if (len_s) |s| {
            //get req connection reader
            const conn_r = &req.server.reader;

            //get req body reader
            const bod_buf:[]u8 = ""; //body buffer
            const bod_r = conn_r.bodyReader(bod_buf, http.TransferEncoding.none, s);
            
            //read the body
            //  (assumes 'Content-Length' header is correct, responds 500 if not)
            const bod:[]u8 = bod_r.readAlloc(alloc, s) catch |e| {
                try log.err("failed to read req body: {any}", .{e});
                hlp.send.headersWithType(500, curTime, req, "text/plain") catch {};
                req.server.out.print("failed to read request body", .{}) catch {};
                return "server err";
            };
            note = bod;
        } else {
            //occurs if 'Content-Length' header is missing
            hlp.send.headersWithType(400, curTime, req, "text/plain") catch {};
            return "need \"Content-Length\" header";
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
    db.put(id, n) catch |e| { //on err
        //send headers (500 server err)
        hlp.send.headersWithType(500, curTime, req, "text/plain") catch {}; //ignore err
        try log.err("failed to read store note: {any}", .{e});
        return "failed to store note";
    };
   
    //send headers (200 OK)
    hlp.send.headers(200, curTime, req) catch {}; //ignore err

    return id;
}

fn viewNote(conn:ServerConn, alloc:mem.Allocator, isReq:bool) ![]const u8 {
    //iterate over the headers 
    const params = conn.params;
    var pItr = mem.splitAny(u8, params, "&");
    var id:[]const u8 = "";
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id")) {
                //set id parameter
                id = alloc.dupe(u8, p.next().?) catch |e| {
                    try log.err("failed to allocate id duplication: {any}", .{e});
                    hlp.send.headersWithType(500, conn.reqTime, conn.req, "text/plain") catch {};
                    return "failed to allocate id duplication";
                };
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
            hlp.send.headersWithType(500, conn.reqTime, conn.req, "text/plain") catch {}; //ignore err
            try log.err("failed to remove from db", .{});
            return "failed to remove from db";
        }
    }

    //only send headers if not internal request
    if (isReq) {
        //send headers (200 OK)
        hlp.send.headers(200, conn.reqTime, conn.req) catch {}; //ignore err
    }

    return note;
}

fn newNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    const reqPage:[]const u8 = web.new;
    
    const na_plac:[]const u8 = "<!-- server name -->";
    const na_replac_si = mem.replacementSize(u8, reqPage, na_plac, conn.conf.name);
    const new_page = alloc.alloc(u8, na_replac_si) catch |e| {
        hlp.send.headersWithType(500, conn.reqTime, conn.req, "text/plain") catch {};
        try log.err("couldn't allocate replacement page size, {any}", .{e});
        return e;
    };
    _ = mem.replace(u8, reqPage, na_plac, conn.conf.name, new_page);

    hlp.send.headers(200, conn.reqTime, conn.req) catch {};
    conn.req.server.out.print("{s}", .{new_page}) catch return;
}

fn viewNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    const req = conn.req;
    const curTime = conn.reqTime;
    const reqPage:[]const u8 = web.view;

    //get the note content
    const noteR:[]const u8 = try viewNote(conn, alloc, false);
    const note = hlp.sanitizeHTML(noteR, alloc, conn.conf.escape_html_ampersand) catch |e| {
        hlp.send.headersWithType(500, conn.reqTime, conn.req, "text/plain") catch {};
        try log.err("failed to sanitize html: {any}", .{e});
        req.server.out.print("failed to sanitize html, aborting for security", .{}) catch {};
        return e;
    };
    defer alloc.free(note);
    
    //insert server name to HTML
    const na_plac:[]const u8 = "<!-- server name -->";
    const na_replac_si = mem.replacementSize(u8, reqPage, na_plac, conn.conf.name);
    const respPage = alloc.alloc(u8, na_replac_si) catch |e| {
        try log.err("failed to allocate replacement size: {any}", .{e});
        hlp.send.headersWithType(500, curTime, req, "text/plain") catch {};
        return e;
    };
    _ = mem.replace(u8, reqPage, na_plac, conn.conf.name, respPage);
    defer alloc.free(respPage);

    //replace placeholder HTML comment with content
    const t:[]const u8 = "<!-- split here -->";
    const newSi = mem.replacementSize(u8, respPage, t, note);
    const newPage = alloc.alloc(u8, newSi) catch |e| {
        try log.err("failed to allocate replacement size: {any}", .{e});
        hlp.send.headersWithType(500, curTime, req, "text/plain") catch {};
        return e;
    };
    _ = mem.replace(u8, respPage, t, note, newPage);
    defer alloc.free(newPage);
    
    //send headers (200 OK)
    hlp.send.headers(200, curTime, req) catch {}; //continue anyways if err
    
    //send HTML body and return if err
    req.server.out.print("{s}", .{newPage}) catch return;
    req.server.out.flush() catch return;
}
