//imports
const std = @import("std");
const globs = @import("global_types.zig");
const file_types = @import("file_types.zig");

//structs from std
const crypto = std.crypto;
const ascii = std.ascii;
const http = std.http;
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;

//structs other imports
const ServerConn = globs.ServerConn;
const note_errs = globs.note_errs;
const LW_Note = globs.LW_Note;
const File_Type = globs.File_Type;

//defaulting to stderr is stupid 
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

pub const send = struct {

    const Self = @This();

    //helper to send headers with default type ("text/html") 
    pub fn headers(
        status:i16,
        curTime: []u8,
        req:http.Server.Request
    ) !void { try Self.headersWithType(status, curTime, req, null, null, null); }

    //send headers
    pub fn headersWithType(
        status:i16,
        curTime: []u8,
        req:http.Server.Request,
        comptime N:?usize,
        things:?if (N) |n| [n][]const u8 else [][]const u8,
        content_type:?[]const u8 //optional, null for "text/html"
    ) !void {
        //scoped allocator
        var gpa = heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const alloc = gpa.allocator();

        //array of headers
        const heads = [_][]const u8 {
            switch (status) {
                200 => "HTTP/1.1 200 OK",
                400 => "HTTP/1.1 400 Bad Request",
                403 => "HTTP/1.1 403 FORBIDDEN",
                404 => "HTTP/1.1 404 not found",
                411 => "HTTP/1.1 411 Length Required",
                413 => "HTTP/1.1 413 Content Too Large",
                else => "HTTP/1.1 500 Internal Server Error",
            },
            fmt.allocPrint(
                alloc, "Content-Type: {s}; charset=UTF-8",
                .{ content_type orelse "text/html" }
            ) catch |e| blk: { //just use text/html if alloc fails
                try log.err("failed to allocate 'Content-Type' header: {t}", .{e});
                break :blk "Content-Type: text/html";
            },
            "x-content-type-options: nosniff",
            "server: homebrew zig http server",
            fmt.allocPrint(alloc, "date: {s}", .{curTime}) catch |e| blk: {
                try log.err("failed to allocate 'date' header: {t}", .{e});
                break :blk "foo-bar-baz: foo bar baz"; //jargon if err
            },
        }; defer for ([_]usize{ 1, 4, }) |i| alloc.free(heads[i]); //only free alloc
        
        //send headers
        for (heads) |h| {
            req.server.out.print("{s}\r\n", .{h}) catch return;
            req.server.out.flush() catch return;
        }

        if (things) |ts| for (ts) |t| {
            req.server.out.print("{s}\r\n", .{t}) catch return;
            req.server.out.flush() catch return;
        };

        req.server.out.print("\r\n", .{}) catch return;
    }
};

pub fn ranStr(len:usize, alloc: mem.Allocator) ![]u8 {
    //byte slice of alpha-numeric characters 
    const chars:[]const u8 = "qwertzuiopasdfghjklycvb" ++
                             "nmQWERTZUIOPASDFGHJKLYXCVBNM1234567890";

    //alias for random
    var p_ran = crypto.random;

    //allocate a buffer
    const buf = alloc.alloc(u8, len) catch |e| {
        try log.err("failed to allocate ranStr(len = {d}) buffer: {t}", .{len, e});
        return e;
    };
    //fill buffer with random characters
    for (buf) |*byte| {
        const i = p_ran.intRangeAtMost(usize, 0, chars.len-1);
        byte.* = chars[i];
    }

    //return the buffer
    return buf;
}

