const std = @import("std");
const globs = @import("global_types.zig");
const log = @import("helpers.zig").log;

pub var safe:bool = false;
pub var used_default:bool = false;

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

//custom errors
const err = error {
    Invalid_Value,
    Invalid_Key,
    Invalid_Line,
    The_Whole_Damn_Thing,
};

pub const conf = struct {
    server: struct {
        port: u16,
        default_page: enum {new, view},
        log: struct {
            level: globs.log_lvl,
            format: globs.log_fmt,
            file: []const u8,
        },
    },
    customization: struct {
        name:[]const u8,
    },
    notes:struct {
        max_size:[]const u8,
        text_preview_size:usize,
        compression: globs.compression,
        escape_ampersand: bool,
    },

    const Self = @This();
    pub var log_level:i8 = undefined;
    pub var max_note_size:usize = undefined;

    //parsing the config
    pub fn read(alloc:std.mem.Allocator) !Self {
        //read the whole config file
        const file = try read_whole_damn_file(alloc, "config.zon");

        //make sure dupe is freed
        defer alloc.free(file);

        safe = true; 
        const config = try std.zon.parse.fromSlice(
            Self, alloc, file, null, .{
                .ignore_unknown_fields = false,
                .free_on_error = true,
            }
        );

        log_level = switch (config.server.log.level) {
            .@"0", .debug => 0,
            .@"1", .info => 1,
            .@"2", .req => 2,
            .@"3", .warn => 3,
            .@"4", .err => 4,
        };

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
        for (config.notes.max_size) |c| if (std.ascii.isDigit(c)) {
            si_str_arr.append(c) catch |e| return e;
        } else ext.append(c) catch |e| return e;

        //convert size number array into string
        const si_str:[]const u8 = si_str_arr.items;

        //err if no number
        if (si_str.len == 0) try log.errf(
            "err parsing config: ({t}) no number found in {s}", .{err.Invalid_Value, si_str}
        ); 

        //attempt to convert string to int
        const si:u64 = std.fmt.parseInt(u64, si_str, 10) catch |e| {
            try log.errf("{t} not a number: {s}", .{e, si_str});
            unreachable;
        };

        //set the maximum note size
        Self.max_note_size = si;

        //convert measurement array into lowercase string
        var extL_buf:[1024]u8 = undefined;
        const extL = std.ascii.lowerString(&extL_buf, ext.items);

        //convert measurement string into enum
        const v = std.meta.stringToEnum(
            v_b_s, extL
        ) orelse v_b_s.bad;

        //used to determine how many times to multiply
        //  the max-note-size int by when converting 
        //    from the specified measurement to bytes
        const mult_num:usize = switch (v) {
            .any => 0, //skip multiplication 
            .b => 0, //skip multiplication 
            .kb => 1, 
            .mb => 2, 
            .gb => 3, 
            .tb => 4,
            .pb => 5,
            .eb => 6,
            .yb => 7,
            .bad => {
                //err on invalid
                try log.errf("{t}: bad extention {s}", .{err.Invalid_Value, ext.items});
                unreachable;
            },
        };

        //multiply by the set number
        for (0..mult_num) |_| Self.max_note_size *= 1024;

        //attempty to parse Zon
        return config;
    }
};

//helper to just read a whole file
pub fn read_whole_damn_file(alloc:std.mem.Allocator, name:[]const u8) ![:0]const u8 {
    //open file
    const fi:?std.fs.File = std.fs.cwd().openFile(name, .{}) catch |e| b: {
        if (e == error.FileNotFound) break :b null;
        try log.errf("failed to open config {t}", .{e});
        unreachable;
    };

    //create array_list
    var res = try std.ArrayList(u8).initCapacity(alloc,0);
    defer _ = res.deinit(alloc);

    //get reader interface
    var re = if (fi) |f| b: {
        //wrap file reader with no buffer
        var wrapper = f.reader(&.{});
        break :b &wrapper.interface;
    } else b: {
        used_default = true;
        break :b @constCast(
            &std.io.Reader.fixed(@embedFile("config.zon"))
        );
    };

    //attempt to dump whole file into array_list
    try re.appendRemainingUnlimited(alloc, &res);

    //return allocated slice of remaining items
    return alloc.dupeZ(u8, res.items);
}
