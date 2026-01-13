const std = @import("std");

pub fn build(b: *std.Build) void {
    const bin = b.addExecutable(.{
        .name = "tmpNote",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });
    bin.linkLibC();
    b.installArtifact(bin);
    
    const run_bin = b.addRunArtifact(bin);

    const run_step = b.step("run", "execute the program");
    run_step.dependOn(&run_bin.step);
}
