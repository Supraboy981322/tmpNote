const std = @import("std");
const hlp = @import("helpers.zig");
const config = @import("conf.zig").conf;
const glob_types = @import("global_types.zig");
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

//types
const note_errs = glob_types.note_errs;
const ServerConn = glob_types.ServerConn;
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

//embeded web-ui files
const web = struct {
    var new:[]const u8 = @embedFile("web/new_note.html");
    var view:[]const u8 = @embedFile("web/view_note.html");

    //helper to send error page
    fn send_err(code:i16, stat:[]const u8, conn:ServerConn) void {
        const curTime = conn.reqTime;
        const req = conn.req;
        
        //define placeholders and replacements
        const placs = [_][]const u8 {
            "<!-- server name -->",
            "<!-- error code -->",
            "<!-- error status -->",
        }; const replacs = [_][]const u8 {
            conn.conf.name, //server name
            //status code as string
            fmt.allocPrint(globAlloc, "{d}", .{code}) catch |e| {
                log.err("failed to allocPrint() {t}", .{e}) catch {};
                return;
            },
            stat, //the err msg
        };

        //generate response page
        const err_page:[]const u8 = @embedFile("web/err.html");
        const respPage = hlp.gen_page(
            err_page, &placs, &replacs, globAlloc
        ) catch return;

        //send response
        hlp.send.headers(code, curTime, req) catch {};
        req.server.out.print("{s}", .{respPage}) catch {};
        req.server.out.flush() catch {};
    }
};


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
        try log.err("failed to recieve html head {t}", .{e});
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
    };

    //why can't I just switch on strings? 
    const vp = enum { new, view, dash, api_view, api_new, invalid };
    const page = std.meta.stringToEnum(vp, reqPage) orelse vp.invalid;
    switch (page) {
        //new note web page
        .new => {
            newNotePage(serverConn, globAlloc) catch |e| {
                try log.err("failed to serve new note page: {t}", .{e});
            };
        },

        //view note web page 
        .view => { 
            viewNotePage(serverConn, globAlloc) catch |e| {
                try log.err("failed to serve view note page {t}", .{e});
            };
        },

        .api_view => {
            const note:[]const u8 = viewNote(serverConn, globAlloc, true) catch |e| blk: {
                switch (e) {
                    note_errs.note_not_found => {
                        hlp.send.headersWithType(
                            400, curTime, req, "text/plain"
                        ) catch {};
                        break :blk "note not found";
                    },
                    else => break :blk "server error",
                }
            };
            defer req.server.out.flush() catch {};
            req.server.out.print("{s}", .{note}) catch return;
        },
        .api_new => { 
            const id:[]const u8 = newNote(serverConn, globAlloc, true) catch |e| blk: {
                if (e == note_errs.note_too_large) hlp.send.headersWithType(
                    413, curTime, req, "text/plain" 
                ) catch {};
                break :blk switch (e) {
                    note_errs.note_too_large => "note too large",
                    else => "server error",
                };
            };
            defer req.server.out.flush() catch {};
            if (id.len == 0) return;
            req.server.out.print("{s}", .{id}) catch return;
        },
        else => web.send_err(404, "not found", serverConn),
    }
    req.server.out.flush() catch {};
}

