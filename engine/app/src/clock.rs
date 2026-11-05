//! The playback clock port: playback advances the playhead by how far this clock moved
//! (docs/architecture.md, ports). The audio output becomes the clock once it exists (P2-001).

use framix_core::time::Time;

/// A monotonic clock in timeline ticks. Only differences between two readings matter.
pub trait Clock: Send {
    /// Now, in ticks since some fixed point.
    fn now(&self) -> Time;
}
