const std = @import("std");

pub fn main() !void {
    var h = handler.init();
    for (0..try std.Thread.getCpuCount()) |i| {
        const t = try std.Thread.spawn(.{}, stress, .{i, &h});
        _ = t.detach();
    }
    std.Thread.sleep(1000 * std.time.ns_per_ms);
}

fn stress(i:usize, h:*handler) !void {
    for (0..100) |j| {
        try h.log("[{d}|{d}]: foo", .{i, j});
    }
}

pub const handler = struct {

    mutex:std.Thread.Mutex = .{},
    
    const this = @This(); 

    pub fn init() handler {
        const mutex = std.Thread.Mutex{};
        return .{
            .mutex = mutex,
        };
    }

    pub fn deinit(Self:*handler) void {
        Self.mutex.lock();
        defer Self.mutex.unlock();
        _ = Self.arena.reset(.free_all);
        _ = Self.arena.deinit();
    }
    pub fn log(Self:*handler, comptime fmt:[]const u8, args:anytype) !void {
        Self.mutex.lock();
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const alloc = arena.allocator();
        defer { _ = arena.reset(.free_all); Self.mutex.unlock(); }

        var file = try std.fs.cwd().openFile("foo.log", .{
            .mode = .read_write,
        });
        defer file.close();

        var current_arr = try std.ArrayList(u8).initCapacity(alloc, 0);
        defer { current_arr.clearAndFree(alloc); current_arr.deinit(alloc); }

        var re = &@constCast(&file.reader(&.{})).interface;
        if (@constCast(&(try file.stat())).size != 0) {
            try re.appendRemainingUnlimited(alloc, &current_arr);
        }

        const formatted = try std.fmt.allocPrint(alloc, fmt ++ "\n", args);

        const lines = b: {
            const a = try std.fmt.allocPrint(
                alloc, "{s}{s}\n", .{current_arr.allocatedSlice(), formatted}
            );
            break :b try Self.break_into_lines(alloc, a);
        };
        const line_count = lines.len;
        
        var wr = &@constCast(&file.writer(&.{})).interface;

        const diff:usize = if (line_count > 10) line_count - 10 else 0;
        
        var new = try std.ArrayList(u8).initCapacity(alloc, 0);
        defer { new.clearAndFree(alloc) ; new.deinit(alloc); }

        for (lines[diff..line_count]) |l| {
            try new.appendSlice(alloc, l);
            //std.debug.print("{{{s}}}\n", .{l});
            try new.append(alloc, '\n');
        }
        //std.debug.print("{s}\n", .{new.items});
        try wr.writeAll(new.items);
    }
    fn break_into_lines(Self:*handler, alloc:std.mem.Allocator, in:[]u8) ![][]const u8 {
        _ = Self;
        var res = try std.ArrayList([]const u8).initCapacity(alloc, 0);
        var buf = try std.ArrayList(u8).initCapacity(alloc, 0);
        defer {
            res.clearAndFree(alloc) ; res.deinit(alloc);
            buf.clearAndFree(alloc) ; buf.deinit(alloc);
        }
        loop: for (in) |b| switch (b) {
            '0'...'~' => try buf.append(alloc, b),
            '\n' => {
                if (buf.items.len == 0) continue :loop;
                try res.append(alloc, try buf.toOwnedSlice(alloc));
                buf.clearAndFree(alloc);
            },
            else => {}
        };
        if (buf.items.len > 0) try res.append(alloc, try buf.toOwnedSlice(alloc));
        return try res.toOwnedSlice(alloc);
    }
};
