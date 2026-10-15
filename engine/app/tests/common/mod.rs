//! Shared test helpers.
#![allow(dead_code)] // Each test crate uses a subset.

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::timeline::{MediaId, Timeline};

/// A valid photo media entry.
pub fn photo() -> Media {
    Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 1,
        height: 1,
        rotation: 0,
        codec: String::new(),
    })
    .expect("valid photo")
}

/// Registers a photo under each id, so clips that refer to them can be saved (P1-011).
pub fn register(t: &mut Timeline, ids: &[u64]) {
    for &id in ids {
        t.restore_media(MediaId(id), photo());
    }
}
