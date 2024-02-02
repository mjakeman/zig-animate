const std = @import("std");
const animator = @import("animator.zig");
const curves = @import("curves.zig");

const ShouldRemove = enum { Remove, Keep };

pub const Event = union(enum) {
    action: struct {
        ptr: usize,
        execute: *const fn (usize) void,
    },
    transition: struct {
        duration: f64,
        ptr: usize,
        animator: usize,
        execute: *const fn (usize, usize, f32) void,
    },

    pub fn create_action(comptime Data: type, ptr: *Data, callback: fn (ptr: *Data) void) Event {
        const execute_fn = struct {
            fn execute(p: usize) void {
                const obj = @as(*Data, @ptrFromInt(p));
                callback(obj);
            }
        }.execute;

        return Event{
            .action = .{
                .ptr = @intFromPtr(ptr),
                .execute = execute_fn,
            },
        };
    }

    pub fn create_transition(comptime Data: type, comptime Property: type, ptr: *Data, anim: *const animator.Animator(Property), duration: f32, callback: fn (ptr: *Data, property: Property) void) Event {
        const execute_fn = struct {
            fn execute(p: usize, a: usize, t: f32) void {
                const anim2 = @as(*const animator.Animator(Property), @ptrFromInt(a));
                const property = anim2.eval(t);
                const obj = @as(*Data, @ptrFromInt(p));
                callback(obj, property);
            }
        }.execute;

        return Event{
            .transition = .{
                .ptr = @intFromPtr(ptr),
                .animator = @intFromPtr(anim),
                .duration = duration,
                .execute = execute_fn,
            },
        };
    }

    // Returns true if should remove
    fn process(self: *Event, elapsed: f64) ShouldRemove {
        switch (self.*) {
            Event.action => {
                self.action.execute(self.action.ptr);
                return ShouldRemove.Remove;
            },
            Event.transition => {
                const t = @as(f32, @floatCast(elapsed / self.transition.duration));
                self.transition.execute(self.transition.ptr, self.transition.animator, t);

                if (elapsed >= self.transition.duration) {
                    return ShouldRemove.Remove;
                }
                return ShouldRemove.Keep;
            },
        }
    }
};

const Sequenceable = struct {
    event: Event,
    start_time: f64,
};

pub const Sequencer = struct {
    event_queue: std.ArrayList(Sequenceable),
    current_time: f64,

    pub fn init(allocator: std.mem.Allocator) Sequencer {
        return Sequencer{
            .event_queue = std.ArrayList(Sequenceable).init(allocator),
            .current_time = 0,
        };
    }

    pub fn add_event(self: *Sequencer, delay: f64, event: Event) void {
        self.event_queue.append(Sequenceable{
            .event = event,
            .start_time = self.current_time + delay,
        }) catch @panic("Cannot add event to sequencer");
    }

    pub fn tick(self: *Sequencer, delta_time: f32) void {
        self.current_time += delta_time;

        var toRemove = std.ArrayList(usize).init(self.event_queue.allocator);

        for (0..self.event_queue.items.len) |index| {
            var sequenceable = &self.event_queue.items[index];
            if (sequenceable.start_time <= self.current_time) {
                const should_remove = sequenceable.event.process(self.current_time - sequenceable.start_time);
                if (should_remove == ShouldRemove.Remove) {
                    toRemove.append(index) catch @panic("Queue removal tracker not working");
                }
            }
        }

        // Go in reverse order to avoid going out of bounds
        for (0..toRemove.items.len) |el| {
            const index = toRemove.items[toRemove.items.len - 1 - el];
            _ = self.event_queue.orderedRemove(index);
        }
    }
};

// TESTS

const TestAllocator = std.heap.page_allocator;

// Callback function
fn clear_array_list(ptr: *std.ArrayList(f32)) void {
    // Work out the sum of the array (why not)
    var sum: f32 = 0;
    for (ptr.items) |item| {
        sum += item;
    }

    // Print it out
    std.debug.print("Callback called with sum {}\n", .{sum});

    // Now clear all elements
    ptr.clearAndFree();
}

test "Action" {

    // Let's create some kind of object...
    // Doesn't matter what, but we'll use something a little more complex
    // Here's an array list going from 0 to 10
    var random_object = std.ArrayList(f32).init(TestAllocator);
    for (0..10) |i| {
        _ = try random_object.append(@as(f32, @floatFromInt(i)));
    }

    // Create a sequencer
    var sequencer = Sequencer.init(TestAllocator);

    // Now we create an 'action' type event. This is a callback which will be triggered after a delay
    const event = Event.create_action(
        std.ArrayList(f32),
        &random_object,
        clear_array_list,
    );

    // Add the event to the sequencer with a delay of 50
    sequencer.add_event(50, event);

    // Move the sequencer forward
    // Normally you'd do this in a loop and pass in the elapsed time
    sequencer.tick(40);

    // Nothing should have happened yet
    try std.testing.expectEqual(random_object.items.len, 10);

    // Move the sequencer forward again
    sequencer.tick(20);

    // The callback should have been called and the array list should be empty
    try std.testing.expectEqual(random_object.items.len, 0);
}

