const std = @import("std");
const globs = @import("global_types.zig");
const hlp = @import("helpers.zig");
const file_types = @import("file_types.zig");

const ServerConn = globs.ServerConn;
const globAlloc = globs.alloc;
const log = hlp.log;
const lazy_lw_note = hlp.lazy_lw_note;
const note_errs = globs.note_errs;

//structs from std
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const net = std.net;
const meta = std.meta;
const heap = std.heap;
const http = std.http;

//types
const Note = globs.Note;
const File = globs.File;
const LW_Note = globs.LW_Note;

//handles api requests
pub fn handle_api(
    conn:ServerConn,
    t2:[]const u8,
    db:*std.StringHashMap(Note)
) void {
    //aliases
    const curTime = conn.reqTime;
    const req = conn.req;

    //enum for page
    const p = meta.stringToEnum(
        enum { new, view, bad }, t2
    ) orelse .bad;
    switch (p) {
        .new => {
            //mk note, and get id 
            const id = newNote(conn, globAlloc, true, db) catch |e| blk: {
               switch (e) {
                    note_errs.note_too_large => {
                        hlp.send.headersWithType(
                            413, curTime, req, "text/plain" 
                        ) catch {};
                        break :blk "note too large";
                    },
                    else => break :blk "server error",
                }
            }; defer req.server.out.flush() catch {};
            //if no id, likely an already handled err
            if (id.len == 0) return;
            //respond with id
            req.server.out.print("{s}", .{id}) catch return;
        },
        .view => {
            //get the note
            const note = viewNote(conn, globAlloc, true, db) catch |e| blk: {
                switch (e) {
                    note_errs.note_not_found => {
                        hlp.send.headersWithType(
                            400, curTime, req, "text/plain"
                        ) catch {};
                        break :blk lazy_lw_note("note doesn't exist");
                    },
                    else => break :blk lazy_lw_note("server error"),
                }
            }; defer req.server.out.flush() catch {};
            //respond with note
            req.server.out.print("{s}", .{note.cont}) catch return;
        },
        .bad => web.send_err(404, "Not Found", conn),
    }
}

//determines what file to send and handles it
pub fn handle_web(
    serverConn:ServerConn,
    db:*std.StringHashMap(Note)
) void {
    //alias for requested page
    const reqPage = serverConn.reqPage;

    const page = std.meta.stringToEnum(
        enum { 
            new, view, dash, invalid, @"script.js", @"style.css",
        }, reqPage
    ) orelse .invalid;
    switch (page) {
        //new note web page
        .new => newNotePage(serverConn, globAlloc) catch |e| {
            log.err("failed to serve new note page: {t}", .{e}) catch {};
        },

        //view note web page 
        .view => viewNotePage(serverConn, globAlloc, db) catch |e| {
            log.err("failed to serve view note page {t}", .{e}) catch {};
        },

        //shared js for web
        .@"script.js" => generic_serve( 
            serverConn, "text/javascript", web.script
        ) catch |e| {
            log.err("failed to serve generic page {t}", .{e}) catch {};
        },

        //shared stylesheet for web
        .@"style.css" => generic_serve(
            serverConn, "text/css", web.style
        ) catch |e| {
            log.err("failed to serve generic page {t}", .{e}) catch {};
        },

        else => web.send_err(404, "not found", serverConn),
    }
}

//generic helper to serve byte slice
fn generic_serve(
    conn:ServerConn,
    typ:[]const u8,
    content:[]const u8,
) !void {
    hlp.send.headersWithType(200, conn.reqTime, conn.req, typ) catch {};
    conn.req.server.out.print("{s}", .{content}) catch {};
    conn.req.server.out.flush() catch {};
}

