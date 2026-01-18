const std = @import("std");
const hlp = @import("helpers.zig");
const globs = @import("global_types.zig");

const log = hlp.log;
const Mime = globs.Mime;

const list = [_][2][]const u8 {
    .{ "BM", "BMP" },
    .{ "MZ", "Windows executable" },
    .{ "%PDF", "PDF" },
    .{ "\x89PNG", "PNG" },
    .{ "\x7fELF", "ELF executable" },
    .{ "\x50\x4b\x03\x04", "zip" },
    .{ "\xff\xd8\xff", "jpeg" },
    .{ "\x47\x49\x46\x38", "GIF" },
    .{ "SQLite format 3\x00", "SQLite database file" },
};

pub fn chk_mime(b_s:[]const u8) Mime {
    var is_text:bool = true;
    for (b_s) |b| {
        if (!std.ascii.isAscii(b)) { is_text = false ; break; }
    }
    log.deb("is_text == {}", .{is_text}) catch {};
    var mime:[]const u8 = if (is_text) "text/plain" else "";
    for (list) |p| {
        if (mime.len > 0) break;
        const mag = p[0];
        const mim = p[1];
        if (hlp.starts_with(b_s, mag)) { mime = mim; break; }
    }
    log.deb("mime: {s}", .{mime}) catch {};
    return Mime{
        .is_text = true,
        .mime = mime
    };
}
