const std = @import("std");
const hlp = @import("helpers.zig");
const globs = @import("global_types.zig");

const log = hlp.log;
const Mime = globs.Mime;

pub const list = [_][2][]const u8 {
    .{ "BM", "BMP" },
    .{ "MZ", "Windows executable" },
    .{ "%PDF", "PDF" },
    .{ "\x89PNG", "PNG" },
    .{ "\x7fELF", "ELF executable" },
    .{ "\x50\x4b\x03\x04", "zip" },
    .{ "\xff\xd8\xff", "jpeg" },
    .{ "\x47\x49\x46\x38", "GIF" },
    .{ "SQLite format 3\x00", "SQLite database file" },
    .{ "\x43\x41\x54\x20", "EA Interchange Format File (IFF)_3" },
    .{ "\x4D\x41\x54\x4C\x41\x42\x20\x35\x2E\x30\x20\x4D\x41\x54\x2D\x66\x69\x6C\x65", "MATLAB v5 workspace" },
};