//api for new note
fn newNote(
    serverConn:ServerConn,
    alloc:mem.Allocator,
    isReq:bool,
    db:*std.StringHashMap(Note)
) ![]const u8 {
    //get needed vals from struct
    const curTime = serverConn.reqTime;
    const req = serverConn.req;
    const conf = serverConn.conf;
    const conn = serverConn;

    //iterate over headers
    var is_file, var respond_html = .{ false, false, };
    var note:[]u8 = "";
    {   //scoped so I don't have to worry about var names clobbering 
        var hItr = req.iterateHeaders();
        while (hItr.next()) |h_C| {
            const h = meta.stringToEnum(enum {
                @"is-file", @"err-html", note, skip
            }, h_C.name) orelse .skip;
            switch (h) {
                .@"err-html" => respond_html = true,
                .@"is-file" => is_file = true,
                .note => note = alloc.dupe(u8, h_C.value) catch {
                    if (respond_html) web.send_err(400, "bad note", conn) else {
                        hlp.send.headersWithType(
                            400, curTime, req, "text/plain"
                        ) catch {};
                        req.server.out.print("bad note", .{}) catch {};
                    } return "";
                },
                .skip => continue,
            }
        }
    }
    const file_type = hlp.chk_file_type(
        if (note.len > 100) note[0..100] else note
    );

    var len_req:u64 = 0; //placeholder
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
    } else if (respond_html) {
        web.send_err(
            411, "need \"Content-Length\" header", conn
        ); return "";
    } else {
        hlp.send.headersWithType(
            411, curTime, req, "text/plain"
        ) catch {}; return "need \"Content-Length\" header";
    }

    const new_conn = ServerConn{
        .conn = conn.conn,
        .req = conn.req,
        .reqPage = conn.reqPage,
        .reqTime = conn.reqTime,
        .params = conn.params,
        .conf = conn.conf,
        .len_req = len_req,
        .respond_html = respond_html,
    };

    //combine err possible err types into one
    const combined_err_typ = mem.Allocator.Error || std.io.Reader.ReadAllocError;
    //array of fns that chk places for note 
    const fns = [2]*const fn(
        mem.Allocator, ServerConn, []const u8
    ) combined_err_typ![]u8{ get_params, read_body, };
    //iterate through fns
    for (fns) |f| {
        if (note.len == 0) note = f(alloc, new_conn, "note") catch |e| {
            try log.err("{t}", .{e}); continue;
        } else break;
    }

    //generate note id (freeing causes seg-fault)
    const id:[]u8 = hlp.ranStr(16, alloc) catch |e| {
        try log.err("failed to generate random string (hlp.ranStr()) {t}", .{e});
        if (respond_html) web.send_err(500, "server err", new_conn) else {
            hlp.send.headersWithType(
                500, curTime, req, "text/plain"
            ) catch {}; return "server error";
        } return "";
    };

    const file:File = .{
        .is_file = is_file,
        .typ = file_type.typ,
        .size = note.len,
    };

    //note struct
    const n:Note = .{
        .content = note,
        .file = file,
        .encrypt = false, //may add encryption later
    };

    //add the note to db
    db.put(id, n) catch |e| { //on err
        if (respond_html) web.send_err(500, "failed to store note", new_conn) else {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, curTime, req, "text/plain"
            ) catch {}; //ignore err
            try log.err("failed to read store note: {t}", .{e});
            return "failed to store note";
        } return "";
    };
   
    //send headers (200 OK)
    hlp.send.headersWithType(
        200, curTime, req, "text/plain"
    ) catch {}; //ignore err

    return id;
}

