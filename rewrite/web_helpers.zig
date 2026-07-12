const std = @import("std");
const zh = @import("zig_http");

const Connection:type = zh.types.Connection;
const HandleResult:type = zh.types.HandleResult;

pub fn handleBots(conn:*Connection) !?HandleResult {
    const agent_raw = conn.parsed.headers.get("User-Agent") orelse return null;
    const agent:[]u8 = @constCast(agent_raw);
    for (agent) |*b|
        b.* = std.ascii.toLower(b.*);

    // TODO: may be neat to fetch these dynamically
    const Bots = enum {
        whatsapp, twitterbot, slackbot, applebot, bingpreview,
        telegrambot, linkedinbot, facebookexternalhit, googlebot,
    };
    if (std.meta.stringToEnum(Bots, agent)) |_| {
        const page = 
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\  <head>
            \\    <meta property="og:title" content="tmpNote">
            \\    <meta property="og:description" content="a temporary, self deleting note">
            \\    <!-- TODO: <meta property="og:image" content="some_image_url"> -->
            \\    <title>tmpNote</title>
            \\  </head> 
            \\  <body>
            \\    <h1>note protected from bot</h1>
            \\  </body>
            \\</html>
        ;
        return conn.sendStringClosing(page, .{}) catch .done(.{});
    }

    return null;
}
