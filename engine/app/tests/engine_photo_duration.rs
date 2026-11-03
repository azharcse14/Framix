//! SetPhotoDuration (P1-028): every photo gets one duration in a single undo step.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SetPhotoDuration, TimelineChanged, Undo, command,
    event,
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

fn item(uri: &str, kind: MediaKind) -> MediaItem {
    MediaItem {
        color: 0,
        uri: uri.into(),
        kind: kind as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: "avc1".into(),
    }
}

fn spans(t: &TimelineChanged) -> Vec<(i64, i64)> {
    let tps = t.ticks_per_second as i64;
    t.tracks[0]
        .clips
        .iter()
        .map(|c| (c.start / tps, c.duration / tps))
        .collect()
}

fn set(duration: i64) -> command::Kind {
    command::Kind::SetPhotoDuration(SetPhotoDuration { duration })
}

#[test]
fn photos_get_one_duration_as_one_undo_step() {
    let mut engine = Engine::default();
    let items = vec![
        item("content://media/external/images/1", MediaKind::Image),
        item("content://media/external/video/2", MediaKind::Video),
        item("content://media/external/images/3", MediaKind::Image),
    ];
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    ));
    assert_eq!(spans(&t), [(0, 3), (3, 2), (5, 3)]);
    let tps = t.ticks_per_second as i64;

    let t = changed(run(&mut engine, set(tps)));
    assert_eq!(spans(&t), [(0, 1), (1, 2), (3, 1)]);

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(spans(&t), [(0, 3), (3, 2), (5, 3)], "one step undoes all");
}

#[test]
fn a_non_positive_duration_is_refused() {
    let mut engine = Engine::default();
    let failed = run(&mut engine, set(0));
    assert!(
        matches!(failed, Some(event::Kind::CommandFailed(_))),
        "got {failed:?}"
    );
}
