const std = @import("std");
const Rgba = @import("zignal").Rgba(u8);
const Image = @import("zignal").Image(Rgba);
const Canvas = @import("zignal").Canvas(Rgba);
const PerlinOptions = @import("zignal").PerlinOptions(f32);
const perlin = @import("zignal").perlin;

const game_mod = @import("game.zig");
const utils = @import("utils.zig");

const img_size = game_mod.img_size;
const img_scale = game_mod.img_scale;

const perlin_options: PerlinOptions = .{};

fn perlinNoise(x: f32, y: f32, z: f32) f32 {
    const noise = perlin(f32, x, y, z, perlin_options);
    return std.math.clamp((noise + perlin_options.amplitude) / (2 * perlin_options.amplitude), 0, 1);
}

pub const Background = struct {
    const scale: f32 = 16;
    const time_scale: f32 = 2;
    img: Image,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Background {
        const img: Image = try .init(
            alloc,
            @intFromFloat(img_size / Background.scale),
            @intFromFloat(img_size / Background.scale),
        );
        img.fill(Rgba.black);
        return .{ .img = img, .alloc = alloc };
    }

    pub fn paint(self: *Background, canvas: Canvas, clock_info: utils.ClockInfo) !void {
        var iter = self.img.pixels();
        const now: f32 = clock_info.now / Background.time_scale;
        while (iter.next()) |pixel| {
            const x: f32 = @as(f32, @floatFromInt(iter.current_col)) * img_scale / Background.scale;
            const y: f32 = @as(f32, @floatFromInt(iter.current_row)) * img_scale / Background.scale;
            const t = perlinNoise(x, y, now);
            pixel.* = .{
                .a = 255,
                .r = @intFromFloat(80.0 + 140.0 * t),
                .g = @intFromFloat(120.0 + 120.0 * t),
                .b = @intFromFloat(150.0 - 20.0 * t),
            };
        }
        var scaled = try self.img.scale(self.alloc, Background.scale, .bilinear);
        defer scaled.deinit(self.alloc);
        canvas.drawImage(scaled, .init(.{ 0, 0 }), null, .normal);
    }
};

pub fn drawGame(canvas: Canvas, game: game_mod.Game) void {
    canvas.fillRectangle(game.player.rect(), Rgba.red, .soft);
    canvas.fillRectangle(game.opponent.rect(), Rgba.black, .soft);
    canvas.fillRectangle(game.ball.rect(), Rgba.blue, .soft);
}