fn newNote(serverConn:ServerConn, alloc:mem.Allocator, isReq:bool) ![]const u8 {
    //get needed vals from struct
    const curTime = serverConn.reqTime;
    const req = serverConn.req;
    const conf = serverConn.conf;
    const conn = serverConn;
    var respond_html:bool = false;
    {
        var hItr = req.iterateHeaders();
        while (hItr.next()) |h| {
            if (mem.eql(u8, h.name, "err-html")) {
                respond_html = true; break;
            }
        }
    }
    var len_req:u64 = 0;
    //make sure the 'Content-Length' header isn't larger than the maximum note size
    if (req.head.content_length) |si| {
        len_req = si; if (si > conf.max_note_size) {
            const too_large_msg:[]const u8 = "note exceeds configured limit";
            if (isReq) {
                if (respond_html) web.send_err(413, too_large_msg, serverConn) else {
                    hlp.send.headersWithType(
                        413, curTime, req, "text/plain"
                    ) catch {};
                    req.server.out.print(too_large_msg, .{}) catch {};
                } return "";
            } else return note_errs.note_too_large;
        }
    } else {
        //occurs if 'Content-Length' header is missing
        if (respond_html) web.send_err(
            411, "need \"Content-Length\" header", conn
        ) else {
            hlp.send.headersWithType(
                411, curTime, req, "text/plain"
            ) catch {};
            return "need \"Content-Length\" header";
        } return "";
    }

    //placeholder for note
    var note:[]u8 = "";

    //chk each header until 'note' header
    var hItr = req.iterateHeaders();
    while (hItr.next()) |h| {
        if (mem.eql(u8, h.name, "note")) {
            note = alloc.dupe(u8, h.value) catch {
                if (respond_html) web.send_err(400, "bad note", conn) else {
                    hlp.send.headersWithType(
                        400, curTime, req, "text/plain"
                    ) catch {};
                    req.server.out.print("bad note", .{}) catch {};
                }
                return "";
            };
            break;
        }
    } if (note.len == 0) {
        const params = serverConn.params;
        var pItr = mem.splitAny(u8, params, "&");
        while (pItr.next()) |par| {
            var p = mem.splitScalar(u8, par, '=');
            while (p.next()) |k| {
                if (mem.eql(u8, k, "note")) {
                    //set note parameter's value
                    if (p.next()) |n| note = alloc.dupe(u8, n) catch |e| {
                        if (respond_html) web.send_err(500, "server err", conn) else {
                            try log.err("failed to allocate note duplication: {t}", .{e});
                            hlp.send.headersWithType(
                                500, curTime, req, "text/plain"
                            ) catch {};
                            return "failed to allocate note duplication";
                        } return "";
                    }; break;
                } _ = p.next(); //skip value
            }
        }
    } if (note.len == 0) {
        //get req connection reader
        const conn_r = &req.server.reader;

        //get req body reader
        const bod_buf:[]u8 = ""; //body buffer
        const bod_r = conn_r.bodyReader(bod_buf, http.TransferEncoding.none, len_req);
        
        //read the body
        //  (assumes 'Content-Length' header is correct, responds 500 if not)
        const bod:[]u8 = bod_r.readAlloc(alloc, len_req) catch |e| {
            if (respond_html) web.send_err(500, "failed to read request", conn) else {
                try log.err("failed to read req body: {t}", .{e});
                hlp.send.headersWithType(
                    500, curTime, req, "text/plain"
                ) catch {};
                req.server.out.print("failed to read request body", .{}) catch {};
                return "server err";
            } return "";
        }; note = bod;
    }

    //generate note id (freeing causes seg-fault)
    const id:[]u8 = hlp.ranStr(16, alloc) catch |e| {
        try log.err("failed to generate random string (hlp.ranStr()) {t}", .{e});
        if (respond_html) web.send_err(500, "server err", conn) else {
            hlp.send.headersWithType(500, curTime, req, "text/plain") catch {};
            return "server error";
        } return "";
    };

    //note struct
    const n:Note = .{
        .content = note,
        .Encrypt = false, //may add encryption later
    };

    //add the note to db
    db.put(id, n) catch |e| { //on err
        if (respond_html) web.send_err(500, "failed to store note", conn) else {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, curTime, req, "text/plain"
            ) catch {}; //ignore err
            try log.err("failed to read store note: {t}", .{e});
            return "failed to store note";
        } return "";
    };
   
    //send headers (200 OK)
    hlp.send.headers(200, curTime, req) catch {}; //ignore err

    return id;
}

