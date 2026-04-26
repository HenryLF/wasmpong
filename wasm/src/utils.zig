const std = @import("std");
const js = @import("./lib/js.zig");

pub const ClockInfo = struct {
    delay: f32 = 0,
    elapsed: f32 = 0,
    now: f32 = 0,
};

pub const Clock = struct {
    t0: f64,
    last_call: f64,

    pub fn init() Clock {
        const now = js.now() / 1e3;
        return .{ .t0 = now, .last_call = now };
    }

    pub fn call(self: *Clock) ClockInfo {
        const now = js.now() / 1e3;
        const delay = now - self.last_call;
        self.last_call = now;
        return .{
            .now = @floatCast(now),
            .delay = @floatCast(delay),
            .elapsed = @floatCast(now - self.t0),
        };
    }
};
