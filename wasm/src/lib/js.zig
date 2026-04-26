const std = @import("std");

extern fn jsLog(ptr: [*]const u8, len: usize) void;
extern fn jsError(ptr: [*]const u8, len: usize) void;

pub extern fn now() f64;
pub extern fn rand() f64;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch |e| return err(e);
    jsLog(msg.ptr, msg.len);
}

pub fn err(e: anyerror) void {
    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "WASM error :: {s}", .{@errorName(e)}) catch return;
    jsError(msg.ptr, msg.len);
}
