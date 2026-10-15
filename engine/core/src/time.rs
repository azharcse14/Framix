//! Integer timebase. Time is never floating-point seconds.

/// Ticks per second: 705,600,000 ("flicks"). Every common frame rate (including NTSC
/// x/1001 rates) and audio sample rate divides it exactly.
pub const TICKS_PER_SECOND: i64 = 705_600_000;

/// A point or span on the timeline, in ticks of [`TICKS_PER_SECOND`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Time(pub i64);

/// Frames (or samples) per second as an exact fraction `num / den`, e.g. 30000/1001.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Rate {
    num: u32,
    den: u32,
}

impl Rate {
    /// Returns `None` unless both parts are non-zero.
    pub fn new(num: u32, den: u32) -> Option<Self> {
        let _ = (num, den);
        None
    }

    /// Start time of frame `frame`. `None` if it does not fit in [`Time`].
    pub fn frame_to_time(self, frame: i64) -> Option<Time> {
        let _ = frame;
        None
    }

    /// Index of the frame showing at `time`. `None` if it does not fit in an i64.
    pub fn time_to_frame(self, time: Time) -> Option<i64> {
        let _ = time;
        None
    }
}