pub const log = struct {

    const Self = @This();

    //generic logger
    pub fn generic(
        comptime tag:[]const u8,
        comptime msg:[]const u8,
        args:anytype
    ) !void {
        //log to file if set
        if (globs.conf.server.log.file.len > 0) try Self.wr_log_file(tag, msg, args);
        //... and print to the terminal 
        try stdout.print(tag++" "++msg++"\n", args);
        try stdout.flush();
    }
    
    //write to log file
    //  (separate, unexported fn so generic logger is easier to read)
    fn wr_log_file(
        comptime tag:[]const u8,
        comptime msg:[]const u8,
        args:anytype
    ) !void {
        if (!@import("conf.zig").safe) return;

        const cwd = std.fs.cwd();
        
        var tmp_name:[]const u8 = undefined;
        //duplicate log file before doing anything to it
        { const e:anyerror!void = blk: {
            //temp name 
            tmp_name = std.fmt.allocPrint(
                globs.alloc, "{s}.tmp", .{globs.conf.server.log.file}
            ) catch |e| break :blk e;

            //copy the file
            cwd.copyFile(
                globs.conf.server.log.file, cwd, tmp_name, .{}
            ) catch |e| switch (e) {
                error.FileNotFound => {
                    //silently create file tmp file and actual log files
                    _ = cwd.createFile(globs.conf.server.log.file, .{}) catch |er| return er;
                    _ = cwd.createFile(tmp_name, .{}) catch |er| return er;
                },
                else => {
                    globs.alloc.free(tmp_name);
                    break :blk e;
                },
            };
        //treat any errs as fatal
        }; if (e) {} else |er| fat_err("failed to log to file {t}", .{er}); }
        defer { //cleanup
            cwd.deleteFile(tmp_name) catch |e| {
                fat_err("failed to remove temp log file: {t}", .{e});
            };
            globs.alloc.free(tmp_name);
        }

        //open the log file
        const log_fi = cwd.openFile(
            globs.conf.server.log.file, .{ .mode = .read_write }
        ) catch |e| {
            fat_err("failed to open log file: {t}", .{e});
            unreachable;
        }; defer log_fi.close();

        //append to the log and remove any logs older than
        //  999 logs ago
        const new_log = blk: {
            //open the temp log file (read mode)
            var fi = cwd.openFile(tmp_name, .{}) catch |e| {
                fat_err("couldn't read temp log {t}", .{e});
                unreachable;
            }; defer fi.close();

            //variables to iterate over log file line-by-line
            var fi_buf:[10240]u8 = undefined;
            var fi_re = fi.reader(&fi_buf);
            var li_N:usize = 0;
            const fi_in = &fi_re.interface;

            //initialize an array list to append to 
            var lines = std.array_list.Managed([]const u8).init(globs.alloc);
            defer lines.deinit();

            //add each line to the file
            while (fi_in.takeDelimiter('\n') catch |e| return e) |li| {
                li_N += 1; //keep track of length
                lines.append(li) catch |e| fat_err("{t}", .{e});
            }

            //construct new log line based on configured format
            const new_li = switch (globs.conf.server.log.format) {
                .txt => b: {
                    //just put the tag and message together
                    //  (along with any params passed to logger) 
                    const li_R = std.fmt.allocPrint(
                        globs.alloc, tag++" "++msg, args
                    ) catch |e| {
                        fat_err("failed to format log message {t}", .{e});
                        unreachable;
                    }; defer globs.alloc.free(li_R);

                    //return an allocated string with only ascii bytes
                    break :b strip_ansi(globs.alloc, li_R) catch |e| {
                        fat_err("failed to strip ansi: {t}", .{e});
                        unreachable;
                    };
                },
                .json => b: {
                    //strip non-ascii bytes from the tag 
                    const tag_P = bl: {
                        const tag_T = strip_ansi(
                            globs.alloc, tag
                        ) catch |e| {
                            fat_err("couldn't strip ansi from log json: {t}", .{e});
                            unreachable;
                        }; defer globs.alloc.free(tag_T);
                         //return allocated string without the '[' and ']:'
                        break :bl try globs.alloc.dupe(u8, tag_T[1..tag_T.len-2]); 
                    }; defer globs.alloc.free(tag_P);

                    //formatted message
                    const m = fmt.allocPrint(globs.alloc, msg, args) catch |e| {
                        fat_err("couldn't format message for json log: {t}", .{e});
                        unreachable;
                    }; defer globs.alloc.free(m);

                    //strip non-ascii from formatted message
                    const msg_P = strip_ansi(globs.alloc, m) catch |e| {
                        fat_err("couldn't strip ansi from log json: {t}", .{e});
                        unreachable;
                    }; defer globs.alloc.free(msg_P);

                    //json stuff 
                    const stuff = [_][3][]const u8{
                        .{ "tag", tag_P, "_", },
                        .{ "msg", msg_P, "_", },
                    }; //reture allocated string of json
                    break :b mk_json_inline(
                        globs.alloc, stuff.len, stuff
                    );
                },
            }; defer globs.alloc.free(new_li);

            //add the new line to the log
            lines.append(new_li) catch |e| fat_err("{t}", .{e});
            const res = std.mem.join(globs.alloc, "\n", lines.items) catch |e| {
                fat_err("failed to merge log messages: {t}", .{e});
                unreachable;
            };

            //return copy in mem so it can be freed here (scoped allocation crap) 
            break :blk globs.alloc.dupe(u8, res) catch |e| {
                fat_err("failed to allocate new log: {t}", .{e});
                unreachable;
            };
        }; defer globs.alloc.free(new_log);

        //finally, actually write the log file
        _ = log_fi.write(new_log) catch |e| fat_err(
            "failed to write log: {t}", .{e}
        );
    }

    //helper for formatted request
    pub fn req(
        curTime:[]const u8,
        remAddr:[]const u8,
        reqPage: []const u8
    ) !void {
        if (@import("conf.zig").conf.log_level > 2) return;
        try Self.generic(
            "\x1b[1;37m[\x1b[1;36mreq\x1b[1;37m]:\x1b[0m",
            blk: { //message with a few fields ('addr{...} page{...} date{...}')
                break :blk 
                    "\x1b[1;35maddr\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;34mpage\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m " ++
                    "\x1b[1;32mdate\x1b[1;37m{{\x1b[0m{s}\x1b[1;37m}}\x1b[0m";
            },
            .{remAddr, reqPage, curTime}
        );
    }

    //debug logger
    pub fn deb(comptime msg:[]const u8, args:anytype) !void {
        //only log if debug level
        if (@import("conf.zig").conf.log_level > 0) return;
        try Self.generic(
            "\x1b[1;37m[\x1b[1;34mdebug\x1b[1;37m]:\x1b[0m", msg, args
        );
    }

    //err logger
    pub fn err(comptime msg:[]const u8, args:anytype) !void {
        //only log if err level
        if (@import("conf.zig").conf.log_level > 4) return;
        try Self.generic("\x1b[1;37m[\x1b[1;31merr\x1b[1;37m]:\x1b[0m", msg, args);
    }

    //err and exit
    pub fn errf(comptime msg:[]const u8, args:anytype) !void {
        try log.err(msg, args);
        std.process.exit(1);
        @panic("failed to fail");
    }

    //info logger
    pub fn info(comptime msg:[]const u8, args:anytype) !void {
        //only log if info level
        if (@import("conf.zig").conf.log_level > 1) return;
        try Self.generic("\x1b[1;37m[\x1b[1;35minfo\x1b[1;37m]:\x1b[0m", msg, args);
    }

    //warn logger
    pub fn warn(comptime msg:[]const u8, args:anytype) anyerror!void {
        //only log if warn level
        if (@import("conf.zig").conf.log_level > 3) return;
        try Self.generic("\x1b[1;37m[\x1b[1;33mWARN\x1b[1;37m]:\x1b[0m", msg, args);
    }
};

