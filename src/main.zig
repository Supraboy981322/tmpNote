//imports
const std = @import("std");
const hlp = @import("helpers.zig");
const config = @import("conf.zig").conf;
const glob_types = @import("global_types.zig");
const globs = glob_types;
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
const web = web_hlp.web;

//types
const note_errs = glob_types.note_errs;
const ServerConn = glob_types.ServerConn;
const Note = glob_types.Note;

//print to stdout (defaulting to stderr is stupid)
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

//scoped allocation is an... interesting... idea
const globAlloc = glob_types.alloc;

//database
var db = std.StringHashMap(Note).init(globAlloc);

pub fn main() !void {
    if (!chk_args()) std.process.exit(0);
    //wipe db on close  TODO: graceful shutdown
    defer db.deinit();

    //set the global config
    glob_types.conf = config.read(globAlloc) catch |e| {
        try log.errf("failed to initialize: {t}", .{e});
        unreachable;
    };
    const conf = glob_types.conf; //just an alias
    init(conf) catch |e| try log.errf("failed to init {t}", .{e});

    //get server addr
    const addr = net.Address.resolveIp("::", conf.port) catch |e| {
        try log.errf("failed to resolve ip: {t}", .{e}); return;
    };

    //initialize the server
    var server = addr.listen(.{ .reuse_address = true }) catch |e| {
        try log.errf("failed to listen on port '{d}': {t}", .{conf.port, e});
        return;
    }; defer server.deinit();

    //log port
    try log.info("{s} is listening on port {d}", .{conf.name, conf.port});

    //wait for connections
    while (true) {
        const acc = server.accept() catch continue;
        hanConn(acc, conf) catch |e| {
            log.err("failed to handle connection {t}", .{e}) catch {};
        };
    }
}

//handles incoming connections
pub fn hanConn(conn: net.Server.Connection, conf:config) !void {
    defer conn.stream.close(); //ensure stream is closed

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
    var remAddr:[]const u8 = undefined; //buffer
    const addrRaw = conn.address.in.sa.addr;
    remAddr = std.fmt.allocPrint(alloc, "{d}", .{addrRaw}) catch return;
    defer alloc.free(remAddr);

    //buffer to hold stream data
    var buf:[1024]u8 = undefined; //buffer
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
    //check the request page, uses default from conf if none
    const reqPage:[]const u8 = if (itr.first().len < 1) conf.default_page else blk: {
        itr.reset() ; break :blk itr.first(); //move index to 0 and get first item
    };
    const params = if (itr.next()) |p| p else ""; //read the params

    //log the request
    try log.req(curTime, remAddr, reqPage); 

    var encoding:globs.Encoding = undefined;
    encoding = b: {
        var pItr = req.iterateHeaders();
        while (pItr.next()) |h| {
            if (mem.eql(u8, h.name, "Accept-Encoding")) {
                var stuff = std.array_list.Managed([]const u8).init(globs.alloc);
                var eItr = mem.tokenizeSequence(u8, h.value, ", ");
                while (eItr.next()) |enc| stuff.append(enc) catch |e| {
                    log.err("failed to append to encoding array: {t}", .{e}) catch {};
                    return e;
                };
                break :b .{ .accepts = stuff.items, .picked = .unknown };
            }
        }
        break :b .{ .accepts = null, .picked = .none };
    };


    //struct passed to handler fn
    var serverConn:ServerConn = ServerConn{
        .conn = conn,
        .encoding = @constCast(&encoding),
        .req = req,
        .reqPage = reqPage,
        .reqTime = curTime,
        .params = params,
        .conf = conf,
        .len_req = 0, //set later by individual endpoint
        .respond_html = false, //set later by individual endpoint
    };

    //determine if api call or web req 
    var target = mem.tokenizeSequence(u8, reqPage, "/");
    if (target.next()) |t| if (mem.eql(u8, t, "api")) { 
        if (target.next()) |t2| web_hlp.handle_api(&serverConn, t2, &db) else {
            web.send_err(404, "Not Found", &serverConn);
        }
    } else web_hlp.handle_web(&serverConn, &db) catch |e| return e;

    //make sure the buffer was flushed
    req.server.out.flush() catch {};
}

pub fn init(conf:config) !void {
    if (@import("conf.zig").used_default) {
        try log.warn("config file not found, using default (use write_config arg to make the default file)", .{});
    }
    if (conf.log_file.len > 0) {
        const opts:std.fs.Dir.WriteFileOptions = .{
            .sub_path = conf.log_file,
            .data = "",
            .flags = std.fs.File.CreateFlags{
                .read = false,
                .truncate = true,
                .exclusive = false,
                .lock = std.fs.File.Lock.none,
                .lock_nonblocking = false,
                .mode = std.fs.File.default_mode
            },
        };
        std.fs.cwd().writeFile(opts) catch |e| {
            try log.errf("failed to create/clear log file: {t}", .{e});
            unreachable;
        };
        try log.deb("reset log", .{});
    //shouldn't occur, but if, for some reason it does, then something changed
    } else try log.deb("config file not set in config", .{});

    if (conf.log_file.len > 0) {
        var stuff = std.mem.splitAny(u8, conf.log_file, ".");
        var ext:[]const u8 = "";
        while (stuff.next()) |f| ext = f;
        const e = std.meta.stringToEnum(globs.log_fmt, ext) orelse .invalid;
        switch (e) {
            .invalid => {},
            else => if (e != conf.log_format) try log.warn(
                "log file format doesn't match file extension", .{}
            ),
        }
    } else try log.warn("no log file set in config", .{});
}

fn chk_args() bool {
    var start:bool = true;
    var err_buf:[1024]u8 = undefined;
    var err_wr = std.fs.File.stdout().writer(&err_buf);
    var stderr = &err_wr.interface;
    const args = std.process.argsAlloc(globs.alloc) catch |e| {
        stderr.print("failed to read args: {}", .{e}) catch {};
        stderr.flush() catch {};
        return false;
    }; defer std.process.argsFree(globs.alloc, args);

    const valid_args = enum {
        write_config, @"write-config", 
        invalid
    };
    for (args, 0..) |arg, i| {
        if (i == 0) continue;
        const a = std.meta.stringToEnum(
            valid_args, arg
        ) orelse .invalid;
        switch (a) {
            .write_config, .@"write-config" => {
                stdout.print("writing default config... (config)\n", .{}) catch {};
                stdout.flush() catch {};
                _ = std.fs.cwd().writeFile(.{
                    .data = @embedFile("config"),
                    .sub_path = "config",
                    .flags = .{},
                }) catch |e| {
                    stderr.print("failed to write default config: {t}\n", .{e}) catch {};
                    stderr.flush() catch {};
                    return true;
                };
                stdout.print("default config written.\n", .{}) catch {};
                stdout.flush() catch {};
                start = false;
            },
            .invalid => {
                stderr.print("invalid arg: {s} (# {d})\n", .{arg, i}) catch {};
                stderr.flush() catch {};
                start = false;
            },
        }
    }
    return start;
}
