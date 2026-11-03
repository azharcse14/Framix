//! ExportInfo carries the bitrate range a user may set, so the UI never repeats the rule
//! (P1-064).

use framix_app::engine::Engine;
use framix_app::proto::{Command, GetTimeline, command, event};
use framix_core::export::KBPS_RANGE;

#[test]
fn the_settable_bitrate_range_is_reported() {
    let mut engine = Engine::default();
    let reply = engine.handle(Command {
        id: 0,
        kind: Some(command::Kind::GetTimeline(GetTimeline {})),
    });
    let Some(event::Kind::TimelineChanged(t)) = reply.kind else {
        panic!("expected TimelineChanged, got {reply:?}");
    };
    let e = t.export.expect("export info");
    assert_eq!(
        (e.min_kbps, e.max_kbps),
        (*KBPS_RANGE.start(), *KBPS_RANGE.end())
    );
}
