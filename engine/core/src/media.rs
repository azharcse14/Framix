//! Imported media: what the engine knows about a picked file. Everything arrives from the
//! platform layer untrusted and only becomes a [`Media`] through [`Media::validate`].

use crate::time::{TICKS_PER_SECOND, Time};

/// Longest media reference accepted.
const MAX_URI_BYTES: usize = 2048;
/// Largest pixel width or height accepted.
const MAX_SIDE: u32 = 16_384;
/// Longest codec tag accepted.
const MAX_CODEC_BYTES: usize = 16;
/// Longest video accepted.
const MAX_VIDEO: i128 = 24 * 3600 * TICKS_PER_SECOND as i128;

/// Most items one import may add.
pub const MAX_IMPORT: usize = 100;
/// Timeline length a photo gets on import (P1-028).
pub const PHOTO_DEFAULT_DURATION: Time = Time(3 * TICKS_PER_SECOND);

/// Video, still image, or a solid color.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MediaKind {
    /// Has a duration.
    Video,
    /// A still; plays for as long as its clip.
    Image,
    /// A solid color with no file (a blank clip); plays like a still and fills the canvas.
    Color,
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
    /// 0xRRGGBBAA for [`MediaKind::Color`]; 0 otherwise.
    color: u32,
}

impl Media {
    /// A solid color (0xRRGGBBAA): no file, 1x1 pixel, no duration. Every value is valid; the
    /// alpha byte is kept but clips are drawn opaque.
    pub fn solid(rgba: u32) -> Self {
        Self {
            uri: String::new(),
            kind: MediaKind::Color,
            duration: Time(0),
            width: 1,
            height: 1,
            rotation: 0,
            codec: String::new(),
            color: rgba,
        }
    }

    /// Checks reported media; see [`MediaError`] for the rules.
    pub fn validate(raw: RawMedia) -> Result<Self, MediaError> {
        if !uri_allowed(&raw.uri) {
            return Err(MediaError::BadUri);
        }
        let side = 1..=MAX_SIDE;
        if !side.contains(&raw.width) || !side.contains(&raw.height) {
            return Err(MediaError::BadSize);
        }
        if !matches!(raw.rotation, 0 | 90 | 180 | 270) {
            return Err(MediaError::BadRotation);
        }
        if raw.codec.len() > MAX_CODEC_BYTES || !raw.codec.is_ascii() {
            return Err(MediaError::BadCodec);
        }
        let duration = match raw.kind {
            MediaKind::Video => video_duration(raw.duration_value, raw.duration_timescale)?,
            MediaKind::Image => Time(0),
            // Colors are made with Media::solid; a reported file is never one.
            MediaKind::Color => return Err(MediaError::BadUri),
        };
        Ok(Self {
            uri: raw.uri,
            kind: raw.kind,
            duration,
            width: raw.width,
            height: raw.height,
            rotation: raw.rotation,
            codec: raw.codec,
            color: 0,
        })
    }

    /// Opaque reference for the platform layer; never log it.
    pub fn uri(&self) -> &str {
        &self.uri
    }

    /// Video, image or color.
    pub fn kind(&self) -> MediaKind {
        self.kind
    }

    /// 0xRRGGBBAA of a color media; 0 for others.
    pub fn color(&self) -> u32 {
        self.color
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

    /// Longest side of the preview proxy this media gets, if any (docs/adr/0007-proxy-media.md):
    /// videos over 2560 px get 1920, over 1920 px get 1280; photos and smaller videos none.
    pub fn proxy_side(&self) -> Option<u32> {
        if self.kind != MediaKind::Video {
            return None;
        }
        match self.width.max(self.height) {
            2561.. => Some(1920),
            1921.. => Some(1280),
            _ => None,
        }
    }
}

/// `content://` plus printable ASCII, or exactly `media/<name>.<ext>` with name `[A-Za-z0-9-]+`
/// and ext `[a-z0-9]{1,5}`: no absolute paths, no `..`, no sub-folders, no other schemes.
fn uri_allowed(uri: &str) -> bool {
    if uri.len() > MAX_URI_BYTES {
        return false;
    }
    if let Some(rest) = uri.strip_prefix("content://") {
        return !rest.is_empty() && rest.bytes().all(|b| b.is_ascii_graphic());
    }
    let Some((name, ext)) = uri.strip_prefix("media/").and_then(|f| f.rsplit_once('.')) else {
        return false;
    };
    !name.is_empty()
        && name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')
        && (1..=5).contains(&ext.len())
        && ext
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
}

/// `value / timescale` seconds in ticks, rounded toward zero (exact for milliseconds), within
/// (0, 24 h].
fn video_duration(value: i64, timescale: u32) -> Result<Time, MediaError> {
    if value <= 0 || timescale == 0 {
        return Err(MediaError::BadDuration);
    }
    let ticks = i128::from(value) * i128::from(TICKS_PER_SECOND) / i128::from(timescale);
    if !(1..=MAX_VIDEO).contains(&ticks) {
        return Err(MediaError::BadDuration);
    }
    i64::try_from(ticks)
        .map(Time)
        .map_err(|_| MediaError::BadDuration)
}
