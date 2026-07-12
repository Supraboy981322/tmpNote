const std = @import("std");
const zh = @import("zig_http");
const types = @import("types.zig");
const hlp = @import("helpers.zig");
const State = @import("state.zig");
const DB = @import("db.zig");

const assert = std.debug.assert;
const HandleResult:type = zh.types.HandleResult;
const Connection:type = zh.types.Connection;
const Note:type = types.Note;

pub const Action = std.meta.FieldEnum(ApiResponse);

pub const ApiResponse = union(enum) {
    view:Note, //note
    new:[DB.ENCODED_ID_LEN]u8, //id
    help:HandleResult,

    err:Err,
    pub const Err = struct{
        err:anyerror,
        msg:[]const u8,
        status:?std.http.Status
    };
};

pub fn handle(conn:*Connection, requested_path:[]const []const u8) !HandleResult {
    assert(std.mem.eql(u8, requested_path[0], "api"));
    const state:*State = @alignCast(@ptrCast(conn.ctx));

    if (requested_path.len < 2) return try conn.sendStringClosing(
        "invalid request (see '/api/help')", .{ .status = .bad_request }
    );

    const action = std.meta.stringToEnum(Action, requested_path[1]);
    if (action == null) return try conn.sendStringClosing(
        "invalid request (see '/api/help')", .{ .status = .bad_request }
    );

    switch (try do(action.?, conn)) {
        .help => |ret| return ret,
        .new => |id| {
            const empty = "{ \"id\": \"\" }";
            const offset = 9;
            comptime assert(empty[offset] == '"'); //offset into json template changed
            const len = empty.len + id.len;
            var buf:[len]u8 = (empty[0..offset] ++ ("\x00" ** id.len) ++ empty[offset..]).*;
            buf[offset..id.len+offset].* = id[0..id.len].*;
            return try conn.sendStringClosing(&buf, .{ .status = .ok });
        },
        .view => |note| {
            const info = note.info();
            var formatter = std.json.fmt(info, .{
                .whitespace = .minified,
                .escape_unicode = true,
            });

            var json:std.Io.Writer.Allocating = .init(conn.alloc);
            defer json.deinit();
            try formatter.format(&json.writer);

            var len_buf:[21]u8 = undefined;
            const len_str_end = std.fmt.printInt(&len_buf, note.content.len, 10, .lower, .{});

            try conn.beginResponse(.ok, .fromMap(&.{
                .{ "Content-Length", len_buf[0..len_str_end] },
                .{ "Note-Info", json.written() },
            }));

            const key = try state.get(conn.io, .key);
            hlp.xorInPlace(note.content, key);
            try conn.writer.interface.writeAll(note.content);
            try conn.writer.interface.flush();

            return try conn.endResponse();
        },
        .err => |info| {
            var buf:[1024]u8 = undefined;
            const rendered = try std.fmt.bufPrint(&buf,
                \\{{ "{t}": "{s}" }}
            , .{ info.err, info.msg });
            const status:std.http.Status = if (info.status) |s| s else .bad_request;
            return try conn.sendStringClosing(rendered, .{ .status = status });
        },
    }

    unreachable;
}

pub fn do(what:Action, conn:*Connection) !ApiResponse {
    return switch (what) {
        .view => view(conn),
        .new => new(conn),
        .help => help(conn),
        .err => unreachable,
    };
}

pub fn new(conn:*Connection) !ApiResponse {
    const state:*State = @alignCast(@ptrCast(conn.ctx));

    var output:std.Io.Writer.Allocating = .init(conn.alloc);
    defer output.deinit();
    const encrypt = blk: {
        const str = conn.parsed.headers.get("Use-Encryption") orelse "false";
        const which = std.meta.stringToEnum(enum{true,false}, str) orelse return .{
            .err = .{
                .err = error.InvalidOption,
                .msg = "'Use-Encryption' header must be either 'true' or 'false'",
                .status = .bad_request,
            },
        };
        break :blk which == .true;
    };

    const length = blk: {
        const str = conn.parsed.headers.get("Content-Length") orelse return .{
            .err = .{
                .err = error.IncompleteRequest,
                .msg = "'Content-Length' header must be provided",
                .status = .length_required,
            },
        };
        break :blk std.fmt.parseInt(usize, str, 10) catch return .{
            .err = .{
                .err = error.InvalidHeader,
                .msg = "'Content-Length' header isn't a valid base-10 number",
                .status = .length_required,
            },
        };
    };
    if (length > (try state.get(conn.io, .opts)).max_note_length) return .{
        .err = .{
            .err = error.NoteTooLarge,
            .msg = "note exceeds configured limit",
            .status = .payload_too_large,
        },
    };
    if (length == 0) return .{
        .err = .{
            .err = error.EmptyNote,
            .msg = "notes cannot be empty",
            .status = .bad_request,
        }
    };

    _ = conn.reader.interface.stream(
        &output.writer, .limited(length)
    ) catch |e| switch (e) {
        error.EndOfStream => return .{
            .err = .{
                .err = error.EndOfStream,
                .msg = "stream ended unexpectedly",
                .status = .bad_request,
            },
        },
        else => return .{
            .err = .{
                .err = e,
                .msg = "failed to read stream",
                .status = .internal_server_error,
            },
        },
    };

    const content = output.written();
    const key = try state.get(conn.io, .key);
    hlp.xorInPlace(content, key);

    const note:Note = .{
        .content = content,
        .file = null,
        .compression = null,
        .encrypted = encrypt,
    };

    const id = try state.db.put(conn.io, note);

    return .{ .new = id };
}

pub fn help(conn:*Connection) !ApiResponse {
    const msg = comptime blk: {
        var res:[]const u8 = &.{};

        res = res ++ "{ \"actions\": [ ";
        for (@typeInfo(ApiResponse).@"union".fields) |field| {
            const name = field.name;
            const as_enum = std.meta.stringToEnum(Action, field.name).?;
            const response = switch (as_enum) {
                .help => "this JSON blob",
                .view => "note information",
                .new => "the corresponding ID for the new note",
                .err => continue,
            };
            res = res
                ++ "{ "
                ++   "\"name\": \"" ++ name ++ "\","
                ++   "\"response\": \"" ++ response ++ "\""
                ++ "},"
            ;
        }
        res = res[0..res.len-1] ++ " ],";

        break :blk res[0..res.len-1] ++ " }";
    };
    return .{ .help = try conn.sendStringClosing(msg, .{ .status = .ok }) };
}

pub fn view(conn:*Connection) !ApiResponse {
    const state:*State = @alignCast(@ptrCast(conn.ctx));

    const id = conn.parsed.params.get("id") orelse return .{
        .err = .{
            .err = error.MissingID,
            .msg = "an id is required to retrieve a note",
            .status = .bad_request,
        },
    };

    const note = try state.db.getBase64(
        conn.io, id, .{ .destroy = conn.alloc }
    ) orelse return .{
        .err = .{
            .err = error.NoteNotFound,
            .msg = "no note found with provided id",
            .status = .not_found,
        }
    };

    return .{ .view = note };
}
