const c = @cImport({
    @cInclude("types.h");
    @cInclude("stat.h");
    @cInclude("user.h");
});

export fn main(_: c_int, _: [*c][*c]u8) callconv(.C) c_uint {
    //const string = "printing from zig code...";
    //t_ = c.write(1, @ptrCast(*const anyopaque, string), string.len);
    return 0;
}
