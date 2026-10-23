//! SetClipTransform (P1-029).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, SetClipTransform, TimelineChanged, Undo,
    command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

/// One 1080 x 1920 photo clip; returns the engine and the clip id.
fn setup() -> (Engine, u64) {
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
    (engine, clip)
}

fn set(clip_id: u64, rotation: u32, flip_h: bool, crop_left: u32) -> command::Kind {
    command::Kind::SetClipTransform(SetClipTransform {
        clip_id,
        rotation,
        flip_h,
        flip_v: false,
        crop_left,
        crop_top: 0,
        crop_right: 0,
        crop_bottom: 0,
    })
}

#[test]
fn the_transform_shows_up_in_the_timeline() {
    let (mut engine, clip) = setup();
    let t = changed(run(&mut engine, set(clip, 90, true, 10)));
    let c = &t.tracks[0].clips[0];
    assert_eq!(
        (c.rotation, c.flip_h, c.flip_v, c.crop_left),
        (90, true, false, 10)
    );
    assert!(t.can_undo);
}

#[test]
fn only_quarter_turns_are_accepted() {
    let (mut engine, clip) = setup();
    for bad in [45, 360, 1] {
        let e = run(&mut engine, set(clip, bad, false, 0));
        assert!(
            matches!(e.kind, Some(event::Kind::CommandFailed(_))),
            "rotation {bad}"
        );
    }
    for good in [0, 90, 180, 270] {
        let t = changed(run(&mut engine, set(clip, good, false, 0)));
        assert_eq!(t.tracks[0].clips[0].rotation, good);
    }
}

#[test]
fn a_crop_leaving_nothing_is_refused() {
    let (mut engine, clip) = setup();
    let e = run(&mut engine, set(clip, 0, false, 1080));
    assert!(matches!(e.kind, Some(event::Kind::CommandFailed(_))));
}

#[test]
fn one_undo_step_and_none_for_no_change() {
    let (mut engine, clip) = setup();
    run(&mut engine, set(clip, 180, false, 0));
    run(&mut engine, set(clip, 180, false, 0));
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(
        t.tracks[0].clips[0].rotation, 0,
        "one undo goes back to the identity"
    );
    assert!(t.can_undo, "the import is still undoable");
}
