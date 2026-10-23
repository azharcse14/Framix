//! TimelineChanged reports the estimated export size (P1-033).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, TimelineChanged, command, event,
};

fn import(engine: &mut Engine, n: u32) -> TimelineChanged {
    let e = engine.handle(Command {
        kind: Some(command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: format!("content://media/external/images/{n}"),
                kind: MediaKind::Image as i32,
                duration_value: 0,
                duration_timescale: 0,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: String::new(),
            }],
        })),
    });
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("{other:?}"),
    }
}

#[test]
fn the_estimate_grows_with_the_timeline() {
    let mut engine = Engine::default();
    let one = import(&mut engine, 1).export.unwrap().estimated_bytes;
    let two = import(&mut engine, 2).export.unwrap().estimated_bytes;
    assert!(one > 0);
    assert!(two > one);
}