//fatal error (unrecoverable and can't log)
pub fn fat_err(comptime msg:[]const u8, args:anytype) void {
    var buf:[1024]u8 = undefined;
    var wr = std.fs.File.stderr().writer(&buf);
    const stderr = &wr.interface;
    //print to stderr
    stderr.print(msg, args) catch {};
    stderr.flush() catch {};
    //stop server
    std.process.exit(1);
}

//escape html special characters in web ui
pub fn sanitizeHTML(
    og:[]const u8,
    alloc:mem.Allocator,
    escapeAmper:bool
) ![]const u8 {
    //bad chars
    const bad = [_][]const u8{ "<", ">", "&", "\"", "'" };
    //start with original
    var new_note:[]const u8 = og;
    //replace each instance of each bad char
    for (0.., bad) |i, char| {
        //set replacement char
        const reChar:[]const u8 = switch (i) {
            0 => "&lt;",
            1 => "&gt;",
            2 => if (escapeAmper) "&amp;" else "&", //acceptable ternary replacement
            3 => "&quot;",
            4 => "&apos;", //single quote
            else => {
                try log.err("unknown escape: {s}", .{char});
                return note_errs.invalid_escape;
            },
        };
        //allocate new note size
        const new_si = mem.replacementSize(u8, new_note, char, reChar);
        const tmp_note = alloc.alloc(u8, new_si) catch |e| {
            try log.err("failed to allocate buffer for escaped note: {t}", .{e});
            return e;
        };
        //replace all instances of char
        _ = mem.replace(u8, new_note, char, reChar, tmp_note);
        new_note = tmp_note; //replace note
    }
 
    return new_note;
}

