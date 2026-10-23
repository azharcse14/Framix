//! Canvas position/scale through SetClipTransform, and the active clip (P1-030).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, Seek, SetClipTransform, SetTrackFlags,
    TimelineChanged, Undo, command, event,
};
use framix_core::time::TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn setup() -> (Engine, u64, u64) {
    let mut engine = Engine::default();
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/images/1".into(),
                kind: MediaKind::Image as i32,
                duration_value: 0,
                duration_timescale: 0,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: String::new(),
            }],
        }),
    ));
    let clip = t.tracks[0].clips[0].id;
    (engine, clip, t.tracks[0].id)
}

fn place(clip_id: u64, x: i32, scale: u32, gesture: u64) -> command::Kind {
    command::Kind::SetClipTransform(SetClipTransform {
        clip_id,
        x,
        scale,
        gesture,
        ..Default::default()
    })
}

#[test]
fn a_gesture_is_one_undo_step() {
    let (mut engine, clip, _) = setup();
    for x in [100, 200, 300] {
        changed(run(&mut engine, place(clip, x, 1200, 42)));
    }
    let t = changed(run(&mut engine, place(clip, 300, 1500, 42)));
    let c = &t.tracks[0].clips[0];
    assert_eq!((c.x, c.scale), (300, 1500));
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    let c = &t.tracks[0].clips[0];
    assert_eq!(
        (c.x, c.y, c.scale),
        (0, 0, 1000),
        "one undo goes back before the gesture"
    );
}

#[test]
fn scale_zero_on_the_wire_means_fit() {
    let (mut engine, clip, _) = setup();
    let t = changed(run(&mut engine, place(clip, 10, 0, 0)));
    assert_eq!(t.tracks[0].clips[0].scale, 1000);
}

#[test]
fn the_active_clip_follows_the_playhead_and_hidden_tracks() {
    let (mut engine, clip, track) = setup();
    let t = changed(run(
        &mut engine,
        command::Kind::GetTimeline(Default::default()),
    ));
    assert_eq!(t.active_clip, clip);
    let e = run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: 60 * TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
    match e.kind {
        // Clamped to the end of the 3 s photo: nothing is under the playhead there.
        Some(event::Kind::PlayheadChanged(p)) => assert_eq!(p.active_clip, 0),
        other => panic!("{other:?}"),
    }
    run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
    let t = changed(run(
        &mut engine,
        command::Kind::SetTrackFlags(SetTrackFlags {
            track_id: track,
            hidden: Some(true),
            ..Default::default()
        }),
    ));
    assert_eq!(t.active_clip, 0, "a hidden track has no active clip");
}
