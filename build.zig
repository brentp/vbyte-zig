const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("vbyte-zig", "src/main.zig");
    lib.linkLibC();
    lib.linkLibCpp();
    lib.addIncludeDir("src/");
    lib.addIncludeDir("src/libvbyte");
    lib.addCSourceFile("src/libvbyte/varintdecode.c", &[_][]const u8{});
    lib.addCSourceFile("src/libvbyte/vbyte.cc", &[_][]const u8{});

    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.linkLibC();
    main_tests.linkLibCpp();
    main_tests.setBuildMode(mode);
    main_tests.addIncludeDir("src/");
    main_tests.addIncludeDir("src/libvbyte");
    main_tests.addCSourceFile("src/libvbyte/varintdecode.c", &[_][]const u8{});
    main_tests.addCSourceFile("src/libvbyte/vbyte.cc", &[_][]const u8{});

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
