use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, InsertClip, MoveClip, TimelineChanged, TrackKind, Undo, command, event,
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

fn add_video(engine: &mut Engine) -> u64 {
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    changed(run(engine, add)).tracks.last().unwrap().id
}

#[test]
fn move_clip_across_tracks_and_undo() {
    let mut engine = Engine::default();
    let v1 = add_video(&mut engine);
    let v2 = add_video(&mut engine);
    let insert = command::Kind::InsertClip(InsertClip {
        track_id: v1,
        media_id: 1,
        source_start: 0,
        start: 0,
        duration: 10,
    });
    let clip = changed(run(&mut engine, insert)).tracks[0].clips[0].id;

    let mv = command::Kind::MoveClip(MoveClip {
        clip_id: clip,
        track_id: v2,
        start: 50,
    });
    let t = changed(run(&mut engine, mv));
    assert!(t.tracks[0].clips.is_empty());
    assert_eq!(
        (t.tracks[1].clips[0].id, t.tracks[1].clips[0].start),
        (clip, 50)
    );

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(t.tracks[0].clips[0].start, 0);

    let bad = command::Kind::MoveClip(MoveClip {
        clip_id: clip,
        track_id: v2,
        start: -1,
    });
    assert!(matches!(
        run(&mut engine, bad),
        Some(event::Kind::CommandFailed(_))
    ));
}
