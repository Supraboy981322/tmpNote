const std = @import("std");
const hlp = @import("helpers.zig");
const globs = @import("global_types.zig");

const log = hlp.log;
const Mime = globs.Mime;

pub fn chk_mime(b_s:[]const u8) Mime {
    var is_text:bool = true;
    for (b_s) |b| {
        if (!std.ascii.isAscii(b)) { is_text = false ; break; }
    }
    log.deb("is_text == {}", .{is_text}) catch {};
    const mime = if (is_text) "text/plain" else "";
    const list = [_][]const u8 {
        "BM",
        "MZ",
        "%PDF",
        "\x89PNG",
        "\x7fELF",
        "\x50\x4b\x03\x04",
        "\xff\xd8\xff\xfe0",
        "GIF87a",
        "GIF89a",
        "SQLite format 3\x00",
    };
    var idx:usize = 0;
    for (list) |m| {
        if (hlp.starts_with(b_s, m)) break;
        idx += 1;
    }
    log.deb("mime idx: {d}", .{idx}) catch {};
    log.deb("mime: {s}", .{mime}) catch {};
    return Mime{
        .is_text = true,
        .mime = mime
    };
}
