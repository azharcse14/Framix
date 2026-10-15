//! Imported media: what the engine knows about a picked file. Everything arrives from the
//! platform layer untrusted and only becomes a [`Media`] through [`Media::validate`].

use crate::time::{TICKS_PER_SECOND, Time};

/// Most items one import may add.
pub const MAX_IMPORT: usize = 100;
/// Timeline length a photo gets on import (P1-028).
pub const PHOTO_DEFAULT_DURATION: Time = Time(3 * TICKS_PER_SECOND);

/// Video or still image.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MediaKind {
    /// Has a duration.
    Video,
    /// A still; plays for as long as its clip.
    Image,
}

/// Media facts as the platform reported them; not trusted.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawMedia {
    /// Opaque reference: `content://...` or `media/<name>.<ext>` relative to the app's folder.
    pub uri: String,
    /// Video or image.
    pub kind: MediaKind,
    /// Video duration is `duration_value / duration_timescale` seconds; ignored for images.
    pub duration_value: i64,
    /// Units per second of `duration_value`.
    pub duration_timescale: u32,
    /// Stored pixel width.
    pub width: u32,
    /// Stored pixel height.
    pub height: u32,
    /// Clockwise display rotation in degrees.
    pub rotation: u32,
    /// Short codec tag.
    pub codec: String,
}

/// Why reported media was refused.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum MediaError {
    /// Not a `content://` URI or a plain `media/<name>.<ext>` path.
    #[error("media reference is not allowed")]
    BadUri,
    /// Width or height is outside 1..=16384.
    #[error("media size is out of range")]
    BadSize,
    /// Rotation is not 0, 90, 180 or 270.
    #[error("media rotation is invalid")]
    BadRotation,
    /// Codec tag is longer than 16 or not ASCII.
    #[error("codec tag is invalid")]
    BadCodec,
    /// Video duration is not in (0, 24 h] or the timescale is zero.
    #[error("media duration is invalid")]
    BadDuration,
}

/// Validated media.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Media {
    uri: String,
    kind: MediaKind,
    duration: Time,
    width: u32,
    height: u32,
    rotation: u32,
    codec: String,
}

impl Media {
    /// Checks reported media; see [`MediaError`] for the rules.
    pub fn validate(_raw: RawMedia) -> Result<Self, MediaError> {
        Err(MediaError::BadUri)
    }

    /// Opaque reference for the platform layer; never log it.
    pub fn uri(&self) -> &str {
        &self.uri
    }

    /// Video or image.
    pub fn kind(&self) -> MediaKind {
        self.kind
    }

    /// Video length; zero for images.
    pub fn duration(&self) -> Time {
        self.duration
    }

    /// Stored pixel size (before rotation).
    pub fn size(&self) -> (u32, u32) {
        (self.width, self.height)
    }

    /// Clockwise display rotation in degrees.
    pub fn rotation(&self) -> u32 {
        self.rotation
    }

    /// Short codec tag.
    pub fn codec(&self) -> &str {
        &self.codec
    }
}
