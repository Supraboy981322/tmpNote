const std = @import("std");
const DB = @import("db.zig");
const hlp = @import("helpers.zig");

opts:Opts,
key:[32]u8,
db:DB,
mut:std.Io.Mutex = .init,

const Io = std.Io;
const Cancelable = Io.Cancelable;
const FieldEnum = std.meta.FieldEnum;
const FieldType = hlp.FieldType;
const fieldInfo = std.meta.fieldInfo;

pub const Opts = struct {
    max_note_length:usize = 1024 * 1024 * 100, // 100MB
};

pub const State = @This();

pub fn init(opts:Opts, db:DB, key:[32]u8) !State {
    return .{
        .opts = opts,
        .db = db,
        .key = key,
    };
}

pub fn deinit(self:*State, io:std.Io) void {
    self.db.deinit(io);
}


pub const Fields = FieldEnum(State);

//for field access with the mutex
pub fn get(self:*State, io:Io, comptime field:Fields) Cancelable!FieldType(State, field) {
    try self.mut.lock(io);
    defer self.mut.unlock(io);
    return @field(self, @tagName(field));
}
