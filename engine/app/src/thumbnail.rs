//! Port for thumbnails: the platform layer decodes a frame and writes a small image file; the
//! engine decides which ones exist and how many are made at once (P1-021). Tests use fakes.

use framix_core::media::MediaKind;
use framix_core::time::Time;
use framix_core::timeline::MediaId;

/// Thumbnail times are multiples of this.
pub const THUMBNAIL_STEP: Time = Time(framix_core::time::TICKS_PER_SECOND);

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