//api for new note
fn viewNote(
    conn:ServerConn,
    alloc:mem.Allocator,
    isReq:bool,
    db:*std.StringHashMap(Note)
) !LW_Note {
    //pull things from conn struct
    const req = conn.req;
    const curTime = conn.reqTime;
    const params = conn.params;

    //TODO: switch to new helper fn
    //iterate over the query params
    var pItr = mem.splitAny(u8, params, "&");
    var id:[]const u8 = ""; //placeholder
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            if (mem.eql(u8, k, "id") or mem.eql(u8, k, "note-id")) {
                //set id parameter
                if (p.next()) |n| {
                    //duplicate mem for value (seg-faults when viewed otherwise)
                    id = alloc.dupe(u8, n) catch |e| {
                        try log.err("failed to allocate id duplication: {t}", .{e});
                        hlp.send.headersWithType(
                            500, curTime, req, "text/plain"
                        ) catch {};
                        return lazy_lw_note("failed to allocate id duplication");
                    };
                } else if (isReq) {
                    hlp.send.headersWithType(
                        400, curTime, req, "text/plain"
                    ) catch {};
                    return lazy_lw_note("missing id");
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
                    return lazy_lw_note("");
                };
                break;
            }
        }
    } defer alloc.free(id);

    if (id.len == 0) {
        if (isReq) {
            hlp.send.headersWithType(400, curTime, req, "text/plain") catch {};
    req.server.out.print("missing note key", .{}) catch {};
            return lazy_lw_note("");
        } return note_errs.no_key_found;
    }

    //default to invalid
    var file:File = .{
        .typ = "unknown",
        .is_file = false,
        .size = 0, //might do this at some point
    };
    var note:[]const u8 = "key not found";
    if (db.get(id)) |n| {
        //set note and delete from db
        note = n.content;
        file.typ = if (n.file.is_file) n.file.typ else "text/plain";
        file.is_file = n.file.is_file;
        file.size = n.file.size;
        if (!db.remove(id)) {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, conn.reqTime, conn.req, "text/plain"
            ) catch {}; //ignore err
            try log.err("failed to remove from db", .{});
            return lazy_lw_note("failed to remove from db");
        }
    } else return note_errs.note_not_found;

    //passed to light-weight note struct
    const size = note.len;
    const conf_prev_size:usize = conn.conf.preview_size;
    const prev_si = if (size < conf_prev_size) size else conf_prev_size;
    const prev_R = note[0..prev_si];

    //only send headers if not internal request
    if (isReq) {
        //send headers (200 OK)
        hlp.send.headersWithType(
            200, conn.reqTime, conn.req, file.typ
        ) catch {}; //ignore err
    } else if (file.is_file) note = ""; //save on the amount of data being moved around
 
    const is_text = mem.eql(u8, file.typ, "text/plain");
    const prev = if (!is_text) "" else blk: {
        var prev_buf:[500]u8 = undefined;
        var prev_stream = std.io.fixedBufferStream(&prev_buf);
        var prev_wr = prev_stream.writer().adaptToNewApi(&prev_buf).new_interface;
        std.zig.stringEscape(prev_R, &prev_wr) catch |e| {
            log.err("failed to escape JSON string: {t}", .{e}) catch {};
            return lazy_lw_note("failed to generate preview");
        };
        break :blk fmt.allocPrint(
            alloc, "{s}", .{prev_wr.buffer[0..prev_wr.end]}
        ) catch "failed to generate preview"; 
    };
    
    const lw_note:LW_Note = .{
        .size = file.size,
        .cont = note,
        .is_file = file.is_file,
        .typ = file.typ,
        .prev = if (is_text) prev else "can't generate preview",
    };

    return lw_note;
}

