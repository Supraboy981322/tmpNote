const std = @import("std");
const globs = @import("global_types.zig");
const web_hlp = @import("web_helpers.zig");
const hlp = @import("helpers.zig");
pub var log:hlp.Log = undefined;

const File = globs.File;

pub const Note = struct {
    content: []u8,
    file: File,
    compression: globs.compression,
    encryption: struct {
        enabled: bool,
        key: ?[32]u8 = null,
    },

    pub fn deinit(
        this:*Note,
        allocator:std.mem.Allocator
    ) void {
        allocator.free(this.content);
        allocator.free(this.file.name);
        allocator.free(this.file.comment);
    }

    pub fn clone(
        this:*Note,
        allocator:std.mem.Allocator,
    ) !Note {
        return .{
            .content = try allocator.dupe(u8, this.content),
            .file = .{
                .typ = this.file.typ,
                .is_file = this.file.is_file,
                .magic = this.file.magic,
                .size = this.file.size,
                .name = try allocator.dupe(u8, this.file.name),
                .comment = try allocator.dupe(u8, this.file.comment),
            },
            .compression = this.compression,
            .encryption = .{
                .enabled = this.encryption.enabled,
                .key = if (this.encryption.enabled)
                            (try allocator.dupe(u8, &this.encryption.key.?))[0..32].*
                        else null,
            },
        };
    }
};

pub const DB = struct {
    db:std.StringHashMap(Note),
    alloc:std.mem.Allocator = std.heap.page_allocator,

    pub fn init() !DB {
        const alloc = std.heap.page_allocator;
        return .{
            .alloc = alloc,
            .db = std.StringHashMap(Note).init(alloc),
        };
    }

    pub fn retrieve_entry(
        this:*DB,
        id:[]const u8,
        conn:?*globs.ServerConn,
        allocator:std.mem.Allocator,
        is_req:bool,
    ) !Note {
        defer log.deb("note retrieved", .{}) catch {};

        var note:Note = undefined;
        if (this.db.fetchRemove(id)) |kv| {
            const n = @constCast(&kv.value);
            defer n.deinit(this.alloc);

            note = try n.clone(allocator);

            const is_file = n.file.is_file;
            if (!is_req or is_file) {
                const id_alloc = try this.alloc.dupe(u8, id);
                const duped_note = try n.clone(this.alloc);
                try this.db.put(id_alloc, duped_note);
            }

            //se note and delete from db
            if (conn) |c| if (c.conf.notes.compression != .none) {
                note.content = @constCast(try web_hlp.compression.undo(
                    note.content, conn.?, null, conn.?.conf.notes.compression, allocator
                ));
            };

            if (n.encryption.enabled) {
                const stuff = try hlp.do_xor(
                    allocator, n.encryption.key.?, note.content, null
                );
                try log.deb("setting note to unencrypted result", .{});
                note.content = stuff.res;
                try log.deb("note unencrypted", .{});
            }
        } else return globs.note_errs.note_not_found;

        return note;
    }

    pub fn clear(this:*DB) !void {
        var it = this.db.keyIterator();
        while (it.next()) |key_ptr| {
            const key = key_ptr.*; 
            defer this.alloc.free(key);

            const value = if (this.db.fetchRemove(key)) |k| k.value else continue;
            @constCast(&value).deinit(this.alloc);
        }
        this.db.clearAndFree();
    }

    pub fn deinit(this:*DB) void {
        this.clear() catch |e| @panic(@errorName(e));
        this.db.deinit();
    }

    pub fn mk_entry(
        this: *DB,
        id:[]const u8,
        note: []const u8,
        file: File,
        compression: globs.compression,
        encryption: struct { enabled:bool, key:?[32]u8 },
    ) !void {
        const n:Note = .{
            .content = try this.alloc.dupe(u8, note),
            .file = .{
                .magic = file.magic,
                .is_file = file.is_file,
                .typ = file.typ,
                .size = file.size,
                .comment = try this.alloc.dupe(u8, file.comment),
                .name = try this.alloc.dupe(u8, file.name),
            },
            .compression = compression,
            .encryption = .{
                .enabled = encryption.enabled,
                .key = if (encryption.key) |h| (try this.alloc.dupe(u8, &h))[0..32].* else null,
            },
        };

        const id_allocated = try this.alloc.dupe(u8, id); 
        try this.db.put(id_allocated, n);
    }

    pub fn sanity_check(
        this:*DB,
    ) !void  {
        try log.deb("performing db tests", .{});
        var arena = std.heap.ArenaAllocator.init(globs.alloc);
        const allocator = arena.allocator();
        const rand = std.crypto.random;
        for (0..1000) |_| {
            var note = try allocator.alloc(u8, rand.int(u8));
            _ = &note;
            for (note) |*b| {
                b.* = rand.intRangeAtMost(u8, '0', '~');
            }
            var id = try allocator.alloc(u8, rand.int(u8));
            _ = &id;
            for (id) |*b| {
                b.* = rand.intRangeAtMost(u8, '0', '~');
            }
            try log.deb(
                "\t\x1b[33mnote{{\x1b[0m{s}\x1b[33m}} id{{\x1b[0m{s}\x1b[33m}}\x1b[0m",
                .{note, id}
            );
            try this.mk_entry(id, note, .{
                .typ = "",
                .is_file = false,
                .magic = hlp.text_magic(),
                .size = note.len,
                .name = "",
                .comment = "",
            }, .none, .{ .enabled = false, .key = null, });
            const n = try this.retrieve_entry(
                id, null, allocator, rand.boolean()
            );
            std.debug.assert(std.mem.eql(u8, n.content, note));
        }
        try this.clear();
    }
};
