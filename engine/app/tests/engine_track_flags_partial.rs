//! P1-026 review: partial flag updates and lock restore order.
use framix_app::engine::Engine;
use framix_app::project::{decode, encode};
use framix_app::proto::{
    AddTrack, Command, SetTrackFlags, TimelineChanged, TrackKind, command, event,
};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TrackFlags, TrackKind as CoreKind};

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn unset_fields_keep_their_value() {
    let mut engine = Engine::default();
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    let track_id = changed(engine.handle(Command { kind: Some(add) }).kind).tracks[0].id;
    let set = |muted, locked| {
        Some(command::Kind::SetTrackFlags(SetTrackFlags {
            track_id,
            muted,
            hidden: None,
            locked,
        }))
    };
    engine.handle(Command {
        kind: set(Some(true), None),
    });
    let t = changed(
        engine
            .handle(Command {
                kind: set(None, Some(true)),
            })
            .kind,
    );
    assert!(
        t.tracks[0].muted && t.tracks[0].locked,
        "lock must not undo the mute"
    );
}

#[test]
fn a_locked_track_with_clips_reopens_with_clips_and_lock() {
    let mut tl = Timeline::default();
    let t = tl.add_track(CoreKind::Video);
    let clip = ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(0),
        duration: Time(10),
    };
    tl.insert_clip(t, clip).unwrap();
    let locked = TrackFlags {
        locked: true,
        ..TrackFlags::default()
    };
    tl.set_track_flags(t, locked).unwrap();
    let opened = decode(&encode(&tl)).unwrap();
    assert_eq!(opened.tracks()[0].clips().len(), 1);
    assert_eq!(opened.tracks()[0].flags(), locked);
}
