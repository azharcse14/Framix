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

/// Registers a one-hour video through the command API and returns its media id, so InsertClip
/// can refer to it (ENG-052). Import also places a clip; it is removed again, so the tracks
/// keep their clips. Call it once the test's first video track exists, or import adds one.
pub fn import_video(engine: &mut framix_app::engine::Engine) -> u64 {
    use framix_app::proto::{
        Command, ImportMedia, MediaItem, MediaKind, RemoveClip, command, event,
    };
    let mut run = |kind| match engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
    {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    };
    let item = MediaItem {
        uri: "media/v.mp4".into(),
        kind: MediaKind::Video as i32,
        duration_value: 3600,
        duration_timescale: 1,
        width: 1920,
        height: 1080,
        ..Default::default()
    };
    let t = run(command::Kind::ImportMedia(ImportMedia {
        items: vec![item],
    }));
    let clip = t
        .tracks
        .iter()
        .flat_map(|t| &t.clips)
        .max_by_key(|c| c.id)
        .expect("import places a clip");
    let (clip_id, media_id) = (clip.id, clip.media_id);
    run(command::Kind::RemoveClip(RemoveClip { clip_id }));
    media_id
}
