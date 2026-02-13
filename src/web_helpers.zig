const std = @import("std");
const globs = @import("global_types.zig");
const hlp = @import("helpers.zig");
const file_types = @import("file_types.zig");
const compress = globs.compress;

const ServerConn = globs.ServerConn;
const globAlloc = globs.alloc;
const log = hlp.log;
const lazy_lw_note = hlp.lazy_lw_note;
const note_errs = globs.note_errs;
const Json_Pair = globs.Json_Pair;

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
const File_Type = globs.File_Type;

//handles api requests
pub fn handle_api(
    conn:*ServerConn,
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
            const id = api_new(conn, globAlloc, true, db) catch |e| blk: {
               switch (e) {
                    note_errs.note_too_large => {
                        hlp.send.headersWithType(
                            413, curTime, req, null, null, "text/plain" 
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
            const note = api_view(conn, globAlloc, true, db) catch |e| blk: {
                switch (e) {
                    note_errs.note_not_found => {
                        hlp.send.headersWithType(
                            400, curTime, req, null, null, "text/plain"
                        ) catch {};
                        break :blk lazy_lw_note("note doesn't exist");
                    },
                    else => break :blk lazy_lw_note("server error"),
                }
            }; defer {
                globAlloc.free(note.id);
                req.server.out.flush() catch {};
            }
            //respond with note
            req.server.out.print("{s}", .{note.cont}) catch return;
        },
        .bad => web.send_err(404, "Not Found", conn),
    }
}

//determines what file to send and handles it
pub fn handle_web(
    serverConn:*ServerConn,
    db:*std.StringHashMap(Note)
) !void {

    try log.deb("reqPage web han", .{});

    //alias for requested page
    const reqPage = serverConn.reqPage;

    try log.deb("switch web han", .{});

    const page = std.meta.stringToEnum(
        enum { 
            new, view, dash, invalid,
        }, reqPage
    ) orelse .invalid;

    switch (page) {
        //new note web page
        .new => newNotePage(
            serverConn, globAlloc
        ) catch |e| return e,

        //view note web page 
        .view => viewNotePage(
            serverConn, globAlloc, db
        ) catch |e| return e,

        else => web.send_err(404, "not found", serverConn),
    }

    try log.deb("web_han", .{});
}

//generic helper to serve byte slice
fn generic_serve(
    conn:*ServerConn,
    typ:[]const u8,
    content:[]const u8,
) !void {
    hlp.send.headersWithType(200, conn.reqTime, conn.req, typ) catch {};
    conn.req.server.out.print("{s}", .{content}) catch {};
    conn.req.server.out.flush() catch {};
}

//api for new note
fn api_new(
    serverConn:*ServerConn,
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
    var is_file, var respond_html = .{
        false, false,
    };
    //may be set in a few places, so create as empty early
    var note:[]u8 = "";
    var comment:[]u8 = "";
    var file_name:[]u8 = "";
    {   //scoped so I don't have to worry about var names clobbering 
        var hItr = req.iterateHeaders();
        //iterate over headers
        while (hItr.next()) |h_C| {
            //create enum from header so I can 'switch'
            const h = meta.stringToEnum(enum {
                @"is-file", @"err-html", note, skip, comment,
            }, h_C.name) orelse .skip; //if not wanted, set to skip 
            //switch on header enum 
            switch (h) {
                //request wants any errors as html page
                .@"err-html" => respond_html = true,
                //request contains file
                .@"is-file" => {
                    is_file = true;
                    file_name = alloc.dupe(u8, h_C.value) catch |e| {
                        if (respond_html) web.send_err(400, "bad filename", conn) else {
                            hlp.send.headersWithType(
                                400, curTime, req, null, null, "text/plain"
                            ) catch {};
                            req.server.out.print("bad filename", .{}) catch {};
                        }
                        log.err("failed to alloc.dupe filename {t}", .{e}) catch {};
                        return "";
                    };
                },
                //request contains note in header (could be in body or url params)
                .note => note = alloc.dupe(u8, h_C.value) catch {
                    if (respond_html) web.send_err(400, "bad note", conn) else {
                        hlp.send.headersWithType(
                            400, curTime, req, null, null, "text/plain"
                        ) catch {};
                        req.server.out.print("bad note", .{}) catch {};
                    } return "";
                },
                .comment => comment = alloc.dupe(u8, h_C.value) catch |e| {
                    if (respond_html) web.send_err(500, "server err", conn) else {
                        hlp.send.headersWithType(
                            500, curTime, req, null, null, "text/plain"
                        ) catch {};
                        req.server.out.print("server err", .{}) catch {};
                    }
                    log.err("alloc note comment failed: {t}", .{e}) catch {};
                    return "";
                },
                //otherwise skip header
                .skip => continue,
            }
        }
    }

    var len_req:u64 = 0; //placeholder
    //make sure the 'Content-Length' header isn't larger than the maximum note size
    if (req.head.content_length) |si| {
        len_req = si; //just an alias 
        //if the note is too large 
        if (si > @import("conf.zig").conf.max_note_size) {
            //message that's sent
            const too_large_msg:[]const u8 = "note exceeds configured limit";
            if (isReq) { //only respond with err if it's an api request 
                //either send html err page or plain-text 
                if (respond_html) web.send_err(413, too_large_msg, serverConn) else {
                    hlp.send.headersWithType(
                        413, curTime, req, null, null, "text/plain"
                    ) catch {};
                    req.server.out.print(too_large_msg, .{}) catch {};
                } return ""; //return empty string
            //otherwise return err to calling fn
            } else return note_errs.note_too_large;
        }
    } else if (respond_html) {
        web.send_err(
            411, "need \"Content-Length\" header", conn
        ); return "";
    } else {
        hlp.send.headersWithType(
            411, curTime, req, null, null, "text/plain"
        ) catch {}; return "need \"Content-Length\" header";
    }

    //create new connection struct
    var new_conn = ServerConn{
        .conn = conn.conn,
        .encoding = conn.encoding,
        .req = conn.req,
        .reqPage = conn.reqPage,
        .reqTime = conn.reqTime,
        .params = conn.params,
        .conf = conn.conf,
        .len_req = len_req,
        .respond_html = respond_html,
    };

    //combine possible err types into one
    const combined_err_typ = mem.Allocator.Error
                    || std.io.Reader.ReadAllocError
                    || note_errs;

    //array of fns that chk places for note 
    const fns = [2]*const fn(
        mem.Allocator, *ServerConn, []const u8
    ) combined_err_typ![]u8{ get_params, read_body, };
    //iterate through array of fns (passes new connection struct)
    for (fns) |f| {
        if (note.len == 0) note = f(alloc, &new_conn, "note") catch |e| {
            //just print err if err isn't no length
            if (e != note_errs.zero_len) try log.err("{t}", .{e});
            continue; //continue either way
        } else break; //stop on first non-empty found
    }

    //generate note id (random string generator helper)
    const id:[]u8 = hlp.ranStr(16, alloc) catch |e| {
        try log.err("failed to generate random string (hlp.ranStr()) {t}", .{e});
        //either respond with html err page or plain-text
        if (respond_html) web.send_err(500, "server err", &new_conn) else {
            hlp.send.headersWithType(
                500, curTime, req, null, null, "text/plain"
            ) catch {}; return "server error";
        } return "";
    };

    //check if it's plain-text
    const is_text = hlp.chk_is_ascii(note);
    //either handle as a file or use generic struct 
    const file_type:File_Type = if (is_file) hlp.chk_magic(
        if (note.len > 100) note else note
    ) else .{ //handle if it's not plain-text and api call claimed it's not a file
        .is_text = if (is_text) true else false,
        .is_file = false,
        .magic = hlp.text_magic(),
        .typ = if (is_text) "text/plain" else "unknown",
    };

    //file info struct
    const file:File = .{
        .magic = file_type.magic,
        .is_file = is_file,
        .typ = file_type.typ,
        .size = note.len,
        .comment = comment,
        .name = file_name,
    };

    const hash, note = if (conf.notes.use_encryption) b: {
        const stuff = try hlp.do_xor(alloc, null, note, .{ .mk_hash = true });
        break :b .{ stuff.hash.?, stuff.res };
    } else .{ null, note };

    //note struct
    const n:Note = .{
        .content = if (conf.notes.compression != .none) b: {
            defer alloc.free(note);
            const n_C = compression.do(
                note, conn, null, conf.notes.compression, alloc
            ) catch |e| {
                try log.err("failed to compress note: {t}", .{e});
                return e;
            };

            break :b try alloc.dupe(u8, n_C);
        } else note,
        .file = file,
        .compression = conf.notes.compression,
        .encryption = .{
            .enabled = conf.notes.use_encryption,
            .key = hash,
        },
    };

    //log the file type (debug)
    //log.deb(
    //    "put: configured{{{s}}} found{{{s}}} length{{{d}}}",
    //    .{
    //        @tagName(n.compression),
    //        hlp.chk_magic(@constCast(n.content)).typ, 
    //        n.content.len
    //    }
    //) catch {};

    //add the note to db
    db.put(id, n) catch |e| { //on err
        //either respond html err page or plain-text
        if (respond_html) web.send_err(500, "failed to store note", &new_conn) else {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, curTime, req, null, null, "text/plain"
            ) catch {}; //ignore err
            //log err and respond with a generic err msg
            try log.err("failed to read store note: {t}", .{e});
            return "failed to store note";
        } return "";
    };
   
    //send headers (200 OK)
    hlp.send.headersWithType(
        200, curTime, req, null, null, "text/plain"
    ) catch {}; //ignore err

    return id;
}

//api for new note
fn api_view(
    conn:*ServerConn,
    alloc:mem.Allocator,
    isReq:bool,
    db:*std.StringHashMap(Note)
) !LW_Note {
    //pull things from conn struct
    const req = conn.req;
    const curTime = conn.reqTime;
    

    //check for id
    const id:[]const u8 = b: {
        //create a new connection struct with content_length
        var new_conn = conn;
        new_conn.len_req = req.head.content_length orelse conn.len_req; 

        //create a list of fns to check for id
        const fns = [_]*const fn(
            mem.Allocator, *ServerConn, []const u8
        ) anyerror![]u8 { get_params, get_header, read_body };

        //iterate over the list of fns
        for (fns) |f| for ([_][]const u8{"note-id", "id"}) |p| {
            const res = f(alloc, new_conn, p) catch |e| {
                //ignore zero length err (assumes no note later) 
                if (e == note_errs.zero_len) continue;
                //log and return all other errs
                try log.err("failed to get id: {t}", .{e});
                return e;
            }; //break with value if found 
            if (res.len != 0) break :b res;
        };

        //if 'break' not called yet, id not found
        if (isReq) { //if api req respond with plain-text err 
            hlp.send.headersWithType(
                400, curTime, req, null, null, "text/plain"
            ) catch {};
            req.server.out.print("missing note key", .{}) catch {};
            return lazy_lw_note(""); //don't return err (already handled)
        } return note_errs.no_key_found; //return missing id err
    };

    //default to invalid
    var file:File = .{
        .typ = "unknown",
        .is_file = false,
        .magic = globs.Magic{
            .class = "",
            .raw = "",
            .desc = "",
        },
        .size = 0,
        .comment = "",
        .name = "",
    };

    //default to invalid
    var note:[]const u8 = "key not found";

    //check if note exists 
    if (db.get(id)) |n| {
        //set note and delete from db
        note = if (conn.conf.notes.compression != .none) b: {
            break :b compression.undo(
                n.content, conn, null, conn.conf.notes.compression, alloc
            ) catch |e| {
                if (e == globs.server_errs.UnknownType) {
                    @panic("unknown compression type");
                }
                try log.err("failed to decompress note: {t}", .{e});
                return e;
            };
        } else n.content;
        if (n.encryption.enabled) {
            const stuff = try hlp.do_xor(
                alloc, n.encryption.key.?, note, null
            );
            note = stuff.res;
        }
        file.magic = n.file.magic; 
        file.typ = if (n.file.is_file) n.file.typ else "text/plain";
        file.is_file = n.file.is_file;
        file.size = n.file.size;
        file.name = n.file.name;
        file.comment = n.file.comment;
        if (n.file.size == 0) {
            log.deb("n.file.size == 0 (api_view(...))", .{}) catch {};
            return hlp.lazy_lw_note("");
        }

        //could be from either api request or internal function call
        if (isReq or !file.is_file) if (!db.remove(id)) {
            //send headers (500 server err)
            hlp.send.headersWithType(
                500, conn.reqTime, conn.req, null, null, "text/plain"
            ) catch {}; //ignore err
            try log.err("failed to remove from db", .{});
            return lazy_lw_note("failed to remove from db");
        };
    } else return note_errs.note_not_found;

    //passed to light-weight note struct
    //const size = file.size;

    //generate note preview 
    const conf_prev_size:usize = conn.conf.notes.text_preview_size;
    const prev_si = if (note.len < conf_prev_size) note.len else conf_prev_size;
    const prev_R = note[0..prev_si];

    //check if type is plain-text 
    const is_text = mem.eql(u8, file.typ, "text/plain");
    try log.deb("{any}", .{is_text});

    //only generate preview if it's plain-text
    const prev = if (!is_text) "" else blk: {
        //create a writer
        var prev_buf:[500]u8 = undefined;
        var prev_stream = std.io.fixedBufferStream(&prev_buf);
        var prev_wr = prev_stream.writer().adaptToNewApi(&prev_buf).new_interface;

        //escape preview content
        std.zig.stringEscape(prev_R, &prev_wr) catch |e| {
            log.err("failed to escape JSON string: {t}", .{e}) catch {};
            return lazy_lw_note("failed to generate preview");
        };

        //fixes strange output from 'std.zig.stringEscape'
        break :blk fmt.allocPrint(
            alloc, "{s}", .{prev_wr.buffer[0..prev_wr.end]}
        ) catch "failed to generate preview"; 
    };

    //only send headers if not internal request
    if (isReq) {
        //additional headers with note info
        const add_head = [_][]const u8{
            try fmt.allocPrint(alloc, "comment: {s}", .{file.comment}),
        };
        hlp.send.headersWithType(
            200, conn.reqTime, conn.req, add_head.len, add_head, file.typ
        ) catch {}; //ignore err
    }

    //create light-weight note
    const lw_note:LW_Note = .{
        .magic = file.magic,
        .size = file.size,
        .cont = note,
        .is_file = file.is_file,
        .typ = file.typ,
        .id = id,
        .file_name = file.name,
        .comment = file.comment,
        .prev = if (is_text) prev else "can't generate preview",
    };

    return lw_note;
}

pub const compression = struct {
    
    const Self = @This();

    fn const_u8_to_c_str(
        in_R:[]const u8,
        alloc:mem.Allocator
    ) !struct { ptr:[*c]u8, raw:[:0]u8 } {
        //duplicate into mutable from immutable
        const in:[]u8 = try alloc.dupe(u8, in_R);
        defer alloc.free(in);

        //allocate duplicate with null terminator (C compat) 
        const in_C:[:0]u8 = try alloc.dupeZ(u8, in);

        //get *char 
        const in_C_ptr:[*c]u8 = in_C.ptr;

        return .{ .ptr = in_C_ptr, .raw = in_C };
    }

    fn c_str_to_const_u8(
        alloc:mem.Allocator,
        c_str:[*c]u8,
        len:usize,
    ) ![]const u8 {
        //convert to a slice
        const compressed = c_str[0..len];

        //return as new allocated slice so the C stuff can be freed 
        return try alloc.dupe(u8, compressed);
    }

    fn attempt_unwrap(
        alloc:mem.Allocator,
        comp:?compress.res
    ) ![]const u8 {
        //make sure the struct isn't null and get it
        const com = if (comp) |com| com else {
            return globs.server_errs.FailedToCompress;
        };

        //make sure the content isn't null and get it
        const res = if (com.cont) |res| res else {
            try log.err("failed to compress data", .{});
            return globs.server_errs.FailedToCompress;
        };

        try log.deb("com.leng == {d}", .{com.leng});

        //return converted to Zig string
        return try Self.c_str_to_const_u8(
            alloc, res, @intCast(com.leng)
        );
    }

    fn get_current (
        encs_R:?[][]const u8,
        encs_e:?globs.compression
    ) !globs.compression {
        //if already enum, just return it
        if (encs_e) |en| return en;

        //create empty list of compression types
        var l = try std.ArrayList([]const u8).initCapacity(globs.alloc, 1);
        defer l.deinit(globs.alloc);
        try l.append(globs.alloc, "");

        //get list of compression types
        const encs = if (encs_R) |encs| encs else l.items;
        
        //iterate through list and set the best compression found
        var best:i128 = -1; //
        for (encs) |enc| {
            //convert to enum
            const en = std.meta.stringToEnum(
                globs.compression, enc
            );
            
            //if better than previously matched best, set new best 
            if (en) |e| if (e != .none) {
                const co_I = for (0..,globs.compression_preference) |i, co| {
                    if (co == e) break i;
                } else {
                    try log.errf("uncaught: invalid compression ({s})", .{@tagName(e)});
                    unreachable;
                };
                if (best < co_I) best = co_I;
            };
        }

        //shouldn't happen, but just in case (funny message)
        if (std.math.maxInt(usize) < best) {
            @panic("by golly, that's a lot of compression types");
        }

        //return the best compression type found
        const enc = if (best >= 0) b: {
            break :b globs.compression_preference[@intCast(best)]; 
        } else .none;
        return enc;
    }

    pub fn do(
        in_R:[]const u8,
        conn:*ServerConn,
        encs_R:?[][]const u8,
        encs_e:?globs.compression,
        alloc:mem.Allocator
    ) ![]const u8 {
        //too large to handle currently  TODO: i64
        if (in_R.len > std.math.maxInt(i32)) return in_R;

        const in = try Self.const_u8_to_c_str(in_R, alloc);

        //get enum from compression input
        const enc = try Self.get_current(encs_R, encs_e);

        //compress
        const comp = b: {
            //switch on compression type  TODO: more compression types
            switch (enc) {
                .gzip => break :b compress.Gz(in.ptr, @intCast(in.raw.len)),
                .br, .brotli => break :b compress.Br(in.ptr, @intCast(in.raw.len)),
                .zlib => break :b compress.Zlib(in.ptr, @intCast(in.raw.len)),
                //shouldn't happen, but just in case
                .none => break :b compress.res{
                    .cont = in.ptr,
                    .leng = @intCast(in.raw.len),
                },
            }
        };
        conn.encoding.picked = enc;

        //return unwrapped
        return try Self.attempt_unwrap(alloc, comp);
    }

    pub fn undo(
        in_R:[]const u8,
        conn:*ServerConn,
        encs_R:?[][]const u8,
        encs_e:?globs.compression,
        alloc:mem.Allocator
    ) ![]const u8 {
        _ = conn;
        //too large to handle currently  TODO: i64
        if (in_R.len > std.math.maxInt(i32)) return in_R;

        const in = try Self.const_u8_to_c_str(in_R, alloc);

        //compress
        const comp = b: {
            //get enum from compression input
            const enc = try Self.get_current(encs_R, encs_e);

            //switch on compression type  TODO: more compression types
            switch (enc) {
                .gzip => break :b compress.De_Gz(in.ptr, @intCast(in.raw.len)),
                .br, .brotli => break :b compress.De_Br(in.ptr, @intCast(in.raw.len)),
                .zlib => break :b compress.De_Zlib(in.ptr, @intCast(in.raw.len)),
                //shouldn't happen, but just in case
                .none => break :b compress.res{
                    .cont = in.ptr,
                    .leng = @intCast(in.raw.len),
                },
                //else => {
                //    try log.deb("TODO: decoding {s}", .{@tagName(enc)});
                //    break :b null;
                //}
            }
        };

        //return unwrapped
        return try Self.attempt_unwrap(alloc, comp);
    }
};

fn page_compressor_handler(
    resp_page_R:[]const u8,
    conn:*ServerConn,
    alloc:mem.Allocator,
    info: ?*const struct { comment:[]u8 },
) []const u8 {
    const res = if (conn.encoding.accepts) |enc| compression.do(
        resp_page_R, conn, enc, null, alloc
    ) catch |e| b: {
        if (e != globs.server_errs.UnknownType) {
            log.err("failed to encode page: {t}", .{e}) catch {};
        }
        break :b resp_page_R;
    } else resp_page_R;

    //additional headers 
    const add_headers = [_][]const u8 {
        //only send compression header if applicable
        //  (sends garbage which'll be filtered-out by stuff like Nginx otherwise)
        if (conn.encoding.accepts) |_| b: {
            break :b fmt.allocPrint(
                alloc, "Content-Encoding: {s}", .{@tagName(conn.encoding.picked)}
            ) catch |e| {
                log.err("failed to alloc print \"Content-Encoding\" header: {t}", .{e}) catch {};
                break :b "_: ignore me";
            };
        } else alloc.dupe(u8, "_: ignore me") catch |e| {
            log.err("failed to alloc.dupe: {t}", .{e}) catch {};
            hlp.send.headersWithType(
                200, conn.reqTime, conn.req, null, null, null
            ) catch {};
            return resp_page_R;
        },
        if (info) |i| b: {
            const c = i.comment;
            break :b fmt.allocPrint(alloc, "comment: {s}", .{ c }) catch |e| bl: {
                log.err("Failed to format comment header: {t}", .{e}) catch {};
                break :bl alloc.dupe(u8, "_: ignore me") catch return resp_page_R;
            };
        } else alloc.dupe(u8, "_: ignore me") catch return resp_page_R,
        "Vary: Accept-Encoding", // TODO: check if should be removed if no compression 
    }; defer for ([_]usize{ 0, 1 }) |i| alloc.free(add_headers[i]);

    //respond with headers
    hlp.send.headersWithType(
        200, conn.reqTime, conn.req,
        add_headers.len, add_headers, null
    ) catch {};
    return res;
}

//web page for new note (not much goes on here)
fn newNotePage(
    conn:*ServerConn,
    alloc:mem.Allocator,
) !void {
    //define placeholder replacements
    const placs = [_][]const u8 {
        "<!-- server name -->",
    }; const replacs = [_][]const u8 {
        conn.conf.customization.name,
    };//generate the page
    const respPage_R = hlp.html.gen_page(
        web.new_page, &placs, &replacs, alloc
    ) catch |e| {
        web.send_err(500, "server err", conn);
        try log.err("failed to generate page {t}", .{e});
        return e;
    };

    //either compress or leave uncompressed (sends headers)
    const resp_page = page_compressor_handler(
        respPage_R, conn, alloc, null//.{ .comment = undefined } 
    );

    //send page
    conn.req.server.out.print("{s}", .{resp_page}) catch {};
    conn.req.server.out.flush() catch {};
}

//web page for view note 
fn viewNotePage(
    conn:*ServerConn,
    alloc:mem.Allocator,
    db:*std.StringHashMap(Note)
) !void {
    const req = conn.req;

    //get the note content  TODO: config opt for confirmation screen before fetching
    const note_lw:LW_Note = api_view(conn, alloc, false, db) catch |e| switch (e) {
        note_errs.no_key_found => {
            web.send_err(400, "key not provided", conn); return;
        },
        note_errs.note_not_found => {
            web.send_err(404, "note not found", conn); return;
        },
        else => { web.send_err(500, "server error", conn); return; },
    }; defer alloc.free(note_lw.id); //free the note's id

    //unescaped note
    const noteR:[]const u8 = note_lw.cont;

    //whether or not to escape ampersand
    const esc_html_amper = conn.conf.notes.escape_ampersand;

    //escape html in note
    const note = if (note_lw.is_file) null else b: {
        break :b hlp.sanitizeHTML(noteR, alloc, esc_html_amper) catch |e| {
            try log.err("failed to sanitize html: {t}", .{e});
            web.send_err(500, "failed to sanitize html", conn);
            return e;
        };
    }; defer if (note) |n| { log.deb("freeing note", .{})catch{}; alloc.free(n);}; //free the escaped note

    //define placeholder replacements
    const placs = [_][]const u8 {
        "<!-- server name -->",
        "<!-- note info -->",
        "<!-- file or plain-text -->",
        "<!-- note content -->",
        "<!-- is deleted -->",
    }; const replacs = [_][]const u8 {
        //server name
        conn.conf.customization.name,
        //note info
        generate_note_info(alloc, conn, note_lw),
        //either put note view element or file view element 
        if (note_lw.is_file) "<div id=\"file\"></div>" else blk: {
            break :blk "<pre id=\"note\"><!-- note content --></pre>";
        },
        //note content (discarded if file)
        if (note_lw.is_file) "" else note.?,
        //only show "note deleted" if it's not a file 
        if (note_lw.is_file) "" else "<p><i>note deleted</i></p>",
    };

    //generate the page
    const respPage_R = hlp.html.gen_page(
        web.view_page, &placs, &replacs, alloc
    ) catch |e| {
        web.send_err(500, "server err", conn);
        try log.err("failed to generate page: {t}", .{e});
        return e;
    };

    //either compress or leave uncompressed (sends headers)
    const resp_page = page_compressor_handler(
        respPage_R, conn, alloc, &.{ .comment = note_lw.comment }
    );
    
    //send HTML body and return if err
    req.server.out.print("{s}", .{resp_page}) catch return;
    req.server.out.flush() catch return;
}

//embeded web-ui files
pub const web = struct {
    pub var view_page:[]const u8 = @embedFile("web_comp/view_note.html");
    pub var new_page:[]const u8 = @embedFile("web_comp/new_note.html");
    pub var err_page:[]const u8 = @embedFile("web_comp/err.html");

    //helper to send error page
    pub fn send_err(code:i16, stat:[]const u8, conn:*ServerConn) void {
        const curTime = conn.reqTime;
        const req = conn.req;

        //status code as string
        const code_str = fmt.allocPrint(globAlloc, "{d}", .{code}) catch |e| {
            //log err
            log.err("failed to allocPrint() {t}", .{e}) catch {};
            //respond with 500
            hlp.send.headers(500, curTime, req) catch {};
            req.server.out.print("500 server err", .{}) catch {};
            return;
        }; defer globAlloc.free(code_str);

        const err_json = blk: {
            //fields:
            //  .{ [key], [value], [is_string (empty for false)] }
            const stuff = [_]Json_Pair{
                .{ .k = "code",    .v = code_str,  .is_str = false },
                .{ .k = "status",  .v = stat,      .is_str = true  },
            };
            break :blk hlp.mk_json(
                globAlloc, stuff.len, stuff
            );
        };
        
        //define placeholders and replacements
        const placs = [_][]const u8 {
            "<!-- server name -->",
            "<!-- error code -->",
            "<!-- error status -->",
            "<!-- err data -->",
        }; const replacs = [_][]const u8 {
            conn.conf.customization.name, //server name
            code_str,
            stat, //the err msg
            err_json,
        }; defer globAlloc.free(err_json);

        //generate response page
        const err_html:[]const u8 = web.err_page;
        const respPage = hlp.html.gen_page(
            err_html, &placs, &replacs, globAlloc
        ) catch |e| blk: {
            log.err("failed to generate error page: {t}", .{e}) catch {};
            break :blk "500 server err";
        };

        //send response
        hlp.send.headers(code, curTime, req) catch {};
        req.server.out.print("{s}", .{respPage}) catch {};
        req.server.out.flush() catch {};
    }
};

fn get_header(
    alloc:mem.Allocator,
    conn:*ServerConn,
    which:[]const u8,
) ![]u8 {
    //iterate over headers
    var hItr = conn.req.iterateHeaders();
    while (hItr.next()) |h| {
        //return allocated value if match
        if (mem.eql(u8, h.name, which)) return try alloc.dupe(u8, h.value);
    } //return empty if not found 
    return "";
}

//helper to get the query params
fn get_params(
    alloc: mem.Allocator,
    serverConn:*ServerConn,
    which:[]const u8
) mem.Allocator.Error![]u8 {
    //alias for params
    const params = serverConn.params;

    //read the each param
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

//helper to read request body
fn read_body(
    alloc: mem.Allocator,
    conn:*ServerConn,
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
    if (len_req == 0) return note_errs.zero_len;
    const bod_r = conn_r.bodyReader(bod_buf, http.TransferEncoding.none, len_req);
    
    //read the body
    //  (assumes 'Content-Length' header is correct, responds 500 if not)
    const bod:[]u8 = bod_r.readAlloc(alloc, len_req) catch |e| {
        //if err, respond with either html or return err
        if (respond_html) web.send_err(500, "failed to read request", conn) else {
            //log err
            log.err("failed to read req body: {t}", .{e}) catch {};
            //send headers
            hlp.send.headersWithType(
                500, conn.reqTime, req, null, null, "text/plain"
            ) catch {};
            //send error
            req.server.out.print("failed to read request body", .{}) catch {};
            return alloc.dupe(u8, "server err"); //can't return []const u8 as a []u8 without alloc
        } return e;
    };

    return bod;
}

fn generate_note_info(
    alloc:mem.Allocator,
    conn:*ServerConn,
    lw_note:LW_Note
) []const u8 {
    _ = conn; //might need this at some point

    //convert non-string values to a string (makes the function easier to read)
    const str_is_file = fmt.allocPrint(alloc, "{}", .{lw_note.is_file}) catch "false";
    const str_size = fmt.allocPrint(alloc, "{d}", .{lw_note.size}) catch "null";

    const has_comment = lw_note.comment.len > 0;

    const comment = if (has_comment) lw_note.comment else "null";

    const stuff = [_]Json_Pair {
        .{ .k = "note_size", .v = str_size,            .is_str = false },
        .{ .k = "is_file",   .v = str_is_file,         .is_str = false },
        .{ .k = "file_type", .v = lw_note.typ,         .is_str = true  },
        .{ .k = "file_name", .v = lw_note.file_name,   .is_str = true  },
        .{ .k = "prev",      .v = lw_note.prev,        .is_str = true  },
        .{ .k = "note_id",   .v = lw_note.id,          .is_str = true  },
        .{ .k = "class",     .v = lw_note.magic.class, .is_str = true  },
        .{ .k = "comment",   .v = comment,             .is_str = has_comment },
    };

    std.debug.print("{any}", .{@TypeOf(stuff[0])});
    
    return hlp.mk_json(
        alloc, stuff.len, stuff
    );
}

//returns true if handled
pub fn chk_user_agent(
    agent_R:[]const u8,
    req:ServerConn,
) !bool {
    const agent:[]const u8 = try hlp.to_lower(globs.alloc, agent_R);
    defer globs.alloc.free(agent);

    const bots:[]const []const u8 = &.{
        "whatsapp", "twitterbot", "slackbot", "applebot", "bingpreview",
        "telegrambot", "linkedinbot", "facebookexternalhit",
    };
    for (bots) |bot| {
        if (mem.count(u8, agent, bot) > 0) {
            hlp.send.headers(200, req.reqTime, req.req) catch return true;
            // TODO: preview image (1200x627px)
            req.req.server.out.print(
                \\<!DOCTYPE html>
                \\<html lang="en">
                \\  <head>
                \\    <meta property="og:title" content="tmpNote">
                \\    <meta property="og:description" content="a temporary, self deleting note">
                \\    <!-- TODO: <meta property="og:image" content="some_image_url"> -->
                \\    <title>tmpNote</title>
                \\  </head> 
                \\  <body>
                \\    <h1>note protected from bot ({s})</h1>
                \\  </body>
                \\</html>
                , .{bot}
            ) catch return true; 
            return true;
        }
    }
    return false;
}
