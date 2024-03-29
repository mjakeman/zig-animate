const std = @import("std");

inline fn clamp(x: f32, min: f32, max: f32) f32 {
    if (x < min) {
        return min;
    } else if (x > max) {
        return max;
    } else {
        return x;
    }
}

pub fn Animator(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        easing_func: *const fn (T, T, f32) T, // See zig
        start: T,
        end: T,

        pub fn init(allocator: std.mem.Allocator, start: T, end: T, easing_func: *const fn (T, T, f32) T) *Animator(T) {
            var anim = allocator.create(Animator(T)) catch @panic("Could not allocate animator");
            anim.allocator = allocator;
            anim.easing_func = easing_func;
            anim.start = start;
            anim.end = end;

            return anim;
        }

        pub fn deinit(self: *Animator(T)) void {
            self.allocator.destroy(self);
        }

        pub fn eval(animator: *const Animator(T), t: f32) T {
            return animator.easing_func(animator.start, animator.end, clamp(t, 0.0, 1.0));
        }
    };
}

pub fn animate(T: type, start: T, end: T, easing_func: fn (T, T, T) T) Animator(T) {
    return Animator(T){
        .easing_func = easing_func,
        .start = start,
        .end = end,
    };
}

// TESTS

const TestAllocator = std.heap.page_allocator;

fn EaseInCubic(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t * t * t;
}

test "f32 Animator" {
    const start = 0;
    const end = 1;

    const anim = Animator(f32).init(TestAllocator, start, end, EaseInCubic);

    try std.testing.expectEqual(EaseInCubic(start, end, 0.5), anim.eval(0.5));
    try std.testing.expectEqual(EaseInCubic(start, end, 0.25), anim.eval(0.25));
    try std.testing.expectEqual(EaseInCubic(start, end, 0.75), anim.eval(0.75));
}

const Vec2 = struct {
    x: f32,
    y: f32,
};

fn EaseInCubicVec2(start: Vec2, end: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = EaseInCubic(start.x, end.x, t),
        .y = EaseInCubic(start.y, end.y, t),
    };
}

test "Vec2 Animator" {
    const start = Vec2{ .x = 0, .y = 0 };
    const end = Vec2{ .x = 1, .y = 1 };

    const anim = Animator(Vec2).init(TestAllocator, start, end, EaseInCubicVec2);

    try std.testing.expectEqual(Vec2{ .x = 0.015625, .y = 0.015625 }, anim.eval(0.25));
    try std.testing.expectEqual(Vec2{ .x = 0.125, .y = 0.125 }, anim.eval(0.5));
    try std.testing.expectEqual(Vec2{ .x = 0.421875, .y = 0.421875 }, anim.eval(0.75));
    try std.testing.expectEqual(Vec2{ .x = 1, .y = 1 }, anim.eval(1));
}

// Just to prove you can do it
const Vec5 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    v: f32,
};

fn EaseInCubicVec5(start: Vec5, end: Vec5, t: f32) Vec5 {
    return Vec5{
        .x = EaseInCubic(start.x, end.x, t),
        .y = EaseInCubic(start.y, end.y, t),
        .z = EaseInCubic(start.z, end.z, t),
        .w = EaseInCubic(start.w, end.w, t),
        .v = EaseInCubic(start.v, end.v, t),
    };
}

test "Vec5 Animator" {
    const start = Vec5{ .x = 0, .y = 0, .z = 0, .w = 0, .v = 0 };
    const end = Vec5{ .x = 1, .y = 1, .z = 1, .w = 1, .v = 1 };

    const anim = Animator(Vec5).init(TestAllocator, start, end, EaseInCubicVec5);

    try std.testing.expectEqual(EaseInCubicVec5(start, end, 0.5), anim.eval(0.5));
    try std.testing.expectEqual(EaseInCubicVec5(start, end, 0.25), anim.eval(0.25));
    try std.testing.expectEqual(EaseInCubicVec5(start, end, 0.75), anim.eval(0.75));
}
