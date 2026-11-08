//! RemoveClips, MoveClips and DuplicateClips (P1-024): one undo step each, all or nothing.

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, DuplicateClips, InsertClip, MoveClips, RemoveClips, TimelineChanged,
    TrackKind, Undo, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn failed(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandFailed(_)))
}

/// One video track with clips at 0, 10 and 40 (10 long each); returns their ids.
fn three_clips(engine: &mut Engine) -> Vec<u64> {
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    let track = changed(run(engine, add)).tracks[0].id;
    let mut t = TimelineChanged::default();
    for start in [0, 10, 40] {
        let insert = command::Kind::InsertClip(InsertClip {
            track_id: track,
            media_id: 1,
            source_start: 0,
            start,
            duration: 10,
        });
        t = changed(run(engine, insert));
    }
    t.tracks[0].clips.iter().map(|c| c.id).collect()
}

fn starts(t: &TimelineChanged) -> Vec<i64> {
    t.tracks[0].clips.iter().map(|c| c.start).collect()
}

#[test]
fn each_multi_edit_is_one_undo_step() {
    let mut engine = Engine::default();
    let ids = three_clips(&mut engine);

    let mv = command::Kind::MoveClips(MoveClips {
        clip_ids: vec![ids[0], ids[1]],
        by: 15,
    });
    assert_eq!(starts(&changed(run(&mut engine, mv))), [15, 25, 40]);
    let undo = || command::Kind::Undo(Undo {});
    assert_eq!(starts(&changed(run(&mut engine, undo()))), [0, 10, 40]);

    let dup = command::Kind::DuplicateClips(DuplicateClips {
        clip_ids: vec![ids[0], ids[1]],
    });
    assert_eq!(starts(&changed(run(&mut engine, dup))), [0, 10, 20, 30, 40]);
    assert_eq!(starts(&changed(run(&mut engine, undo()))), [0, 10, 40]);

    let rm = command::Kind::RemoveClips(RemoveClips {
        clip_ids: vec![ids[2], ids[0]],
    });
    assert_eq!(starts(&changed(run(&mut engine, rm))), [10]);
    assert_eq!(starts(&changed(run(&mut engine, undo()))), [0, 10, 40]);
}

#[test]
fn a_refused_multi_edit_changes_nothing() {
    let mut engine = Engine::default();
    let ids = three_clips(&mut engine);

    // The second clip would run into the third: the first must not move either.
    let mv = command::Kind::MoveClips(MoveClips {
        clip_ids: vec![ids[0], ids[1]],
        by: 25,
    });
    assert!(failed(run(&mut engine, mv)));
    let rm = command::Kind::RemoveClips(RemoveClips {
        clip_ids: vec![ids[0], 999],
    });
    assert!(failed(run(&mut engine, rm)));
    let empty = command::Kind::DuplicateClips(DuplicateClips { clip_ids: vec![] });
    assert!(failed(run(&mut engine, empty)));
    // More ids than the timeline has clips is refused before any work.
    let long = command::Kind::RemoveClips(RemoveClips {
        clip_ids: (0..1_000_000).collect(),
    });
    assert!(failed(run(&mut engine, long)));

    let get = command::Kind::GetTimeline(Default::default());
    assert_eq!(starts(&changed(run(&mut engine, get))), [0, 10, 40]);
    // No step was added: one undo takes back the last insert.
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(starts(&t), [0, 10]);
}
