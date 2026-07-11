const std = @import("std");
const hlp = @import("helpers.zig");

const Alloc = std.mem.Allocator;

pub const Note = struct {
    content:[]const u8,
    file:?File,
    compression:?void, // TODO
    encrypted:bool, // TODO

    pub fn free(self:*Note, alloc:Alloc) void {
        alloc.free(self.content);
        if (self.file) |f| f.free(alloc);
    }

    pub fn get(self:*Note, alloc:Alloc, key:[32]u8) error{OutOfMemory}!Note {
        return .{
            .compression = self.compression,
            .encrypted = self.encrypted,

            .content =
                if (self.encrypted)
                    self.decrypt(alloc, key) catch return error.OutOfMemory
                else
                    try alloc.dupe(u8, self.content),

            .file =
                if (self.file) |f|
                    try f.dupe(alloc)
                else
                    null,
        };
    }

    pub const DecryptErr = error{ OutOfMemory, NotEncrypted };

    pub fn decrypt(self:*Note, alloc:std.mem.Allocator, key:[32]u8) DecryptErr![]const u8 {
        if (!self.encrypted) return error.NotEncrypted;
        const content = try alloc.dupe(u8, self.content);
        for (content, 0..) |*b, i|
            b.* = b.* ^ key[i % key.len];
        return content;
    }

    pub fn dupe(self:Note, alloc:std.mem.Allocator) error{OutOfMemory}!Note {
        return .{
            .content = try alloc.dupe(u8, self.content),
            .file = if (self.file) |f| try f.dupe(alloc) else null,
            .compression = self.compression,
            .encrypted = self.encrypted,
        };
    }
};

pub const File = struct {
    type:[]const u8, // TODO: enum?
    magic:Magic,
    size:usize,
    name:[]const u8,
    comment:[]const u8,

    pub fn free(self:*File, alloc:Alloc) void {
        alloc.free(self.type);
        alloc.free(self.name);
        alloc.free(self.comment);
        self.magic.free(alloc);
    }

    pub fn dupe(self:*File, alloc:Alloc) error{OutOfMemory}!File {
        return .{
            .type = try alloc.dupe(u8, self.type),
            .magic = try self.magic.dupe(alloc),
            .size = self.size,
            .name = try alloc.dupe(u8, self.name),
            .comment = try alloc.dupe(u8, self.comment),
        };
    }
};

pub const Magic = struct {
    raw:[]const u8,
    desc:[]const u8,
    class:[]const u8,
    pub fn free(self:*Magic, alloc:Alloc) void {
        alloc.free(self.raw);
        alloc.free(self.desc);
        alloc.free(self.class);
    }

    pub fn dupe(self:*Magic, alloc:Alloc) error{OutOfMemory}!Magic {
        return .{
            .raw = try alloc.dupe(u8, self.raw),
            .desc = try alloc.dupe(u8, self.desc),
            .class = try alloc.dupe(u8, self.class),
        };
    }
};