fn viewNote(conn:ServerConn, alloc:mem.Allocator, isReq:bool) ![]const u8 {
    const req = conn.req;
    const curTime = conn.reqTime;
    //iterate over the query params
    const params = conn.params;
    var pItr = mem.splitAny(u8, params, "&");
    var id:[]const u8 = "";
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id") or mem.eql(u8, k, "note-id")) {
                //set id parameter
                if (p.next()) |n| {
                    id = alloc.dupe(u8, n) catch |e| {
                        try log.err("failed to allocate id duplication: {t}", .{e});
                        hlp.send.headersWithType(
                            500, curTime, req, "text/plain"
                        ) catch {};
                        return "failed to allocate id duplication";
                    };
                } else if (isReq) {
                    hlp.send.headersWithType(
                        400, curTime, req, "text/plain"
                    ) catch {};
                    return "missing id";
                } else return note_errs.no_key_found;
                break;
            } _ = p.next(); //skip value
        }
    } if (id.len == 0) { //if no id found, chk headers
        //chk each header until 'note' header
        var hItr = req.iterateHeaders();
        while (hItr.next()) |h| {
            if (mem.eql(u8, h.name, "note-id") or mem.eql(u8, h.name, "id")) {
                id = alloc.dupe(u8, h.value) catch {
                    hlp.send.headersWithType(
                        400, curTime, req, "text/plain"
                    ) catch {};
                    req.server.out.print("bad id", .{}) catch {};
                    return "";
                };
                break;
            }
        }
    } defer alloc.free(id);

    if (id.len == 0) {
        if (isReq) {
            hlp.send.headersWithType(400, curTime, req, "text/plain") catch {};
            req.server.out.print("missing note key", .{}) catch {};
            return "";
        } return note_errs.no_key_found;
    }

    //default to invalid
    var note:[]const u8 = "key not found";
    if (db.get(id)) |n| {
        //set note and delete from db
        note = n.content;
        if (!db.remove(id)) {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, conn.reqTime, conn.req, "text/plain"
            ) catch {}; //ignore err
            try log.err("failed to remove from db", .{});
            return "failed to remove from db";
        }
    } else return note_errs.note_not_found;

    //only send headers if not internal request
    if (isReq) {
        //send headers (200 OK)
        hlp.send.headers(200, conn.reqTime, conn.req) catch {}; //ignore err
    }

    return note;
}

fn newNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    //define placeholder replacements
    const placs = [_][]const u8 {
        "<!-- server name -->",
    }; const replacs = [_][]const u8 {
        conn.conf.name,
    };//generate the page
    const respPage = hlp.gen_page(
        web.new, &placs, &replacs, alloc
    ) catch |e| {
        web.send_err(500, "server err", conn);
        try log.err("failed to generate page {t}", .{e});
        return e;
    };

    //respond
    hlp.send.headers(200, conn.reqTime, conn.req) catch {};
    conn.req.server.out.print("{s}", .{respPage}) catch {};
    conn.req.server.out.flush() catch {};
}

fn viewNotePage(conn:ServerConn, alloc:mem.Allocator) !void {
    const req = conn.req;
    const curTime = conn.reqTime;

    //get the note content
    const noteR:[]const u8 = viewNote(conn, alloc, false) catch |e| switch (e) {
        note_errs.no_key_found => {
            web.send_err(400, "key not provided", conn); return;
        },
        note_errs.note_not_found => {
            web.send_err(404, "note not found", conn); return;
        },
        else => { web.send_err(500, "server error", conn); return; },
    };
    const esc_html_amper = conn.conf.escape_html_ampersand;
    const note = hlp.sanitizeHTML(noteR, alloc, esc_html_amper) catch |e| {
        try log.err("failed to sanitize html: {t}", .{e});
        web.send_err(500, "failed to sanitize html", conn);
        return e;
    }; defer alloc.free(note);


    //define placeholder replacements
    const placs = [_][]const u8 {
        "<!-- server name -->",
        "<!-- split here -->",
    }; const replacs = [_][]const u8 {
        conn.conf.name,
        note,
    };//generate the page
    const respPage = hlp.gen_page(
        web.view, &placs, &replacs, alloc
    ) catch |e| {
        web.send_err(500, "server err", conn);
        try log.err("failed to generate page: {t}", .{e});
        return e;
    };
    
    //send headers (200 OK)
    hlp.send.headers(200, curTime, req) catch {}; //continue anyways if err
    
    //send HTML body and return if err
    req.server.out.print("{s}", .{respPage}) catch return;
    req.server.out.flush() catch return;
}
