//! TrimToPlayhead (P1-081): the engine trims one edge to its own playhead and keeps the other
//! edge from its own clip, so quick taps never send stale values.

use framix_app::engine::Engine;
use framix_app::proto::{
    ClipEdge, Command, ImportMedia, MediaItem, MediaKind, Seek, TimelineChanged, TrimToPlayhead,
    Undo, command, event,
};
use framix_core::time::TICKS_PER_SECOND;

const S: i64 = TICKS_PER_SECOND;

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

fn seek(engine: &mut Engine, time: i64) {
    run(
        engine,
        command::Kind::Seek(Seek {
            time,
            snap_within: 0,
        }),
    );
}

fn trim(clip_id: u64, edge: ClipEdge) -> command::Kind {
    command::Kind::TrimToPlayhead(TrimToPlayhead {
        clip_id,
        edge: edge as i32,
    })
}

/// An engine holding one 2 s video; returns it and the clip id.
fn with_video() -> (Engine, u64) {
    let mut engine = Engine::default();
    let item = MediaItem {
        color: 0,
        uri: "content://media/external/video/1".into(),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: "avc1".into(),
    };
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items: vec![item] }),
    ));
    let clip = t.tracks[0].clips[0].id;
    (engine, clip)
}

fn span(t: &TimelineChanged) -> (i64, i64, i64) {
    let c = &t.tracks[0].clips[0];
    (c.start, c.duration, c.source_start)
}

#[test]
fn trims_each_edge_to_the_playhead() {
    let (mut engine, clip) = with_video();
    seek(&mut engine, S / 2);
    let t = changed(run(&mut engine, trim(clip, ClipEdge::Start)));
    assert_eq!(span(&t), (S / 2, 3 * S / 2, S / 2));

    seek(&mut engine, S);
    // The start edge is the engine's own, not a value the UI last saw.
    let t = changed(run(&mut engine, trim(clip, ClipEdge::End)));
    assert_eq!(span(&t), (S / 2, S / 2, S / 2));

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(span(&t), (S / 2, 3 * S / 2, S / 2), "one undo step each");
}

#[test]
fn an_edge_past_the_other_or_no_edge_is_refused() {
    let (mut engine, clip) = with_video();
    seek(&mut engine, 0);
    let refused = |e: Option<event::Kind>| matches!(e, Some(event::Kind::CommandFailed(_)));
    assert!(refused(run(&mut engine, trim(clip, ClipEdge::End))));
    assert!(refused(run(&mut engine, trim(clip, ClipEdge::Unspecified))));
    assert!(refused(run(&mut engine, trim(clip + 99, ClipEdge::Start))));
}
