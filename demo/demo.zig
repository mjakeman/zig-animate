const std = @import("std");
const animate = @import("animate");

// Some misc helper classes/functions
const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

fn EaseInCubicVec4(start: Vec4, end: Vec4, t: f32) Vec4 {
    return Vec4{
        .x = animate.curves.EaseInCubic(start.x, end.x, t),
        .y = animate.curves.EaseInCubic(start.y, end.y, t),
        .z = animate.curves.EaseInCubic(start.z, end.z, t),
        .w = animate.curves.EaseInCubic(start.w, end.w, t),
    };
}

const MyObject = struct {
    value: f32,
    other_value: Vec4,

    const Self = @This();

    fn update(self: *Self, value: f32) void {
        self.value = value;
    }

    fn update_other(self: *Self, other_value: Vec4) void {
        self.other_value = other_value;
    }
};

pub fn main() !void {
    // Let's now update multiple properties of an object using the sequencer
    var testObj: MyObject = undefined;
    testObj.value = 30;
    testObj.other_value = Vec4{ .x = 10, .y = 10, .z = 10, .w = 10 };

    // Go from 30 to 50
    const valueAnim = animate.Animator(f32).init(30, 50, animate.curves.EaseInCubic);
    const valueEvent = animate.Event.create_transition(
        MyObject,
        f32,
        &testObj,
        &valueAnim,
        100,
        MyObject.update,
    );

    // Go from (10, 10, 10, 10) to (6, 4, 6, 4)
    const otherValueAnim = animate.Animator(Vec4).init(Vec4{ .x = 10, .y = 10, .z = 10, .w = 10 }, Vec4{ .x = 6, .y = 4, .z = 6, .w = 4 }, EaseInCubicVec4);
    const otherValueEvent = animate.Event.create_transition(
        MyObject,
        Vec4,
        &testObj,
        &otherValueAnim,
        100,
        MyObject.update_other,
    );

    // Create a sequencer
    var sequencer = animate.Sequencer.init(std.heap.page_allocator);
    sequencer.add_event(0, valueEvent);
    sequencer.add_event(0, otherValueEvent);

    for (0..100) |_| {
        // Increment by 1 frame
        sequencer.tick(1);

        std.debug.print("Value: {}\n", .{testObj.value});
        std.debug.print("Other Value: ({}, {}, {}, {})\n", .{ testObj.other_value.x, testObj.other_value.y, testObj.other_value.z, testObj.other_value.w });

        // Sleep for 100 nanoseconds
        std.time.sleep(100);
    }

    std.debug.print("\n\nDone!", .{});
}
