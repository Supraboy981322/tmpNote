const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "tmpNote",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });
    exe.linkLibC();
    b.installArtifact(exe);
    
    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "execute the program");
    run_step.dependOn(&run_exe.step);
}
