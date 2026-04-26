const std = @import("std");
const Rect = @import("zignal").Rectangle(f32);
const js = @import("./lib/js.zig");

const Vect = @Vector(2, f32);
const Pi: f64 = std.math.pi;

pub const img_size: u32 = 256;
pub const img_scale: f32 = @floatFromInt(img_size - 1);

pub const BarPosition = enum { top, bottom };

pub const Bar = struct {
    width: f32 = 0.1,
    height: f32 = 0.02,
    position: f32 = 0.5,
    velocity: f32 = 0,
    accel: f32 = 2,
    friction: f32 = 0.05,
    momentum_transfer: f32 = 0.5,
    h_offset: f32,

    pub fn init(y: BarPosition) Bar {
        const height: f32 = 0.02;
        return .{ .h_offset = switch (y) {
            .top => height * img_scale,
            .bottom => (1.0 - height) * img_scale,
        } };
    }

    pub fn rect(self: Bar) Rect {
        return .initCenter(
            self.position * img_scale,
            self.h_offset,
            self.width * img_scale,
            self.height * img_scale,
        );
    }

    pub fn applyForce(self: *Bar, sign: f32, dt: f32) void {
        self.velocity += sign * self.accel * dt;
        self.velocity *= std.math.pow(f32, self.friction, dt);
        const half_w = self.width / 2.0;
        self.position = std.math.clamp(
            self.position + self.velocity * dt,
            half_w,
            1.0 - half_w,
        );
    }
};

pub const Ball = struct {
    position: Vect = Vect{ 0.5, 0.5 },
    velocity: Vect,
    radius: f32 = 0.01,
    speed: f32 = 0.5,

    pub fn init(rand: f64) Ball {
        var b: Ball = .{ .velocity = undefined };
        const ang: f32 = @floatCast(rand * Pi);
        b.velocity = Vect{ @cos(ang) * b.speed, @sin(ang) * b.speed };
        return b;
    }

    pub fn rect(self: Ball) Rect {
        const pos = self.position * @as(Vect, @splat(img_scale));
        const diam = self.radius * 2.0 * img_scale;
        return .initCenter(pos[0], pos[1], diam, diam);
    }
};

pub const AiMode = enum { dumb, normal, expert };

pub const InputDirection = enum { left, right };

pub fn processInput(input: u8) ?InputDirection {
    if (input & 0x01 != 0) return .left;
    if (input & 0x10 != 0) return .right;
    return null;
}

fn predictLanding(ball: Ball, opponent_y: f32, opponent_hh: f32) f32 {
    if (ball.velocity[1] >= 0) return ball.position[0];
    const r = ball.radius;
    const target_y = opponent_y + opponent_hh + r;
    if (ball.position[1] <= target_y) return ball.position[0];
    const t = (ball.position[1] - target_y) / (-ball.velocity[1]);
    const min_x = r;
    const max_x = 1.0 - r;
    const width = max_x - min_x;
    var x = (ball.position[0] - min_x) + ball.velocity[0] * t;
    x = @mod(x, 2.0 * width);
    if (x > width) x = 2.0 * width - x;
    return x + min_x;
}

extern fn updateScore() void;

pub const Game = struct {
    player: Bar = .init(.bottom),
    opponent: Bar = .init(.top),
    ball: Ball,
    ai_mode: AiMode = .dumb,
    waiting: bool = true,

    pub fn init() Game {
        const rand = js.rand();
        updateScore();
        return .{ .ball = .init(rand) };
    }

    fn resetBall(self: *Game) void {
        updateScore();
        self.ball = Ball.init(js.rand());
        self.waiting = true;
    }

    pub fn setAiMode(self: *Game, mode: AiMode) void {
        self.ai_mode = mode;
    }

    pub fn movePlayer(self: *Game, input: u8, dt: f32) void {
        const sign: f32 = if (processInput(input)) |dir| switch (dir) {
            .left => -1,
            .right => 1,
        } else 0;
        self.player.applyForce(sign, dt);
    }

    pub fn moveOpponent(self: *Game, dt: f32) void {
        const target_x: f32 = switch (self.ai_mode) {
            .dumb => target: {
                const half_w = self.opponent.width / 2.0;
                if (self.opponent.position <= half_w) break :target 1.0 - half_w;
                if (self.opponent.position >= 1.0 - half_w) break :target half_w;
                break :target if (self.opponent.velocity >= 0) 1.0 else 0.0;
            },
            .normal => self.ball.position[0],
            .expert => predictLanding(
                self.ball,
                self.opponent.h_offset / img_scale,
                self.opponent.height / 2.0,
            ),
        };
        const sign = std.math.sign(target_x - self.opponent.position);
        self.opponent.applyForce(sign, dt);
    }

    pub fn moveBall(self: *Game, dt: f32, score: *[2]u8) void {
        self.ball.position += self.ball.velocity * @as(Vect, @splat(dt));

        const bx = self.ball.position[0];
        const by = self.ball.position[1];
        const r = self.ball.radius;

        if (bx - r <= 0 or bx + r >= 1) {
            self.ball.velocity[0] = -self.ball.velocity[0];
            self.ball.position[0] = std.math.clamp(bx, r, 1.0 - r);
        }

        const player_y = self.player.h_offset / img_scale;
        const player_hh = self.player.height / 2.0;
        if (by + r >= player_y - player_hh and
            @abs(bx - self.player.position) < self.player.width / 2.0 + r)
        {
            self.ball.velocity *= @as(Vect, @splat(1.05));
            self.ball.velocity[1] = -@abs(self.ball.velocity[1]);
            self.ball.velocity[0] += self.player.velocity * self.player.momentum_transfer;
            self.ball.position[1] = player_y - player_hh - r;
        }

        const opponent_y = self.opponent.h_offset / img_scale;
        const opponent_hh = self.opponent.height / 2.0;
        if (by - r <= opponent_y + opponent_hh and
            @abs(bx - self.opponent.position) < self.opponent.width / 2.0 + r)
        {
            self.ball.velocity *= @as(Vect, @splat(1.05));
            self.ball.velocity[1] = @abs(self.ball.velocity[1]);
            self.ball.velocity[0] += self.opponent.velocity * self.opponent.momentum_transfer;
            self.ball.position[1] = opponent_y + opponent_hh + r;
        }

        if (by - r <= 0) {
            score[0] +|= 1; // player scores (opponent missed)
            self.resetBall();
        } else if (by + r >= 1) {
            score[1] +|= 1; // opponent scores (player missed)
            self.resetBall();
        }
    }
};
