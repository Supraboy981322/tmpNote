//imports
const std = @import("std");
const hlp = @import("helpers.zig");
const globs = @import("global_types.zig");

//structs from std
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const meta = std.meta;
const ascii = std.ascii;

//structs from misc imports
const log = hlp.log;
const log_lvl = globs.log_lvl;

//defaulting to stderr is beyond stupid
var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

pub var safe:bool = false; //determines if it's safe to read conf struct

//accepted units of byte measurement
const valid_byte_sizes = enum {
    b,  //byte
    kb, //kilobyte
    mb, //megabyte
    gb, //gigabyte
    tb, //terabyte
    pb, //petabyte
    eb, //exabyte
    yb, //yottabyte
    any,//TODO: any size
    bad,//invalid
};
//accepted boolean values
//  (used when parsing string to bool)
const bool_enum = enum {
    TRUE,
    FALSE,
    T,
    F,
    BAD, //invalid
};
//valid config keys
const conf_vals = enum {
    preview_size,
    port, //server port
    name, //server name
    max_note_size, //maximum note size
    escape_html_ampersand, //escaping '&' in note HTML
    default_page, //default web page
    log_level, //log verbosity
    log_file, //log file
    log_format,
    bad, //invalid
};

//custom errors
const err = error {
    Invalid_Value,
    Invalid_Key,
    Invalid_Line,
    The_Whole_Damn_Thing,
};

//default config (TODO: setting default config when none found)
const def_conf = @embedFile("config");

