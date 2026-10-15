use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, Event, GetTimeline, InsertClip, Redo, TimelineChanged, TrackKind, Undo,
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

fn failed(e: Event) -> String {
    match e.kind {
        Some(event::Kind::CommandFailed(f)) => f.reason,
        other => panic!("expected CommandFailed, got {other:?}"),
    }
}

fn add_video_track(engine: &mut Engine) -> TimelineChanged {
    changed(run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ))
}

fn insert(track_id: u64, start: i64, duration: i64) -> command::Kind {
    command::Kind::InsertClip(InsertClip {
        track_id,
        media_id: 7,
        source_start: 0,
        start,
        duration,
    })
}

#[test]
fn add_track_reports_the_new_timeline() {
    let mut engine = Engine::default();
    let t = add_video_track(&mut engine);
    assert_eq!(t.tracks.len(), 1);
    assert_eq!(t.tracks[0].kind, TrackKind::Video as i32);
    assert!(t.can_undo);
    assert!(!t.can_redo);
}

#[test]
fn insert_clip_reports_clip_and_duration() {
    let mut engine = Engine::default();
    let track = add_video_track(&mut engine).tracks[0].id;
    let t = changed(run(&mut engine, insert(track, 100, 50)));
    let clip = &t.tracks[0].clips[0];
    assert_eq!((clip.media_id, clip.start, clip.duration), (7, 100, 50));
    assert_eq!(t.duration, 150);
}

#[test]
fn rejected_edit_reports_failure_and_keeps_state() {
    let mut engine = Engine::default();
    let track = add_video_track(&mut engine).tracks[0].id;
    changed(run(&mut engine, insert(track, 0, 100)));
    assert!(!failed(run(&mut engine, insert(track, 50, 100))).is_empty());
    assert!(!failed(run(&mut engine, insert(999, 0, 10))).is_empty());
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert!(t.tracks[0].clips.is_empty());
}

#[test]
fn bad_commands_are_rejected() {
    let mut engine = Engine::default();
    assert!(!failed(engine.handle(Command { kind: None })).is_empty());
    let unspecified = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Unspecified as i32,
    });
    assert!(!failed(run(&mut engine, unspecified)).is_empty());
    let unknown = command::Kind::AddTrack(AddTrack { kind: 99 });
    assert!(!failed(run(&mut engine, unknown)).is_empty());
}

#[test]
fn undo_and_redo_report_availability() {
    let mut engine = Engine::default();
    add_video_track(&mut engine);
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert!(t.tracks.is_empty());
    assert!(!t.can_undo && t.can_redo);
    let t = changed(run(&mut engine, command::Kind::Redo(Redo {})));
    assert_eq!(t.tracks.len(), 1);
    assert!(t.can_undo && !t.can_redo);
}

#[test]
fn undo_with_nothing_to_undo_fails() {
    let mut engine = Engine::default();
    assert!(!failed(run(&mut engine, command::Kind::Undo(Undo {}))).is_empty());
    assert!(!failed(run(&mut engine, command::Kind::Redo(Redo {}))).is_empty());
}

#[test]
fn get_timeline_reports_state_without_an_undo_step() {
    let mut engine = Engine::default();
    add_video_track(&mut engine);
    run(&mut engine, command::Kind::Undo(Undo {}));
    let t = changed(run(&mut engine, command::Kind::GetTimeline(GetTimeline {})));
    assert!(t.tracks.is_empty());
    assert!(!t.can_undo);
    assert!(t.can_redo, "GetTimeline must not drop the redo step");
}

#[test]
fn tracks_are_numbered_per_kind() {
    let mut engine = Engine::default();
    let add = |engine: &mut Engine, kind: TrackKind| {
        changed(run(
            engine,
            command::Kind::AddTrack(AddTrack { kind: kind as i32 }),
        ))
    };
    add(&mut engine, TrackKind::Audio);
    add(&mut engine, TrackKind::Video);
    let t = add(&mut engine, TrackKind::Video);
    let numbers: Vec<u32> = t.tracks.iter().map(|t| t.number).collect();
    assert_eq!(numbers, [1, 1, 2]);
}
