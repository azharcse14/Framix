use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, DuplicateClip, InsertClip, MergeClips, RemoveClip, SplitClip,
    TimelineChanged, TrackKind, TrimClip, Undo, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine.handle(Command { kind: Some(kind) }).kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

/// Engine with one video track holding clip [0, 100) of media 7 (source 0); returns its id.
fn with_clip() -> (Engine, u64) {
    let mut engine = Engine::default();
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    let track = changed(run(&mut engine, add)).tracks[0].id;
    let insert = command::Kind::InsertClip(InsertClip {
        track_id: track,
        media_id: 7,
        source_start: 0,
        start: 0,
        duration: 100,
    });
    let clip = changed(run(&mut engine, insert)).tracks[0].clips[0].id;
    (engine, clip)
}

/// (start, duration) of the first track's clips.
fn spans(t: &TimelineChanged) -> Vec<(i64, i64)> {
    t.tracks[0]
        .clips
        .iter()
        .map(|c| (c.start, c.duration))
        .collect()
}

#[test]
fn split_merge_trim_duplicate_remove_and_undo() {
    let (mut engine, clip) = with_clip();
    let t = changed(run(
        &mut engine,
        command::Kind::SplitClip(SplitClip {
            clip_id: clip,
            at: 30,
        }),
    ));
    assert_eq!(spans(&t), [(0, 30), (30, 70)]);
    let right = t.tracks[0].clips[1].id;

    let merge = MergeClips {
        left_id: clip,
        right_id: right,
    };
    let t = changed(run(&mut engine, command::Kind::MergeClips(merge)));
    assert_eq!(spans(&t), [(0, 100)]);

    let trim = TrimClip {
        clip_id: clip,
        start: 10,
        end: 60,
    };
    let t = changed(run(&mut engine, command::Kind::TrimClip(trim)));
    assert_eq!(spans(&t), [(10, 50)]);
    assert_eq!(t.tracks[0].clips[0].source_start, 10);

    let t = changed(run(
        &mut engine,
        command::Kind::DuplicateClip(DuplicateClip { clip_id: clip }),
    ));
    assert_eq!(spans(&t), [(10, 50), (60, 50)]);

    let t = changed(run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip { clip_id: clip }),
    ));
    assert_eq!(spans(&t), [(60, 50)]);

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(spans(&t), [(10, 50), (60, 50)], "each op is one undo step");
}

#[test]
fn ops_on_unknown_clips_fail() {
    let (mut engine, _) = with_clip();
    let e = run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip { clip_id: 999 }),
    );
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
}
