//! The playback clock port: playback advances the playhead by how far this clock moved
//! (docs/architecture.md, ports). The audio output becomes the clock once it exists (P2-001).

use framix_core::time::Time;

/// A monotonic clock in timeline ticks. Only differences between two readings matter.
pub trait Clock: Send {
    /// Now, in ticks since some fixed point.
    fn now(&self) -> Time;
}

/// Wall time from the OS monotonic clock: the clock until audio drives playback.
pub struct SystemClock {
    start: std::time::Instant,
}

impl SystemClock {
    /// A clock reading 0 now.
    pub fn new() -> Self {
        Self {
            start: std::time::Instant::now(),
        }
    }
}

impl Default for SystemClock {
    fn default() -> Self {
        Self::new()
    }
}

impl Clock for SystemClock {
    fn now(&self) -> Time {
        use framix_core::time::TICKS_PER_SECOND;
        let nanos = self.start.elapsed().as_nanos();
        // Exact integer ticks; i64 ticks last about 400 years.
        let ticks = nanos * TICKS_PER_SECOND as u128 / 1_000_000_000;
        Time(i64::try_from(ticks).unwrap_or(i64::MAX))
    }
}
