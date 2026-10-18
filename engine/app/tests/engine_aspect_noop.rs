//! P1-010 review: setting the ratio the timeline already has is not an edit.
use framix_app::engine::Engine;
use framix_app::proto::{AddTrack, Command, SetAspectRatio, TrackKind, Undo, command, event};
use framix_core::aspect::AspectRatio;

fn run(engine: &mut Engine, kind: command::Kind) -> (bool, bool) {
    match engine.handle(Command { kind: Some(kind) }).kind {
        Some(event::Kind::TimelineChanged(t)) => (t.can_undo, t.can_redo),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn setting_the_current_ratio_keeps_undo_and_redo() {
    let mut engine = Engine::default();
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Video as i32,
    });
    run(&mut engine, add.clone());
    run(&mut engine, add);
    assert_eq!(run(&mut engine, command::Kind::Undo(Undo {})), (true, true));
    // 18:32 reduces to the current 9:16.
    let same = command::Kind::SetAspectRatio(SetAspectRatio {
        width: 18,
        height: 32,
    });
    assert_eq!(run(&mut engine, same.clone()), (true, true), "redo kept");
    assert_eq!(
        run(&mut engine, command::Kind::Undo(Undo {})),
        (false, true)
    );
    assert_eq!(run(&mut engine, same), (false, true), "no undo step added");
}

#[test]
fn boundary_ratios_are_accepted() {
    for (w, h) in [(3, 1), (1, 3), (100, 99), (100, 100)] {
        assert!(AspectRatio::new(w, h).is_some(), "{w}:{h}");
    }
}
