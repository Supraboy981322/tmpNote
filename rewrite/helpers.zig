const std = @import("std");

const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;
const expectEqualStrings = std.testing.expectEqualStrings;

const Io = std.Io;
const Writer = Io.Writer;

pub fn filterErr(err:anytype, comptime remove:@TypeOf(err)) !void {
    return switch (err) {
        remove => unreachable,
        inline else => |e| e,
    };
}

//returns length of buffer used
pub fn xor(in:[]const u8, out:[]u8, key:[32]u8) usize {
    assert(out.len >= in.len);
    for (0..in.len) |i|
        out[i] ^= in[i] ^ key[i % key.len];
    return in.len;
}
test xor {
    const io = std.testing.io;

    var key:[32]u8 = undefined;
    try io.randomSecure(&key);

    const msg = "foo bar baz";

    var one_buf:[1024]u8 = undefined;
    const one = one_buf[0..xor(msg, &one_buf, key)];
    try expect(!std.mem.eql(u8, one, msg));

    var two_buf:[1024]u8 = undefined;
    const two = two_buf[0..xor(one, &two_buf, key)];
    try expectEqualStrings(two, msg);
}

pub fn xorInPlace(buf:[]u8, key:[32]u8) void {
    for (buf, 0..) |*b, i| b.* ^= key[i % key.len];
}

pub fn FieldType(comptime T:type, field:std.meta.FieldEnum(T)) type {
    return std.meta.fieldInfo(T, field).type;
}
