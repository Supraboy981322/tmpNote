const std = @import("std");

pub fn main() !void {
    try handler.init();
    const t = try std.Thread.spawn(.{}, handler.start, .{});
    _ = t.detach();
    std.Thread.sleep(100 * std.time.ns_per_ms);
    for (0..100) |_| try handler.push("foo");
}

fn stress() !void {
    for (0..100) |_| {
        try handler.push("foo");
        try handler.write();
    }
}

pub const handler = struct {

    var mutex:std.Thread.Mutex = std.Thread.Mutex{};
    var buffer:std.ArrayList([]const u8) = undefined;
    var arena:std.heap.ArenaAllocator = undefined;
    var alloc:std.mem.Allocator = undefined;
    
    const Self = @This(); 

    pub fn start() !void {
        try init();
        while (true) {
            std.Thread.sleep(500 * std.time.ns_per_ms);
            if (buffer.items.len > 0) try write();
        }
    }
   
    pub fn init() !void {
        var thread_alloc = std.heap.ThreadSafeAllocator{
            .child_allocator = std.heap.page_allocator,
        };
        arena = std.heap.ArenaAllocator.init(thread_alloc.allocator());
        alloc = Self.arena.allocator();
        buffer = try std.ArrayList([]const u8).initCapacity(Self.alloc, 0);
    }
    pub fn deinit() void {
        mutex.lock();
        defer mutex.unlock();
        _ = buffer.deinit(Self.alloc);
        _ = arena.reset(.free_all);
        _ = arena.deinit();
    }
    pub fn push(msg:[]const u8) !void {
        mutex.lock();
        defer mutex.unlock();
        try buffer.append(alloc, msg);
    }
    pub fn drain() !void {
        defer mutex.unlock();
        deinit();
        mutex.lock();
        try init();
    }
    pub fn write() !void {
        mutex.lock();
        for (buffer.items) |msg| {
            std.debug.print("{s}\n", .{msg});
        }
        mutex.unlock();
        try drain();
    }
};
