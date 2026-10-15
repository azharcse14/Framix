use framix_app::engine::Engine;
use framix_app::project::{decode, encode};
use framix_app::proto::{
    AddTrack, Command, InsertClip, SetTrackFlags, TimelineChanged, TrackKind, Undo, command, event,
};
use framix_core::timeline::{Timeline, TrackFlags, TrackKind as CoreKind};

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine.handle(Command { kind: Some(kind) }).kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn flags(track_id: u64, muted: bool, hidden: bool, locked: bool) -> command::Kind {
    command::Kind::SetTrackFlags(SetTrackFlags {
        track_id,
        muted: Some(muted),
        hidden: Some(hidden),
        locked: Some(locked),
    })
}

#[test]
fn flags_are_reported_undoable_and_lock_blocks_edits() {
    let mut engine = Engine::default();
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    let track = changed(run(&mut engine, add)).tracks[0].id;

    let t = changed(run(&mut engine, flags(track, true, true, true)));
    let tr = &t.tracks[0];
    assert!(tr.muted && tr.hidden && tr.locked);

    let insert = command::Kind::InsertClip(InsertClip {
        track_id: track,
        media_id: 1,
        source_start: 0,
        start: 0,
        duration: 10,
    });
    let e = run(&mut engine, insert);
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    let tr = &t.tracks[0];
    assert!(!tr.muted && !tr.hidden && !tr.locked);
}

#[test]
fn hiding_an_audio_track_is_refused() {
    let mut engine = Engine::default();
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Audio as i32,
    });
    let track = changed(run(&mut engine, add)).tracks[0].id;
    let e = run(&mut engine, flags(track, false, true, false));
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
}

#[test]
fn flags_round_trip_through_the_project_file() {
    let mut tl = Timeline::default();
    let t = tl.add_track(CoreKind::Video);
    let set = TrackFlags {
        muted: true,
        hidden: false,
        locked: true,
    };
    tl.set_track_flags(t, set).unwrap();
    let opened = decode(&encode(&tl)).unwrap();
    assert_eq!(opened.tracks()[0].flags(), set);
}
