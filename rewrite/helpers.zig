const std = @import("std");

pub fn filterErr(err:anytype, comptime remove:@TypeOf(err)) !void {
    return switch (err) {
        remove => unreachable,
        inline else => |e| e,
    };
}
