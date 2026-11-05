//! Each clip reports its picture's frame on the canvas (P1-063), so the UI outline matches
//! what the preview draws.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SetAspectRatio, TimelineChanged, command, event,
};

fn changed(engine: &mut Engine, kind: command::Kind) -> TimelineChanged {
    match engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
    {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn a_wide_video_reports_a_full_width_short_frame() {
    let mut engine = Engine::default();
    changed(
        &mut engine,
        command::Kind::SetAspectRatio(SetAspectRatio {
            width: 9,
            height: 16,
        }),
    );
    let t = changed(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                color: 0,
                uri: "content://media/external/video/1".into(),
                kind: MediaKind::Video as i32,
                duration_value: 2000,
                duration_timescale: 1000,
                width: 1920,
                height: 1080,
                rotation: 0,
                codec: "avc1".into(),
            }],
        }),
    );
    let clip = &t.tracks[0].clips[0];
    assert!(
        (clip.frame_width - 1.0).abs() < 1e-4,
        "{}",
        clip.frame_width
    );
    assert!(
        (clip.frame_height - 81.0 / 256.0).abs() < 1e-4,
        "{}",
        clip.frame_height
    );

    // The canvas shape changes the frame too.
    let t = changed(
        &mut engine,
        command::Kind::SetAspectRatio(SetAspectRatio {
            width: 16,
            height: 9,
        }),
    );
    let clip = &t.tracks[0].clips[0];
    assert!((clip.frame_width - 1.0).abs() < 1e-4);
    assert!((clip.frame_height - 1.0).abs() < 1e-4);
}
