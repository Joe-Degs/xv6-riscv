const std = @import("std");
const builtin = std.builtin;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

const target = CrossTarget{
    .cpu_arch = .riscv64,
    .os_tag = .freestanding,
    .abi = .none,
    .cpu_model = .{ .explicit = &Target.riscv.cpu.sifive_s54 },
};

const optimize = builtin.Mode.ReleaseSmall;

pub fn build(b: *std.Build) !void {
    const want_gdb = b.option(bool, "gdb", "Enable the QEMU stub for GDB") orelse false;
    const num_cpu = b.option(usize, "ncpu", "Number of CPUs to use") orelse 3;
    const gcc_mkfs = b.option(bool, "gcc-mkfs", "Build mkfs with gcc") orelse false;

    const bin_dir = b.pathJoin(&[_][]const u8{ "zig-out", "bin" });

    // kernel/kernel
    const kernel = b.addExecutable(.{
        .name = "kernel",
        .target = target,
        .optimize = builtin.Mode.ReleaseFast,
    });
    kernel.link_z_max_page_size = 4096;
    kernel.setLinkerScriptPath(.{ .path = b.pathJoin(&[_][]const u8{ "kernel", "kernel.ld" }) });
    kernel.addIncludePath("kernel");
    for (kernel_sources) |ksrc| {
        var path = b.pathJoin(&.{ "kernel", ksrc });
        var split = std.mem.splitBackwardsScalar(u8, ksrc, '.');
        if (std.mem.eql(u8, split.first(), "S")) {
            kernel.addAssemblyFile(path);
            continue;
        }
        kernel.addCSourceFile(path, &cflags);
    }
    b.installArtifact(kernel);

    // compile the init process
    // TODO(joe-degs): this is still incomplete, it needs the objcopy part to work
    // correctly
    const initcode = b.addExecutable(.{
        .name = "initcode.exe",
        .target = target,
        .optimize = builtin.Mode.ReleaseSmall,
    });
    initcode.link_z_max_page_size = 4096;
    initcode.entry_symbol_name = "start";
    initcode.strip = true;
    initcode.code_model = .medium;
    initcode.stack_protector = false;
    initcode.pie = false;
    initcode.addIncludePath("kernel");
    initcode.addAssemblyFile(b.pathJoin(&[_][]const u8{ "user", "initcode.S" }));
    b.installArtifact(initcode);

    const objcopy = initcode.addObjCopy(.{
        .basename = "initcode",
        .format = .bin,
        .only_section = ".text",
    });
    const run_objcopy = b.step("initcode", "Run objcopy on initcode");
    run_objcopy.dependOn(&initcode.step);
    run_objcopy.dependOn(&objcopy.step);

    // build userspace programs
    const usys_source = blk: {
        var code: u8 = undefined;
        const usys_contents = b.execAllowFail(
            &[_][]const u8{
                "perl",
                b.pathFromRoot("user/usys.pl"),
            },
            &code,
            .Ignore,
        ) catch |err| @panic(b.fmt("failed to create usys.S: {}", .{err}));

        break :blk std.build.Step.WriteFile.create(b).add("usys.S", usys_contents);
    };

    const user_lib = b.addStaticLibrary(.{
        .name = "user",
        .target = target,
        .optimize = optimize,
    });
    user_lib.addIncludePath("kernel");
    user_lib.addCSourceFiles(&cdeps, &cflags);
    user_lib.addAssemblyFileSource(usys_source);
    b.installArtifact(user_lib);

    // compile c programs
    inline for (user_programs) |source| {
        const bin = b.addExecutable(.{
            .name = "_" ++ source,
            .target = target,
            .optimize = optimize,
        });
        bin.link_z_max_page_size = 4096;
        bin.setLinkerScriptPath(.{ .path = b.pathJoin(&[_][]const u8{ "user", "user.ld" }) });
        bin.addIncludePath("kernel");
        bin.addIncludePath("user");
        bin.addCSourceFile(b.pathJoin(&[_][]const u8{ "user", source ++ ".c" }), &cflags);
        bin.linkLibrary(user_lib);
        b.installArtifact(bin);
    }

    // compile zig programs
    inline for (zig_programs) |source| {
        const bin = b.addExecutable(.{
            .name = "_" ++ source,
            .root_source_file = .{ .path = b.pathJoin(&[_][]const u8{ "src", source ++ ".zig" }) },
            .target = target,
            .optimize = optimize,
        });
        bin.addIncludePath("kernel");
        bin.addIncludePath("user");
        bin.linkLibrary(user_lib);
        bin.setLinkerScriptPath(.{ .path = b.pathJoin(&[_][]const u8{ "user", "user.ld" }) });
        b.installArtifact(bin);
    }

    // mkfs/mkfs
    const mkfs = b.addExecutable(.{
        .name = "mkfs",
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    mkfs.addCSourceFile(b.pathJoin(&[_][]const u8{ "mkfs", "mkfs.c" }), &[_][]const u8{
        "-Wall", "-Werror", "-Wreturn-type", "-I.",
    });
    mkfs.linkLibC();
    b.installArtifact(mkfs);

    // use gcc to compile mkfs because we are getting a illegal instruction
    // when we compile with the default toolchain in zig
    var gcc_build_mkfs: *std.Build.Step.Run = undefined;
    const mkfs_bin = b.pathJoin(&[_][]const u8{ bin_dir, "mkfs" });
    if (gcc_mkfs) {
        var build_args = std.ArrayList([]const u8).init(b.allocator);
        try build_args.appendSlice(&[_][]const u8{
            "gcc",
            "-Wall",
            "-Werror",
            "-I.",
            "-o",
            mkfs_bin,
            "mkfs/mkfs.c",
        });
        gcc_build_mkfs = b.addSystemCommand(build_args.items);
    }

    const image_path = b.pathJoin(&[_][]const u8{ bin_dir, "fs.img" });

    const mk_img = b.step("fs.img", "Create the filesytem image");
    var mkfs_cmd = std.ArrayList([]const u8).init(b.allocator);
    try mkfs_cmd.appendSlice(&[_][]const u8{
        mkfs_bin,
        image_path,
        "README",
    });
    inline for (zig_programs ++ user_programs) |prog| {
        try mkfs_cmd.append(b.pathJoin(&[_][]const u8{ bin_dir, "_" ++ prog }));
    }
    const run_mkfs = b.addSystemCommand(mkfs_cmd.items);
    if (gcc_mkfs) {
        run_mkfs.step.dependOn(&gcc_build_mkfs.step);
    } else {
        run_mkfs.step.dependOn(&mkfs.step);
    }
    mk_img.dependOn(&run_mkfs.step);

    const kernel_bin_dir = b.pathJoin(&[_][]const u8{ bin_dir, "kernel" });

    const qemu = b.step("qemu", "Run OS in qemu");
    var qemu_args = std.ArrayList([]const u8).init(b.allocator);
    try qemu_args.appendSlice(&[_][]const u8{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-bios",
        "none",
        "-kernel",
        kernel_bin_dir,
        "-m",
        "128M",
        "-smp",
        b.fmt("{d}", .{num_cpu}),
        "-nographic",
        "-global",
        "virtio-mmio.force-legacy=false",
        "-drive",
        b.fmt("file={s},if=none,format=raw,id=x0", .{image_path}),
        "-device",
        "virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0",
    });
    if (want_gdb) {
        const port = 60009;
        const template =
            \\set confirm off
            \\set architecture riscv:rv64
            \\target remote 127.0.0.1:{d}
            \\symbol-file {s}
            \\set disassemble-next-line auto
            \\set riscv use-compressed-breakpoints yes
        ;
        const file = try std.fs.createFileAbsolute(b.pathFromRoot(".gdbinit"), .{});
        defer file.close();
        try file.writeAll(b.fmt(template, .{ port, kernel_bin_dir }));
        try qemu_args.appendSlice(&[_][]const u8{ "-S", "-gdb", b.fmt("tcp::{d}", .{port}) });
        std.debug.print("GdbStub -> tcp::{d}\n", .{port});
    }
    const run_qemu = b.addSystemCommand(qemu_args.items);
    qemu.dependOn(&run_qemu.step);
    if (gcc_mkfs) {
        run_qemu.step.dependOn(&gcc_build_mkfs.step);
    } else {
        run_qemu.step.dependOn(&mkfs.step);
    }
    run_qemu.step.dependOn(&run_mkfs.step);
}

const cdeps = [_][]const u8{
    "user/ulib.c",
    "user/printf.c",
    "user/umalloc.c",
};

const zig_programs = [_][]const u8{
    "test",
};

const kernel_sources = [_][]const u8{
    "entry.S",
    "start.c",
    "console.c",
    "printf.c",
    "uart.c",
    "kalloc.c",
    "spinlock.c",
    "string.c",
    "main.c",
    "vm.c",
    "proc.c",
    "swtch.S",
    "trampoline.S",
    "trap.c",
    "syscall.c",
    "sysproc.c",
    "bio.c",
    "fs.c",
    "log.c",
    "sleeplock.c",
    "file.c",
    "pipe.c",
    "exec.c",
    "sysfile.c",
    "kernelvec.S",
    "plic.c",
    "virtio_disk.c",
};

const user_programs = [_][]const u8{
    "cat",
    "echo",
    "forktest",
    "grep",
    "init",
    "kill",
    "ln",
    "ls",
    "mkdir",
    "rm",
    "sh",
    "stressfs",
    "usertests",
    "grind",
    "wc",
    "zombie",
};

const cflags = [_][]const u8{
    // "-Werror", TODO(joe-degs): change all the old style designation to the new one
    "-fno-omit-frame-pointer",
    "-mcmodel=medany",
    "-ffreestanding",
    "-fno-common",
    "-nostdlib",
    "-mno-relax",
    "-I.",
    // "-Ikernel",
    // "-Iuser",
    "-fno-stack-protector",
    "-fno-pie",
    // "-no-pie",
};
