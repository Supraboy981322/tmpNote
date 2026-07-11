const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});


    const root = b.option([]const u8, "root", "source root directory") orelse "src";
    const bin = b.addExecutable(.{
        .name = "tmpNote",
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{ root, "main.zig" })),
            .target = target,
            .optimize = optimize,
            //.link_libc = true,
        }),
    });

    // TODO:
    //  bin.addIncludePath(b.path("include"));
    //  bin.addLibraryPath(b.path("include"));
    //  bin.addObjectFile(b.path("include/compress.a"));
    //for ([_][]const u8 {
    //    "libbrotlicommon", "libbrotlidec", "libbrotlienc"
    //}) |header| bin.root_module.linkSystemLibrary(header, .{});
    
    const zig_http = b.dependency("zig_http", .{
        .target = target,
        .optimize = optimize,
    });
    bin.root_module.addImport("zig_http", zig_http.module("zig_http"));

    b.installArtifact(bin);

    const run_bin = b.addRunArtifact(bin);
    if (b.args) |args| {
        run_bin.addArgs(args);
    }
    const run_step = b.step("run", "execute the program");
    run_step.dependOn(&run_bin.step);
}
