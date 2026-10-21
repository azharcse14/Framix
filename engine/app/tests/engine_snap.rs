//! Seek with snapping (P1-022).

use framix_app::engine::Engine;
use framix_app::proto::{Command, Event, ImportMedia, MediaItem, MediaKind, Seek, command, event};
use framix_core::time::TICKS_PER_SECOND;

const SECOND: i64 = TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

/// Two videos back to back: [0, 2 s) and [2 s, 5 s).
fn engine() -> Engine {
    let mut engine = Engine::default();
    let items = [2, 3]
        .iter()
        .enumerate()
        .map(|(i, s)| MediaItem {
            uri: format!("content://media/external/video/{i}"),
            kind: MediaKind::Video as i32,
            duration_value: s * 1000,
            duration_timescale: 1000,
            width: 1080,
            height: 1920,
            rotation: 0,
            codec: String::new(),
        })
        .collect();
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    );
    engine
}

fn seek(engine: &mut Engine, time: i64, snap_within: i64) -> Event {
    run(engine, command::Kind::Seek(Seek { time, snap_within }))
}

fn landed(e: Event) -> (i64, bool) {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => (p.time, p.snapped),
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

#[test]
fn a_seek_near_an_edge_snaps_to_it() {
    let mut engine = engine();
    let near = 2 * SECOND + SECOND / 20;
    assert_eq!(
        landed(seek(&mut engine, near, SECOND / 10)),
        (2 * SECOND, true)
    );
}

#[test]
fn without_a_tolerance_nothing_snaps() {
    let mut engine = engine();
    let near = 2 * SECOND + SECOND / 20;
    assert_eq!(landed(seek(&mut engine, near, 0)), (near, false));
}

#[test]
fn far_from_edges_it_does_not_snap() {
    let mut engine = engine();
    assert_eq!(
        landed(seek(&mut engine, SECOND, SECOND / 10)),
        (SECOND, false)
    );
}

#[test]
fn a_huge_tolerance_is_capped_at_ten_seconds() {
    let mut engine = engine();
    // 3.5 s is 1.5 s from 2 s and 5 s; a 100 s radius would snap, the 10 s cap still does,
    // so check the cap with a point farther than 10 s from every edge instead.
    let mut long = Engine::default();
    run(
        &mut long,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/video/9".into(),
                kind: MediaKind::Video as i32,
                duration_value: 60_000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: String::new(),
            }],
        }),
    );
    assert_eq!(
        landed(seek(&mut long, 30 * SECOND, 100 * SECOND)),
        (30 * SECOND, false)
    );
    assert_eq!(
        landed(seek(&mut engine, 3 * SECOND, 100 * SECOND)),
        (2 * SECOND, true)
    );
}

#[test]
fn a_negative_tolerance_is_refused() {
    let mut engine = engine();
    assert!(matches!(
        seek(&mut engine, SECOND, -1).kind,
        Some(event::Kind::CommandFailed(_))
    ));
}
