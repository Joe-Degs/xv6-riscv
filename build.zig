const std = @import("std");
const builtin = std.builtin;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

const user_source_files = &[_][]const u8{
    "test",
};

const c_deps = &[_][]const u8{
    "user/ulib.c",
    "user/printf.c",
    "user/umalloc.c",
};

const c_flags = &[_][]const u8{
    "-Werror",
    "-fno-omit-frame-pointer",
    "-mcmodel=medany",
    "-ffreestanding",
    "-fno-common",
    "-nostdlib",
    "-mno-relax",
    "-I.",
    "-Ikernel",
    "-Iuser",
    "-fno-stack-protector",
    "-fno-pie",
};

const asm_deps = &[_][]const u8{
    "user/usys.S",
};

pub fn build(b: *std.Build) void {
    const target = CrossTarget{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .gnueabihf,
        .cpu_model = .{ .explicit = &Target.riscv.cpu.sifive_s54 },
    };
    const optimize = builtin.Mode.Debug;
    b.resolveInstallPrefix("", .{ .exe_dir = "user" });

    inline for (user_source_files) |source| {
        const exe = b.addExecutable(.{
            .name = "_" ++ source,
            .root_source_file = .{ .path = "src/" ++ source ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        //exe.disable_stack_probing = true;
        // exe.linkLibC();
        exe.addIncludePath("kernel");
        exe.addIncludePath("user");
        exe.addCSourceFiles(c_deps, c_flags);
        inline for (asm_deps) |dep| exe.addAssemblyFile(dep);
        exe.setLinkerScriptPath(.{ .path = "user/user.ld" });

        b.installArtifact(exe);
    }
}
