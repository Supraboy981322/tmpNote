const std = @import("std");
const types = @import("types.zig");

const DB = @This();
const KeyType = u64;
pub const ENCODED_ID_LEN = 11;

map:std.AutoHashMap(KeyType, Note),
alloc:std.mem.Allocator,
mut:std.Io.Mutex = .init,

const Note = types.Note;
const Alloc = std.mem.Allocator;
const Io = std.Io;

const toValue = std.mem.bytesToValue;
const assert = std.debug.assert;
const base64 = std.base64.url_safe_no_pad;

pub fn init(alloc:Alloc) !DB {
    return .{
        .alloc = alloc,
        .map = .init(alloc),
    };
}

pub fn deinit(self:*DB, io:Io) void {
    var locked:bool = true;
    self.mut.lock(io) catch { locked = false; };
    defer if (locked) self.mut.unlock(io);

    var itr = self.map.iterator();
    while (itr.next()) |note|
        note.value_ptr.free(self.alloc);
    self.map.deinit();
}

pub const PutError = Alloc.Error || Io.Cancelable;
//returns key
pub fn put(self:*DB, io:Io, note:Note) PutError![ENCODED_ID_LEN]u8 {
    try self.mut.lock(io);
    defer self.mut.unlock(io);

    const duped = try note.dupe(self.alloc);
    var key_buf:[@sizeOf(KeyType)]u8 = undefined;
    var key:KeyType = 0;
    while (true) {
        io.random(&key_buf);
        key = toValue(KeyType, &key_buf);
        if (!self.map.contains(key)) break;
    }
    try self.map.putNoClobber(key, duped);

    var encode_buf:[ENCODED_ID_LEN]u8 = undefined;
    const encoded = base64.Encoder.encode(&encode_buf, &key_buf);
    return encoded[0..ENCODED_ID_LEN].*;
}

pub const GetError = PutError;
const GetHow = union(enum) {
    destroy:Alloc,
    keep
};
pub fn get(self:*DB, io:Io, key:KeyType, how:GetHow) GetError!?Note {
    try self.mut.lock(io);
    defer self.mut.unlock(io);

    if (!self.map.contains(key)) return null;
    const note = self.map.getPtr(key).?;
    switch (how) {
        .destroy => |alloc| {
            const duped = try note.dupe(alloc);
            note.free(self.alloc);
            assert(self.map.remove(key));
            return duped;
        },
        .keep => return note.*,
    }

    unreachable;
}

pub const GetBase64Error = GetError || error{InvalidKey};
pub fn getBase64(self:*DB, io:Io, key_str:[]const u8, how:GetHow) GetBase64Error!?Note {
    if (key_str.len > ENCODED_ID_LEN) return error.InvalidKey;
    var buf:[ENCODED_ID_LEN]u8 = undefined;
    base64.Decoder.decode(&buf, key_str) catch |e| switch (e) {
        error.NoSpaceLeft => unreachable, //increase MAX_ENCODED_KEY_LEN
        else => return error.InvalidKey,
    };
    const key = toValue(KeyType, &buf);
    return self.get(io, key, how);
}
