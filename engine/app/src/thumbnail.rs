//! Port for thumbnails: the platform layer decodes a frame and writes a small image file; the
//! engine decides which ones exist and how many are made at once (P1-021). Tests use fakes.

use std::collections::{BTreeSet, VecDeque};

use framix_core::media::{Media, MediaKind};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::MediaId;

/// Thumbnail times are multiples of this.
pub const THUMBNAIL_STEP: Time = Time(TICKS_PER_SECOND);

/// Smallest and largest thumbnail side a request may ask for.
pub const MAX_SIDE: std::ops::RangeInclusive<u32> = 32..=512;

/// Most times one request may carry.
pub const MAX_TIMES: usize = 64;

/// Thumbnails being made at once (RES-005 adds priorities).
const MAX_IN_FLIGHT: usize = 2;

/// One thumbnail: a media, a snapped source time and a size.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ThumbnailKey {
    /// Which media.
    pub media: MediaId,
    /// Snapped source time.
    pub time: Time,
    /// Longest side in pixels.
    pub max_side: u32,
}

/// What the platform needs to make one thumbnail.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ThumbnailRequest {
    /// Passed back with the answer.
    pub key: ThumbnailKey,
    /// The media reference, as imported.
    pub uri: String,
    /// Video or photo.
    pub kind: MediaKind,
    /// Source time in microseconds (the platform does no tick math).
    pub time_us: i64,
}

/// The platform layer (Swift/Kotlin) side. Calls must return at once; the answer comes back
/// through [`crate::engine::Engine::thumbnail_ready`].
pub trait ThumbnailHost: Send {
    /// Starts making one thumbnail. An error means nothing was started.
    fn request(&self, request: ThumbnailRequest) -> Result<(), String>;
}

/// Which thumbnails were asked for, which are being made, and what waits.
pub(crate) struct Thumbnails {
    host: Box<dyn ThumbnailHost>,
    /// Every key ever asked for (made, failed or waiting): nothing is made twice.
    known: BTreeSet<ThumbnailKey>,
    /// Keys the platform is working on.
    in_flight: BTreeSet<ThumbnailKey>,
    queue: VecDeque<ThumbnailRequest>,
}

impl Thumbnails {
    pub(crate) fn new(host: Box<dyn ThumbnailHost>) -> Self {
        Self {
            host,
            known: BTreeSet::new(),
            in_flight: BTreeSet::new(),
            queue: VecDeque::new(),
        }
    }

    /// Queues the thumbnails of `media` at `times` that were never asked for, then starts as
    /// many as may run. Fails if the platform refuses to start one (no platform layer).
    pub(crate) fn ask(
        &mut self,
        id: MediaId,
        media: &Media,
        times: &[i64],
        max_side: u32,
    ) -> Result<(), String> {
        for &time in times {
            let time = snap(media, time);
            let key = ThumbnailKey {
                media: id,
                time,
                max_side,
            };
            if self.known.insert(key) {
                self.queue.push_back(ThumbnailRequest {
                    key,
                    uri: media.uri().to_owned(),
                    kind: media.kind(),
                    time_us: micros(time),
                });
            }
        }
        self.start()
    }

    /// The platform answered `key`; false if it was not being made (a stray answer).
    pub(crate) fn finish(&mut self, key: ThumbnailKey) -> bool {
        let known = self.in_flight.remove(&key);
        // Nobody waits on this answer; a refusal here surfaces on the next request.
        let _ = self.start();
        known
    }

    /// Starts queued requests while fewer than MAX_IN_FLIGHT run. If the platform refuses one,
    /// it and everything still queued are forgotten, so a later request asks again.
    fn start(&mut self) -> Result<(), String> {
        while self.in_flight.len() < MAX_IN_FLIGHT {
            let Some(request) = self.queue.pop_front() else {
                return Ok(());
            };
            let key = request.key;
            if let Err(reason) = self.host.request(request) {
                self.known.remove(&key);
                for waiting in self.queue.drain(..) {
                    self.known.remove(&waiting.key);
                }
                return Err(reason);
            }
            self.in_flight.insert(key);
        }
        Ok(())
    }
}

/// `time` snapped down to the step, inside the media (photos: always 0).
fn snap(media: &Media, time: i64) -> Time {
    if media.kind() == MediaKind::Image {
        return Time(0);
    }
    let last = (media.duration().0 - 1).max(0);
    let time = time.clamp(0, last);
    Time(time - time % THUMBNAIL_STEP.0)
}

/// Ticks to microseconds, rounded down.
fn micros(time: Time) -> i64 {
    // Exact for step multiples; i128 keeps the product in range for any i64 tick count.
    (i128::from(time.0) * 1_000_000 / i128::from(TICKS_PER_SECOND)) as i64
}
