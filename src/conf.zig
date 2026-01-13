const std = @import("std");

const log = @import("helpers.zig").log;

const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const meta = std.meta;
const ascii = std.ascii;

var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

const valid_byte_sizes = enum {
    b,
    kb,
    mb,
    gb,
    tb,
    pb,
    eb,
    yb,
    any,
    bad,
};
const bool_enum = enum {
    TRUE,
    FALSE,
    T,
    F,
    BAD,
};
const conf_vals = enum {
    port,
    name,
    max_note_size,
    escape_html_ampersand,
    bad,
};

//custom errors
const err = error {
    Invalid_Value,
    Invalid_Key,
    Invalid_Line,
    The_Whole_Damn_Thing,
};

const def_conf = @embedFile("config");

pub const conf = struct {
    port: u16,
    name: []const u8,
    max_note_size: u64,
    escape_html_ampersand: bool,

    const Self = @This();

    pub fn read(alloc:mem.Allocator) !Self {
        var port:u16 = 7855;
        var name:[]const u8 = "tmpNote";
        var max_note_size:u64 = 1024 * 1024; //1MB
        var escape_html_ampersand:bool = true;

        var fi = fs.cwd().openFile("config", .{}) catch |e| {
            try log.errf("failed to read config {t}", .{e});
            @panic("failed to fail");
        }; defer fi.close();

        var fi_buf:[1024]u8 = undefined;
        var fi_R = fi.reader(&fi_buf);
        const fi_I = &fi_R.interface;

        var li_N:usize = 0;
        while (fi_I.takeDelimiter('\n') catch |e| {
            try log.errf("{t}", .{e});
            @panic("huh... failed to fail");
        }) |li| {
            li_N += 1;
            var itr = mem.splitSequence(u8, li, " : ");
            if (itr.next()) |keyR| {
                if (itr.next()) |val| {
                    const key = meta.stringToEnum(
                        conf_vals, keyR
                    ) orelse conf_vals.bad;
                    if (keyR.len == 0) conf_err(
                        err.Invalid_Key, li_N, "no key", null
                    );
                    switch (key) {
                        .port => port = fmt.parseInt(u16, val, 10) catch |e| {
                            conf_err(e, li_N, "not a number", val);
                            continue;
                        },
                        .name => name = try alloc.dupe(u8, val),
                        .max_note_size => {
                            const v_b_s = valid_byte_sizes;

                            var ext = std.array_list.Managed(u8).init(alloc);
                            defer ext.deinit();

                            var si_str_arr = std.array_list.Managed(u8).init(alloc);
                            defer si_str_arr.deinit();

                            for (val) |c| if (ascii.isDigit(c)) {
                                si_str_arr.append(c) catch |e| {
                                    try log.errf("{t}", .{e});
                                };
                            } else ext.append(c) catch |e| try log.errf("{t}", .{e});

                            const si_str:[]const u8 = si_str_arr.items;

                            if (si_str.len == 0) conf_err(
                                err.Invalid_Value, li_N,
                                "no number found in", val
                            ); 
                            const si:u64 = fmt.parseInt(u64, si_str, 10) catch |e| {
                                conf_err(e, li_N, "not a number", si_str);
                                continue;
                            };

                            var extL_buf:[1024]u8 = undefined;
                            const extL = ascii.lowerString(&extL_buf, ext.items);
                            const v = meta.stringToEnum(
                                v_b_s, extL
                            ) orelse v_b_s.bad;

                            var mult_num:usize = 0;
                            max_note_size = si;

                            switch (v) {
                                .any => continue,
                                .b => continue,
                                .kb => mult_num = 1, 
                                .mb => mult_num = 2,
                                .gb => mult_num = 3,
                                .tb => mult_num = 4,
                                .pb => mult_num = 5,
                                .eb => mult_num = 6,
                                .yb => mult_num = 7,
                                .bad => conf_err(
                                    err.Invalid_Value, li_N,
                                    "bad extension", ext.items
                                ),
                            }
                            for (0..mult_num) |_| max_note_size *= 1024;
                        },
                        .escape_html_ampersand => {
                            var valU_buf:[1024]u8 = undefined;
                            const valU = ascii.upperString(&valU_buf, val);
                            const valEnum = meta.stringToEnum(
                                bool_enum, valU
                            ) orelse bool_enum.BAD;
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
                       .bad => conf_err(
                            err.Invalid_Key, li_N, "key doesn't exist", null
                        ), 
                    }
                } else conf_err(
                    err.Invalid_Line, li_N, "missing key and/or value", null
                );
            } else conf_err(
                err.Invalid_Line, li_N, "it's just bad", null
            );
        }

        //make sure everything was flushed;
        try stdout.flush();

        return Self{
            .port = port,
            .name = name,
            .max_note_size = max_note_size,
            .escape_html_ampersand = escape_html_ampersand,
        };
    }
};

fn conf_err(
    e:anyerror,
    li_N:usize,
    comptime msg:[]const u8,
    thing:?[]const u8
) void {
    if (thing != null) {
        log.errf(
            "(conf err on line {d}) {t} : "++msg++" '{s}'",
            .{li_N, e, thing.?}
        ) catch return;
    } else {
        log.errf(
            "(conf err on line {d}) {t} : "++msg,
            .{li_N, e}
        ) catch return;
    }
}