//helper to replace placeholder comments
pub fn gen_page(
    og:[]const u8,
    placeholders:[]const []const u8,
    replacements:[]const []const u8,
    alloc:mem.Allocator
) ![]const u8 {
    //start with original page
    var respPage:[]const u8 = og;
    //iterate through each placeholder
    for (0.., placeholders) |i, plac| {
        //set the thing to replace with
        const replac_with = replacements[i];

        //calculate in-between page size
        const na_replac_si = mem.replacementSize(
            u8, respPage, plac, replac_with
        );

        //allocate in-between page
        const between = alloc.alloc(u8, na_replac_si) catch |e| {
            try log.err("failed to allocate replacement size: {t}", .{e});
//            send.headersWithType(500, curTime, req, "text/plain") catch {};
            return e;
        };

        //replace placeholders 
        _ = mem.replace(u8, respPage, plac, replac_with, between);
        //replace response page with in-between
        respPage = between;
    }

    return respPage;
}

//helper to generate a light-weight note with a message 
pub fn lazy_lw_note(msg:[]const u8) LW_Note {
    return LW_Note{
        .cont = msg, 
        .is_file = false,
        .typ = "text/error",
        .size = msg.len,
        .prev = msg,
        .id = "",
        .magic = text_magic(),
        .comment = "",
        .file_name = "",
    };
}

//helper to check if a string starts with another string
pub fn starts_with(b_s:[]const u8, pre:[]const u8) bool {
    if (b_s.len < pre.len) return false;
    const first_half = b_s[0..pre.len];
    return mem.eql(u8, first_half, pre);
}

//helper to check if string contains a byte
pub fn str_has_byte(str:[]const u8, b:u8) bool {
    for (str) |c| if (c == b) return true;
    return false;
}

//helper for plain-text checks
pub fn chk_is_ascii(b_s:[]u8) bool {
    for (b_s) |b| if (!ascii.isAscii(b)) return false; 
    return true;
}

//helper to check binary type
pub fn chk_magic(b_s:[]u8) File_Type {
    const is_text = chk_is_ascii(b_s);
    var typ:[]const u8 = if (is_text) "text/plain" else "unknown";
    
    var m:globs.Magic = .{
        .raw = "",
        .desc = "couldn't match",
        .class = "unknown",
    };

    if (!is_text) for (file_types.list) |p| {
        const t = p[1]; //type description
        m = globs.Magic {
            .raw = p[0],
            .desc = t,
            .class = p[2],
        };//"magic" byte pattern
        if (starts_with(b_s, m.raw)) { typ = t; break; }
    };
    
    return File_Type{
        .is_text = is_text,
        .is_file = true,
        .typ = typ,
        .magic = m, 
    };
}

//helper for plain-text
pub fn text_magic() globs.Magic {
    return globs.Magic {
        .raw = "foo",
        .desc = "plain text",
        .class = "text",
    };
}

//helper to adapt mk_json old to new mk_json_with_opts
pub fn mk_json(
    alloc:mem.Allocator,
    comptime N:usize,
    stuff:[N][3][]const u8
) []const u8 {
    return mk_json_with_opts(alloc, N, stuff, .{
        .pack = true,
    });
}

//single-line json (eg: '{ "foo":"bar", "baz":"qux" }')
pub fn mk_json_inline(
    alloc:mem.Allocator,
    comptime N:usize,
    stuff:[N][3][]const u8
) []const u8 {
    return mk_json_with_opts(alloc, N, stuff, .{
        .pack = true,
        .delim = ' ',
    });
}

