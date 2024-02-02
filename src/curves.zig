pub fn Linear(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn EaseInQuad(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t * t;
}

pub fn EaseOutQuad(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t * (2.0 - t);
}

pub fn EaseInOutQuad(a: f32, b: f32, t: f32) f32 {
    if (t < 0.5) {
        return a + (b - a) * 2.0 * t * t;
    } else {
        return a + (b - a) * (2.0 * t - 1.0) * (2.0 - 2.0 * t);
    }
}

pub fn EaseInCubic(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t * t * t;
}

pub fn EaseOutCubic(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * (t - 1.0) * (t - 1.0) * (t - 1.0) + 1.0;
}

pub fn EaseInOutCubic(a: f32, b: f32, t: f32) f32 {
    if (t < 0.5) {
        return a + (b - a) * 4.0 * t * t * t;
    } else {
        return a + (b - a) * (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0;
    }
}
