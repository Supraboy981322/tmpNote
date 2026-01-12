const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

var stdout_buf:[1024]u8 = undefined;
var stdout_wr = fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_wr.interface;

const conf_vals = enum {
    port,
    name,
    bad,
};

const def_conf = @embedFile("config");

pub const conf = struct {
    port: u16,
    name: []const u8,

    const Self = @This();

    pub fn read(alloc:mem.Allocator) !Self {
        var port:u16 = 7855;
        var name:[]const u8 = "tmpNote";

        var fi = fs.cwd().openFile("config", .{}) catch |e| {
            switch (e) {
                error.FileNotFound => {
                    try errf("failed to read config: file ('config') not found", .{});
                    return e;
                }, else => return e,
            }
        }; defer fi.close();

        var fi_buf:[1024]u8 = undefined;
        var fi_R = fi.reader(&fi_buf);
        const fi_I = &fi_R.interface;

        var li_N:usize = 0;
        while (try fi_I.takeDelimiter('\n')) |li| {
            li_N += 1;
            var itr = mem.splitSequence(u8, li, ": ");
            if (itr.next()) |keyR| {
                if (itr.next()) |val| {
                    const key = std.meta.stringToEnum(conf_vals, keyR) orelse conf_vals.bad;
                    switch (key) {
                        .port => port = try fmt.parseInt(u16, val, 10),
                        .name => name = try alloc.dupe(u8, val),
                        .bad => try errf("invalid key in config: '{s}' (line {d})\n", .{keyR, li_N}),
                    }
                } else try errf("invalid value for config: line {d}\n", .{li_N});
            } else try errf("invalid config: line number {d}\n", .{li_N});
        }

        try stdout.flush();
        return Self{
            .port = port,
            .name = name,
        };
    }
};

fn err(comptime msg:[]const u8, args:anytype) !void {
    var stderr_buf:[1024]u8 = undefined;
    var stderr_wr = fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_wr.interface;

    try stderr.print(msg, args);
    try stderr.flush();
}

fn errf(comptime msg:[]const u8, args:anytype) !void {
    try err(msg, args);
    std.process.exit(1);
}