pub const conf = struct {
    port: u16,
    name: []const u8,
    max_note_size: u64,
    escape_html_ampersand: bool,
    default_page: []const u8,
    log_level:i8,
    preview_size:usize,
    log_file:[]const u8,
    log_format:globs.log_fmt,

    const Self = @This();

    //parsing the config
    pub fn read(alloc:mem.Allocator) !Self {
        //default values
        var port:u16 = 7855; //server port
        var name:[]const u8 = "//tmpNote"; //server name
        var max_note_size:u64 = 1024 * 1024; //1MB max note size
        var escape_html_ampersand:bool = true; //do escape '&'
        var default_page:[]const u8 = "new";
        var log_level:i8 = 0;
        var prev_si:usize = 100;
        var log_file:[]const u8 = "";
        var log_format:globs.log_fmt = globs.log_fmt.txt;

        //open the config
        var fi = fs.cwd().openFile("config", .{}) catch |e| {
            try log.errf("failed to read config {t}", .{e});
            @panic("failed to fail");
        }; defer fi.close();

        //create a reader interface for config
        var fi_buf:[1024]u8 = undefined;
        var fi_R = fi.reader(&fi_buf);
        const fi_I = &fi_R.interface;

        //read it line-by-line
        //  (friends said they prefer the first line being 1)
        var li_N:usize = 1;
        while (fi_I.takeDelimiter('\n') catch |e| return e) |li| : (li_N += 1) {
            //skip if key is empty 
            if (li.len == 0) continue;
            if (li[0] == '#') continue;
            //split line into key and value
            var itr = mem.splitSequence(u8, li, " : ");
            if (itr.next()) |keyR| { //get key
                if (keyR.len == 0) conf_err(
                    err.Invalid_Key, li_N, "key is empty", keyR
                );
                if (itr.next()) |val| { //get value
                    if (val.len == 0) conf_err(
                        err.Invalid_Value, li_N, "key is empty", keyR
                    );
                    //convert key into enum 
                    const key = meta.stringToEnum(
                        conf_vals, keyR
                    ) orelse conf_vals.bad;
                    //switch on the key
                    switch (key) {
                        //set the port
                        .port => port = fmt.parseInt(u16, val, 10) catch |e| {
                            conf_err(e, li_N, "not a number", val);
                            continue;
                        },
                        //set the server name
                        .name => name = try alloc.dupe(u8, val),
                        //set the maximum note size
                        .max_note_size => {
                            //shorter name for accepted measurements
                            const v_b_s = valid_byte_sizes;

                            //create array to hold measurement array
                            var ext = std.array_list.Managed(u8).init(alloc);
                            defer ext.deinit();

                            //create array to hold size number array 
                            var si_str_arr = std.array_list.Managed(u8).init(alloc);
                            defer si_str_arr.deinit();

                            //for each char in val, either add to
                            //  number or measurement array
                            for (val) |c| if (ascii.isDigit(c)) {
                                si_str_arr.append(c) catch |e| return e;
                            } else ext.append(c) catch |e| return e;

                            //convert size number array into string
                            const si_str:[]const u8 = si_str_arr.items;

                            //err if no number
                            if (si_str.len == 0) conf_err(
                                err.Invalid_Value, li_N,
                                "no number found in", val
                            ); 

                            //attempt to convert string to int
                            const si:u64 = fmt.parseInt(u64, si_str, 10) catch |e| {
                                conf_err(e, li_N, "not a number", si_str);
                                continue;
                            };
                            //set the maximum note size
                            max_note_size = si;

                            //used to determine how many times to multiply
                            //  the max-note-size int by when converting 
                            //    from the specified measurement to bytes
                            var mult_num:usize = 0;

                            //convert measurement array into lowercase string
                            var extL_buf:[1024]u8 = undefined;
                            const extL = ascii.lowerString(&extL_buf, ext.items);

                            //convert measurement string into enum
                            const v = meta.stringToEnum(
                                v_b_s, extL
                            ) orelse v_b_s.bad;

                            //switch on enum
                            switch (v) {
                                .any => continue, //skip multiplication 
                                .b => continue, //skip multiplication 
                                .kb => mult_num = 1, 
                                .mb => mult_num = 2, 
                                .gb => mult_num = 3, 
                                .tb => mult_num = 4,
                                .pb => mult_num = 5,
                                .eb => mult_num = 6,
                                .yb => mult_num = 7,
                                .bad => conf_err( //err on invalid
                                    err.Invalid_Value, li_N,
                                    "bad extension", ext.items
                                ),
                            }

                            //multiply by the set number
                            for (0..mult_num) |_| max_note_size *= 1024;
                        },
                        //set whether to escape ampersand in note
                        .escape_html_ampersand => {
                            //convert value to uppercase 
                            var valU_buf:[1024]u8 = undefined;
                            const valU = ascii.upperString(&valU_buf, val);

                            //convert uppercase value to enum 
                            const valEnum = meta.stringToEnum(
                                bool_enum, valU
                            ) orelse bool_enum.BAD;

                            //switch on enum
                            switch (valEnum) {
                                .TRUE =>  escape_html_ampersand = true,
                                .T => escape_html_ampersand = true,
                                .F => escape_html_ampersand = false,
                                .FALSE => escape_html_ampersand = false,
                                .BAD => conf_err(
                                    err.Invalid_Value, li_N, "not a bool", val
                                ),
                            }
                        },
                        .log_level => {
                            //convert to enum
                            const v = meta.stringToEnum(
                                log_lvl, val
                            ) orelse log_lvl.bad;

                            log_level = switch (v) {
                                .@"0", .debug => 0,
                                .@"1", .info => 1,
                                .@"2", .req => 2,
                                .@"3", .warn => 3,
                                .@"4", .err => 4,
                                .bad => {
                                    const msg:[]const u8 = "not a log level";
                                    conf_err(
                                        err.Invalid_Value, li_N, msg, null
                                    ); unreachable; //conf_err(...) exits
                                },
                            };
                        },
                        .log_file => log_file = try alloc.dupe(u8, val),
                        //set the default web page
                        .default_page => default_page = try alloc.dupe(u8, val),
                        //size of file preview in web page
                        .preview_size => prev_si = try fmt.parseInt(usize, val, 10),
                        .log_format => {
                            log_format = meta.stringToEnum(
                                globs.log_fmt, val
                            ) orelse if (mem.eql(u8, val, "text")) blk: {
                                break :blk globs.log_fmt.txt;
                            } else {
                                conf_err(err.Invalid_Value, li_N, val, null);
                                @panic("failed to fail");
                            };
                        },
                        //invalid option
                        .bad => conf_err(
                            err.Invalid_Key, li_N, keyR, null
                        ),
                    }
                } else conf_err( //likely missing something
                    err.Invalid_Line, li_N, "not a key-value pair", null
                );
            } else conf_err( //delimiter didn't exist
                err.The_Whole_Damn_Thing, li_N, "it's just bad", null
            );
        }

        //make sure everything was flushed;
        try stdout.flush();

        safe = true;
        //return config struct
        return Self{
            .port = port,
            .name = name,
            .max_note_size = max_note_size,
            .escape_html_ampersand = escape_html_ampersand,
            .default_page = default_page,
            .log_level = log_level,
            .preview_size = prev_si,
            .log_file = log_file,
            .log_format = log_format,
        };
    }
};

//local-helper for config err printing
fn conf_err(
    e:anyerror,
    li_N:usize,
    msgR:[]const u8,
    thing:?[]const u8
) void {
    //scoped allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    //format message 
    const msg:[]const u8 = fmt.allocPrint(
        alloc, "(conf err on line {d}) {t} : {s}", .{li_N, e, msgR}
    ) catch |er| { log.errf("{t}", .{er}) catch {}; return; };

    //print msg and exit
    if (thing != null) {
        log.errf("{s} '{s}'", .{msg, thing.?}) catch @panic(msg);
    } else {
        log.errf("{s}", .{msg}) catch @panic(msg);
    }

    //ensure it exited
    std.process.exit(1);
}
