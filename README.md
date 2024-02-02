# zig-animation
A property animation library in Zig.

## Demo 1: Property Interpolation
Full demo code in [`animator.zig`](src/animator.zig).

```zig
const start = Vec2{ .x = 0, .y = 0 };
const end = Vec2{ .x = 1, .y = 1 };

const anim = Animator(Vec2).init(start, end, EaseInCubicVec2);

// 2D Cubic Easing
try std.testing.expectEqual(Vec2{ .x = 0.015625, .y = 0.015625 }, anim.eval(0.25));
try std.testing.expectEqual(Vec2{ .x = 0.125, .y = 0.125 }, anim.eval(0.5));
try std.testing.expectEqual(Vec2{ .x = 0.421875, .y = 0.421875 }, anim.eval(0.75));
try std.testing.expectEqual(Vec2{ .x = 1, .y = 1 }, anim.eval(1));
```

## Demo 2: Sequencing
Full demo code in [`sequencer.zig`](src/sequencer.zig).

We can animate a complex object:
```zig
const TestObject = struct {
    value: f32,
    other_value: Vec2,

    const Self = @This();

    fn update(self: *Self, value: f32) void { ... }
    fn update_other(self: *Self, other_value: Vec2) void { ... }
}
```

Sequencing multiple property animations:
```zig
var testObj: TestObject = undefined;
testObj.value = 30;
testObj.other_value = Vec2{ .x = 10, .y = 10 };

// Go from 30 to 50 over 80 frames
const valueAnim = animator.Animator(f32).init(30, 50, curves.EaseInCubic);
const valueEvent = Event.create_transition(TestObject, f32, &testObj, &valueAnim, 80, TestObject.update);

// Go from (10, 10) to (6, 4) over 65 frames
const otherValueAnim = animator.Animator(Vec2).init(Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 6, .y = 4 }, EaseInCubicVec2);
const otherValueEvent = Event.create_transition(TestObject, Vec2, &testObj, &otherValueAnim, 65, TestObject.update_other);

// Create a sequencer
var sequencer = Sequencer.init(TestAllocator);
sequencer.add_event(0, valueEvent);
sequencer.add_event(0, otherValueEvent);

// Move the sequencer forward
sequencer.tick(10);

// Check the values
const expectedVal = curves.EaseInCubic(30, 50, 10.0 / 80.0);
try std.testing.expectEqual(expectedVal, testObj.value);

const expectedVector = EaseInCubicVec2(Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 6, .y = 4 }, 10.0 / 65.0);
try std.testing.expectEqual(expectedVector, testObj.other_value);
```

## Key Concepts
The three files in this library are:
 * `animator.zig`: Contains Animators, which are objects that animate over a given property. You have one animator per property, so a location/rotation/scale animation might have `locationAnim: Animator(Vec3)`, `rotationAnim: Animator(Quat)`, `scaleAnim: Animator(Vec3)` (respectively).
 * `sequencer.zig`: Allows for Actions (one-off event) and Transitions (ongoing event) to be scheduled and run. You have one sequencer per project/module/grouping of animations.
 * `curves.zig`: A collection of interpolation functions for f32. See the `animator.zig` class for an easy example of how to create higher dimension interpolation functions (e.g. for Vector2/3/4/etc).

## Examples
In each source file, there are fully-commented tests demonstrating some key patterns.

For example, see [sequencer.zig](/src/sequencer.zig).

## Building
Standard Zig library:
```
zig build
zig build test --summary all
```

## About
This repo is a mirror of the in-tree animation library from my personal game engine project. As such, this library is actively (albeit infrequently) maintained.

### Contributions
Contributions are welcome, although keep in mind the library scope is intentionally small.

### Licence
MIT Licensed - do what you want!