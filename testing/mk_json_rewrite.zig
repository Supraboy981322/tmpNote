const std = @import("std");
const mem = std.mem;

const json_pair = struct{ k:[]const u8, v:[]const u8, is_str:bool };

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const pairs = [_]json_pair{
        json_pair{ .k = "foo", .v = "bar", .is_str = true },
        json_pair{ .k = "baz", .v = "1", .is_str = false },
    };

    const json = try mk_json_with_opts(
        alloc, pairs.len, pairs, .{ .pack = true }
    );

    std.debug.print("{s}", .{json});
}

pub fn mk_json_with_opts(
    alloc:mem.Allocator,
    comptime N: usize,
    pairs:[N]json_pair,
    comptime opts:struct{
        pack:bool = false,
        delim:?u8 = null,
    },
) ![]const u8 {
    const delim = if (opts.delim) |d| &[_]u8{d} else if (opts.pack) "" else " ";
    //create array list
    var res = try std.ArrayList(u8).initCapacity(alloc, 0);
    defer _ = res.deinit(alloc); 

    //open json object
    try res.append(alloc, '{');

    //add either newline (non-packing) or delimiter (empty if none provided)
    try res.appendSlice(alloc, if (!opts.pack) "\n" else delim);

    //iterate through pairs
    for (0..,pairs) |i, p| {
        //determine what goes before the key
        const before_key = (if (opts.pack) delim else "\t") ++ "\"";

        //determine the slice added after the key 
        const after_key = "\":" ++ (if (opts.pack) "" else delim);

        //before value
        const before_val = if (p.is_str) "\"" else "";

        //determine the slice added after the key 
        const after_val = if (p.is_str) "\"" else "";

        const chunks = [_][]const u8 {
            before_key, p.k, after_key,
            before_val, p.v, after_val,
            if (i < N-1) "," else "", if (opts.pack) "" else "\n"
        };

        for (chunks) |ch| try res.appendSlice(alloc, ch);
    }

    try res.append(alloc, '}');
    return try alloc.dupe(u8, res.items);
}
