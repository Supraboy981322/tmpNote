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

//database
var db:globs.DB = undefined; 

pub fn main() !void {
    if (!chk_args()) std.process.exit(0);

    var db_arena = std.heap.ArenaAllocator.init(heap.page_allocator);
    defer db_arena.deinit();

    //create db (db doesn't save to disk)  TODO: graceful shutdown
    db = .{ //db has it's own allocator
        .db = std.StringHashMap(Note).init(db_arena.allocator()),
        .alloc = db_arena.allocator(),
    };
    defer db.db.deinit();

    //set the global config
    globs.conf = config.read(globs.alloc) catch |e| {
        log.errf(
            "failed to parse config: \"{t}\" " ++ 
                "(I know, utterly useless error, stupid std.zon Zig error handling)\n" ++
                "I shall now dump the stack trace (sorry)\n\n", .{e}
        ) catch {};
        return e;
    };
    defer std.zon.parse.free(globs.alloc, globs.conf);

    const conf = glob_types.conf; //just an alias
    init(conf) catch |e| try log.errf("failed to init {t}", .{e});

    //get server addr
    const addr = net.Address.resolveIp("::", conf.server.port) catch |e| {
        try log.errf("failed to resolve ip: {t}", .{e}); return;
    };

    //initialize the server
    var server = addr.listen(.{ .reuse_address = true }) catch |e| {
        try log.errf("failed to listen on port '{d}': {t}", .{conf.server.port, e});
        return;
    }; defer server.deinit();

    //log port
    try log.info("{s} is listening on port {d}", .{
        conf.customization.name, conf.server.port
    });

    //used for debugging
    var i:usize = 0;

    //wait for connections
    while (true) {
        const acc = server.accept() catch continue;
        if (conf.server.use_async) {
            try log.deb("spawning handler thread", .{});
            const t = try std.Thread.spawn(.{}, hanConn, .{acc, conf});
            t.detach();
        } else hanConn(acc, conf) catch |e| {
            try log.err("failed to handle connection: {t}", .{e});
        };
        if (conf.debug.quit_after_n_requests) |n| {
            if (i >= n-1) break else i+=1;
            try log.warn("request {d} of {d} until quitting", .{i, n});
        }
    }
}

//handles incoming connections
pub fn hanConn(
    conn: net.Server.Connection,
    conf:config,
) !void {
    //arena that lasts the lifetime of the request
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    
    defer conn.stream.close(); //ensure stream is closed

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
    const remAddr:[]const u8 = b: {
        var foo = std.Io.Writer.Allocating.init(alloc);
        defer foo.deinit();
        try conn.address.format(&foo.writer);
        break :b try alloc.dupe(u8, foo.written());
    };
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
        return e; //return on err (a netcat cmd could cause problems otherwise)
    }; defer req.server.out.flush() catch {};

    var itr = mem.splitAny(u8, req.head.target[1..], "?"); //remove query params

    //check the request page, uses default from conf if none
    const reqPage:[]const u8 = if (itr.first().len < 1)
        @tagName(conf.server.default_page)
    else blk: { //move index to 0 and get first item
        itr.reset() ; break :blk itr.first();
    };
    const params = if (itr.next()) |p| p else ""; //read the params

    //log the request
    try log.req(curTime, remAddr, reqPage); 

    var encoding:?globs.Encoding = null;
    var is_mobile:bool = false;
    var agent:[]const u8 = "";
    {var pItr = req.iterateHeaders();
    while (pItr.next()) |h| {
        const h_e = std.meta.stringToEnum(enum{
            @"Accept-Encoding", @"User-Agent", skip,
        }, h.name ) orelse .skip;

        switch (h_e) {
            .@"Accept-Encoding" => {
                var stuff = std.array_list.Managed([]const u8).init(alloc);
                defer stuff.deinit();
                var eItr = mem.tokenizeSequence(u8, h.value, ", ");
                while (eItr.next()) |enc| stuff.append(enc) catch |e| {
                    log.err("failed to append to encoding array: {t}", .{e}) catch {};
                    return e;
                };
                encoding = .{ .accepts = stuff.items, .picked = .none };
            },
            .@"User-Agent" => {
                try log.deb("{s}", .{h.value}); 
                agent = h.value;

                is_mobile = mem.count(u8, h.value, "Mobile") > 0;
            },
            .skip => {},
            //else => try log.deb("forgot to add {s} header switch prong", .{@tagName(h_e)}),
        }
    }{  //anything that could be null needs a value 
        if (encoding) |_| {} else encoding = .{ .accepts = null, .picked = .none };
    }}

    try log.deb("server conn", .{});

    //struct passed to handler fn
    var serverConn:ServerConn = ServerConn{
        .conn = conn,
        .encoding = @constCast(&encoding.?),
        .req = req,
        .reqPage = reqPage,
        .reqTime = curTime,
        .params = params,
        .conf = conf,
        .len_req = 0, //set later by individual endpoint
        .respond_html = false, //set later by individual endpoint
    };

    // BUG: Zig std.http hangs after mobile request finishes
    //   TODO: switch to new async http when Zig 0.16.0 releases
    if (!conf.server.use_async and is_mobile) {
        const msg = "sorry, mobile currently overloads the server, " ++ 
                    "still waiting for async http Zig update";
        web_hlp.generic_serve(
            &serverConn, "text/plain", msg, 400
        ) catch {};
        return; 
    }

    //check and possibly handle requests that aren't users
    const handled:bool = web_hlp.chk_user_agent(agent, serverConn) catch {
        hlp.send.headersWithType(
            500, curTime, req, null, null, "text/plain"
        ) catch {};
        req.server.out.print("failed to check user agent", .{}) catch {};
        return;
    }; if (handled) return;

    
    try log.deb("get target", .{});

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

