const std = @import("std");
const Rgba = @import("zignal").Rgba(u8);
const Image = @import("zignal").Image(Rgba);
const Canvas = @import("zignal").Canvas(Rgba);

const js = @import("./lib/js.zig");
const game_mod = @import("game.zig");
const render = @import("render.zig");
const utils = @import("utils.zig");

export const img_size: u32 = game_mod.img_size;
export const img_buffer_size = img_size * img_size * @sizeOf(Rgba);
export var img_buffer: [img_buffer_size]u8 align(@alignOf(Rgba)) = undefined;

export var input: u8 = 0;
export var score: [2]u8 = .{ 0, 0 };

var cvs: Canvas = undefined;
var gpa = std.heap.wasm_allocator;
var game: game_mod.Game = undefined;
var background: render.Background = undefined;
var clock: utils.Clock = undefined;

export fn init() void {
    const img: Image = .initFromBytes(img_size, img_size, &img_buffer);
    cvs = .init(gpa, img);
    clock = .init();

    background = render.Background.init(gpa) catch |err| {
        js.err(err);
        return;
    };

    background.paint(cvs, .{}) catch |err| {
        js.err(err);
        return;
    };

    score = .{ 0, 0 };
    game = .init();
}

export fn loop() void {
    const clock_info = clock.call();

    if (game.waiting) {
        if (input != 0) game.waiting = false;
    } else {
        game.movePlayer(input, clock_info.delay);
        game.moveOpponent(clock_info.delay);
        game.moveBall(clock_info.delay, &score);
    }

    background.paint(cvs, clock_info) catch |err| {
        js.err(err);
        return;
    };
    render.drawGame(cvs, game);
}

export fn setAiBehavior(mode: u8) void {
    switch (mode) {
        0 => game.setAiMode(.dumb),
        1 => game.setAiMode(.normal),
        2 => game.setAiMode(.expert),
        else => return,
    }
}