//fields:
//  .{ [key], [value], [is_string (empty for false)] }
pub fn mk_json_with_opts(
    alloc:mem.Allocator,
    comptime N: usize,
    stuff:[N][3][]const u8,
    comptime opts:struct{
        pack:bool = false,
        delim:?u8 = null,
    },
) []const u8 {
    //open JSON body
    var res:[]const u8 = "{"++if (!opts.pack) "\n" else blk: {
        //only use delimiter at start if set to pack json
        break :blk if (opts.delim) |d| b: {
            const foo = &[_]u8{d}; //turn byte into array of 1 byte
            break :b foo[0..]; //coerce into a slice
        } else ""; //default to no spacing
    };

    //iterate through each pair 
    for (0..,stuff) |i, t| {
        //create a writer
        var v_R_buf:[1024]u8 = undefined;
        var v_R_stream = std.io.fixedBufferStream(&v_R_buf);
        var v_R_wr = v_R_stream.writer().adaptToNewApi(&v_R_buf).new_interface;
        //pull buffer out of stream struct (easier to read)
        const v_S_buf = v_R_stream.buffer;

        //escape json value
        std.zig.stringEscape(t[1], &v_R_wr) catch |e| {
            log.err("failed to escape JSON string: {t}", .{e}) catch {};
            return t[1];
        };

        //cut-off on first non-ascii byte
        const v_R = for (0..v_S_buf.len) |j| {
            if (!ascii.isAscii(v_S_buf[j])) break v_S_buf[0..j];
        } else v_S_buf;

        //either put in quotations (string; unescaped) or leave alone (non-string)
        const v = if (t[2].len == 0) v_R else blk: {
            //allocated value in quotes
            break :blk fmt.allocPrint(alloc, "\"{s}\"", .{v_R}) catch |e| blk2: {
                log.err("failed to format note info value {t}", .{e}) catch {};
                break :blk2 "";
            };
        };

        //only use a comma if it isn't he last pair
        const end = blk: {
            //determine delimiter
            const delim:[]const u8 = if (opts.pack) bl: {
                //only use check the provided delimiter if set to pack 
                break :bl if (opts.delim) |d| b: {
                    const foo = &[_]u8{d}; //turn byte into array of 1 byte
                    break :b foo[0..]; //coerce into a slice
                } else ""; //default to no spacing when packing
            } else "\n"; //use newline when not packing
            //add a comma if not the last item (json sucks)
            break :blk if (i == stuff.len-1) delim else ","++delim;
        };

        //format the line
        const line = blk: {
            //determine the separator
            const sep = if (!opts.pack) b: {
                //only use provided delimiter if *not* packing
                if (opts.delim) |d| {
                    const foo = &[_]u8{d}; //turn byte into array of 1 byte
                    break :b foo[0..]; //coerce into a slice
                } else " "; //default to space when not packing
            } else ""; //use no spacing when packing
            //make allocated formatted line string
            break :blk fmt.allocPrint(
                alloc, "{s}\"{s}\":{s}{s}{s}", .{
                    if (opts.pack) sep else "\t", t[0], sep, v, end
                }
            ) catch |e| b: { //log err and use empty line 
                log.err("failed to format json line: {t}", .{e}) catch {};
                break :b "";
            };
        };

        //add the line to the result
        res = fmt.allocPrint(alloc, "{s}{s}", .{res, line}) catch |e| blk: {
            log.err("failed to generate note info: {t}", .{e}) catch {};
            break :blk res;
        };
    } res = fmt.allocPrint( //close the JSON object
        alloc, "{s}}}{s}", .{ res, if (!opts.pack) "\n" else "" }
    ) catch |e| blk: { //log err and set to empty object on err 
        log.err("failed to close note info json object: {t}", .{e}) catch {};
        break :blk "{}";
    };
    return res;
}

//helper to strip non-ascii from string
pub fn strip_ansi(
    alloc:mem.Allocator,
    in:[]const u8
) ![]const u8 {
    //initialize array list (uses input size as capacity) 
    var out_R = try std.ArrayList(u8).initCapacity(alloc, in.len);
    defer out_R.deinit(alloc);

    //iterate over the string
    var esc:bool = false;
    for (0..in.len) |i| {
        if (esc) {//skip if part of ansi code (stop skipping if not) 
            if (!str_has_byte(";[0987654321", in[i])) esc = false;
        } else if (in[i] == '\x1b') esc = true else if (ascii.isAscii(in[i])) {
            try out_R.append(alloc, in[i]); //only add if ascii
        }
    }

    //get the output (remove any possible nulls) 
    const out = out_R.items[0..out_R.items.len];

    //return allocated string (so array list can be deinit())
    return try alloc.dupe(u8, out);
}

//make str lowercase 
pub fn to_lower(
    alloc:mem.Allocator,
    str:[]const u8
) ![]const u8 {
    var res = try std.ArrayList(u8).initCapacity(alloc, str.len);
    defer res.deinit(alloc);
    for (str) |b| {
        try res.append(alloc, if (b >= 'A' and b <= 'Z') b+32 else b);
    }
    return alloc.dupe(u8, res.items);
}