//web page for new note (not much goes on here)
fn newNotePage(
    conn:ServerConn,
    alloc:mem.Allocator,
) !void {
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

//web page for view note 
fn viewNotePage(
    conn:ServerConn,
    alloc:mem.Allocator,
    db:*std.StringHashMap(Note)
) !void {
    const req = conn.req;
    const curTime = conn.reqTime;

    //get the note content
    const note_lw:LW_Note = viewNote(conn, alloc, false, db) catch |e| switch (e) {
        note_errs.no_key_found => {
            web.send_err(400, "key not provided", conn); return;
        },
        note_errs.note_not_found => {
            web.send_err(404, "note not found", conn); return;
        },
        else => { web.send_err(500, "server error", conn); return; },
    };
    const noteR:[]const u8 = note_lw.cont;
    //whether or not to escape ampersand
    const esc_html_amper = conn.conf.escape_html_ampersand;
    //escape html in note
    const note = hlp.sanitizeHTML(noteR, alloc, esc_html_amper) catch |e| {
        try log.err("failed to sanitize html: {t}", .{e});
        web.send_err(500, "failed to sanitize html", conn);
        return e;
    }; defer alloc.free(note); 


    //define placeholder replacements
    const placs = [_][]const u8 {
        "<!-- server name -->",
        "<!-- note info -->",
        "<!-- file or plain-text -->",
        "<!-- split here -->",
    }; const replacs = [_][]const u8 {
        conn.conf.name,
        generate_server_info(alloc, conn, note_lw),
        if (note_lw.is_file) blk: {
            break :blk "<div id=\"file\"></div>";
        } else "<pre id=\"note\"><!-- split here --></pre>",
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

//embeded web-ui files
pub const web = struct {
    var new:[]const u8 = @embedFile("web/new_note.html");
    var view:[]const u8 = @embedFile("web/view_note.html");
    var script:[]const u8 = @embedFile("web/script.js");
    var style:[]const u8 = @embedFile("web/style.css");

    //helper to send error page
    pub fn send_err(code:i16, stat:[]const u8, conn:ServerConn) void {
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

fn get_params(
    alloc: mem.Allocator,
    serverConn:ServerConn,
    which:[]const u8
) mem.Allocator.Error![]u8 {
    //read the params 
    const params = serverConn.params;
    var pItr = mem.splitAny(u8, params, "&");
    while (pItr.next()) |par| {
        var p = mem.splitScalar(u8, par, '=');
        while (p.next()) |k| {
            //get just the target value
            if (mem.eql(u8, k, which)) {
                //set note parameter's value
                if (p.next()) |n| return try alloc.dupe(u8, n);
            } _ = p.next(); //skip value
        }
    }
    
    //default to empty
    return "";
}

fn read_body(
    alloc: mem.Allocator,
    conn: ServerConn,
    which:[]const u8
) ![]u8 {
    _ = which;
    //get req connection reader and req length
    const req = conn.req;
    const conn_r = &req.server.reader;
    const len_req = conn.len_req;
    const respond_html = conn.respond_html;

    //get req body reader
    const bod_buf:[]u8 = ""; //body buffer
    const bod_r = conn_r.bodyReader(bod_buf, http.TransferEncoding.none, len_req);
    
    //read the body
    //  (assumes 'Content-Length' header is correct, responds 500 if not)
    const bod:[]u8 = bod_r.readAlloc(alloc, len_req) catch |e| {
        //respond with either html or plain text
        if (respond_html) web.send_err(500, "failed to read request", conn) else {
            log.err("failed to read req body: {t}", .{e}) catch {};
            hlp.send.headersWithType(
                500, conn.reqTime, req, "text/plain"
            ) catch {};
            req.server.out.print("failed to read request body", .{}) catch {};
            return alloc.dupe(u8, "server err");
        } return e;
    };

    return bod;
}

fn generate_server_info(
    alloc:mem.Allocator,
    conn:ServerConn,
    lw_note:LW_Note
) []const u8 {
    _ = conn; //might need this at some point
    var res:[]const u8 = "";
    const lines = [_][]const u8 {
        "{",
        fmt.allocPrint(alloc, "\t\"note_size\": {d},", .{lw_note.size}) catch blk: {
            break :blk "\t\"note_size\": null";
        },
        fmt.allocPrint(alloc, "\t\"is_file\": {},", .{lw_note.is_file}) catch blk: {
            break :blk "\t\"is_file\": false";
        },
        fmt.allocPrint(alloc, "\t\"file_type\": \"{s}\",", .{lw_note.typ}) catch blk: {
            break :blk "\t\"file_type\": \"text/plain\",";
        },
        fmt.allocPrint(alloc, "\t\"prev\": \"{s}\"", .{lw_note.prev}) catch blk: {
            break :blk "\t\"prev\": null";
        },
        "}",
    };
    for (lines) |l| res = fmt.allocPrint(alloc, "{s}{s}\n", .{res, l}) catch |e| {
        log.err("failed to generate note info: {t}", .{e}) catch {};
        return res;
    };
    return res;
}