pub fn init(
    conf:config
) !void {
    const config_ = @import("conf.zig");
    if (conf.server.use_async and conf.server.log.format != .none) {
        try log.errf("sorry, but currently it's not possible to use " ++ 
            "both async and a log file. please set server.log.format = .none", .{}); 
    }
    if (config_.used_default) {
        try log.warn(
            "config file not found, using default " ++ 
            "(use the write_config arg to write it to a file)", .{}
        );
    }
    if (conf.debug.quit_after_n_requests) |n| {
        try log.warn("the server is set to quit after {d} requests", .{n});
    }

    if (conf.server.log.file.len > 0 and conf.server.log.format != .none) {
        const opts:std.fs.Dir.WriteFileOptions = .{
            .sub_path = conf.server.log.file,
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

    if (conf.server.log.file.len > 0) {
        var stuff = std.mem.splitAny(u8, conf.server.log.file, ".");
        var ext:[]const u8 = "";
        while (stuff.next()) |f| ext = f;
        const e = std.meta.stringToEnum(globs.log_fmt, ext).?;
        switch (e) {
            else => if (e != conf.server.log.format) try log.warn(
                "log file format doesn't match file extension", .{}
            ),
        }
    } else try log.warn("no log file set in config", .{});

    if (conf.customization.css) |css| {
        var alloc = globs.alloc;
        if (css.disable_default) {
            web.err_page = try hlp.html.remove_element(
                alloc, .{ .open = "<style>", .close = "</style" }, web.err_page
            );
            web.view_page = try hlp.html.remove_element(
                alloc, .{ .open = "<style>", .close = "</style" }, web.view_page
            );
            web.new_page = try hlp.html.remove_element(
                alloc, .{ .open = "<style>", .close = "</style" }, web.new_page
            );
        }
        if (css.custom_file) |filename| {
            const is_abs:bool = fs.path.isAbsolute(filename);
            const file_path = if (is_abs) try alloc.dupe(u8, filename) else b: {
                break :b try fs.cwd().realpathAlloc(alloc, filename);
            };
            defer alloc.free(file_path);

            const stylesheet_file = try fs.openFileAbsolute(file_path, .{});

            var wrapper = stylesheet_file.reader(&.{});
            var re = &wrapper.interface;

            var array_list = try std.ArrayList(u8).initCapacity(alloc, 0);
            defer array_list.deinit(alloc);

            try re.appendRemainingUnlimited(alloc, &array_list);

            const element = try fmt.allocPrint(alloc, "<style>{s}</style>", .{array_list.items});
            defer alloc.free(element);
            
            web.view_page = try hlp.html.add_to_element(
                alloc, "</head>", web.view_page, element
            );
            web.new_page = try hlp.html.add_to_element(
                alloc, "</head>", web.new_page, element
            );
            web.err_page = try hlp.html.add_to_element(
                alloc, "</head>", web.err_page, element
            );
        }
    }
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
                    .data = @embedFile("config.zon"),
                    .sub_path = "config.zon",
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
