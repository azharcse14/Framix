//! Integer timebase. Time is never floating-point seconds.

/// Ticks per second: 705,600,000 ("flicks"). Every common frame rate (including NTSC
/// x/1001 rates) and audio sample rate divides it exactly.
pub const TICKS_PER_SECOND: i64 = 705_600_000;

/// A point or span on the timeline, in ticks of [`TICKS_PER_SECOND`]. Defaults to 0.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Time(pub i64);

impl Time {
    /// Whole microseconds, rounded toward zero: the unit platform media APIs take.
    pub fn micros(self) -> i64 {
        // A microsecond is 705.6 ticks, so the quotient always fits; i128 keeps the product in
        // range for any tick count.
        (i128::from(self.0) * 1_000_000 / i128::from(TICKS_PER_SECOND)) as i64
    }
}

/// Frames (or samples) per second as an exact fraction `num / den`, e.g. 30000/1001.
///
/// Conversions are exact only while `num <= den * TICKS_PER_SECOND`; faster rates make a
/// frame shorter than one tick (rejecting them in `new` is ENG-047).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Rate {
    num: u32,
    den: u32,
}

impl Rate {
    /// `fps` whole frames per second; 0 counts as 1.
    pub fn whole(fps: u32) -> Self {
        Self {
            num: fps.max(1),
            den: 1,
        }
    }

    /// Returns `None` unless both parts are non-zero.
    pub fn new(num: u32, den: u32) -> Option<Self> {
        (num != 0 && den != 0).then_some(Self { num, den })
    }

    /// Start time of frame `frame`. `None` if it does not fit in [`Time`].
    pub fn frame_to_time(self, frame: i64) -> Option<Time> {
        // Ceil, so a frame never starts before its exact instant and time_to_frame round-trips.
        let exact = i128::from(frame) * self.ticks_per_frame_num();
        let ticks = -(-exact).div_euclid(i128::from(self.num));
        i64::try_from(ticks).ok().map(Time)
    }

    /// Index of the frame showing at `time`. `None` if it does not fit in an i64.
    pub fn time_to_frame(self, time: Time) -> Option<i64> {
        let frame =
            (i128::from(time.0) * i128::from(self.num)).div_euclid(self.ticks_per_frame_num());
        i64::try_from(frame).ok()
    }

    /// Numerator of ticks per frame (`den * TICKS_PER_SECOND / num`); fits easily in i128.
    fn ticks_per_frame_num(self) -> i128 {
        i128::from(self.den) * i128::from(TICKS_PER_SECOND)
    }
}