test "Simple Transition" {

    // The property we want to animate
    var property: f32 = 0;

    // A callback function to update our property
    const update_callback = struct {
        fn update_property(ptr: *f32, value: f32) void {
            std.debug.print("Updating property to {}\n", .{value});
            ptr.* = value;
        }
    }.update_property;

    // We animate it from 0 to 10
    const property_animator = animator.Animator(f32).init(0, 10, curves.Linear);

    // Animate over 100 frames, calling 'update_callback' each time the sequencer ticks
    const event = Event.create_transition(
        f32,
        f32,
        &property,
        &property_animator,
        100,
        update_callback,
    );

    // Create a sequencer and add the event with a delay of 20
    var sequencer = Sequencer.init(TestAllocator);
    sequencer.add_event(20, event);

    // Move the sequencer forward
    sequencer.tick(10);

    // The property should not change as the event has yet to start (recall delay of 20)
    try std.testing.expectEqual(@as(f32, 0), property);

    // Move the sequencer forward again
    sequencer.tick(30);

    // The property should be at t=0.2 (i.e. 20 frames into the animation)
    try std.testing.expectEqual(@as(f32, 2), property);

    // Move the sequencer forward again
    sequencer.tick(50);

    // The property should be at t=0.7 (i.e. 70 frames into the animation)
    try std.testing.expectEqual(@as(f32, 7), property);

    // Move the sequencer forward again
    sequencer.tick(500);

    // The property should be at t=1 (i.e. animation finished)
    try std.testing.expectEqual(@as(f32, 10), property);
}

//
// A more complex scenario
//
const Vec2 = struct {
    x: f32,
    y: f32,
};

fn EaseInCubicVec2(start: Vec2, end: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = curves.EaseInCubic(start.x, end.x, t),
        .y = curves.EaseInCubic(start.y, end.y, t),
    };
}

const TestObject = struct {
    value: f32,
    other_value: Vec2,

    const Self = @This();

    fn update(self: *Self, value: f32) void {
        std.debug.print("Updating value to {}\n", .{value});
        self.value = value;
    }

    fn update_other(self: *Self, other_value: Vec2) void {
        std.debug.print("Updating other value to {}\n", .{other_value});
        self.other_value = other_value;
    }
};

test "Multi-Event Transitions" {
    // Let's now update multiple properties of an object using the sequencer
    var testObj: TestObject = undefined;
    testObj.value = 30;
    testObj.other_value = Vec2{ .x = 10, .y = 10 };

    // Go from 30 to 50 (over 80 frames)
    const valueAnim = animator.Animator(f32).init(30, 50, curves.EaseInCubic);
    const valueEvent = Event.create_transition(
        TestObject,
        f32,
        &testObj,
        &valueAnim,
        80,
        TestObject.update,
    );

    // Go from (10, 10) to (6, 4) over 65 frames
    const otherValueAnim = animator.Animator(Vec2).init(Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 6, .y = 4 }, EaseInCubicVec2);
    const otherValueEvent = Event.create_transition(
        TestObject,
        Vec2,
        &testObj,
        &otherValueAnim,
        65,
        TestObject.update_other,
    );

    // Create a sequencer
    var sequencer = Sequencer.init(TestAllocator);
    sequencer.add_event(0, valueEvent);
    sequencer.add_event(0, otherValueEvent);

    // Move the sequencer forward
    sequencer.tick(10);

    // Check the values
    try std.testing.expectEqual(curves.EaseInCubic(30, 50, 10.0 / 80.0), testObj.value);
    try std.testing.expectEqual(EaseInCubicVec2(Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 6, .y = 4 }, 10.0 / 65.0), testObj.other_value);

    // Move the sequencer forward
    sequencer.tick(50);

    // Check the values
    try std.testing.expectEqual(curves.EaseInCubic(30, 50, 60.0 / 80.0), testObj.value);
    try std.testing.expectEqual(EaseInCubicVec2(Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 6, .y = 4 }, 60.0 / 65.0), testObj.other_value);

    // Move the sequencer to the end
    sequencer.tick(100);

    // Check the values
    try std.testing.expectEqual(@as(f32, 50), testObj.value);
    try std.testing.expectEqual(Vec2{ .x = 6, .y = 4 }, testObj.other_value);

    // Check empty
    try std.testing.expectEqual(@as(usize, 0), sequencer.event_queue.items.len);
}
