use framix_app::engine::Engine;
use framix_app::proto::{
    Command, GetTimeline, SetAspectRatio, TimelineChanged, Undo, command, event,
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

fn set(width: u32, height: u32) -> command::Kind {
    command::Kind::SetAspectRatio(SetAspectRatio { width, height })
}

#[test]
fn the_timeline_reports_the_default_aspect() {
    let t = changed(run(
        &mut Engine::default(),
        command::Kind::GetTimeline(GetTimeline {}),
    ));
    assert_eq!((t.aspect_width, t.aspect_height), (9, 16));
}

#[test]
fn set_aspect_ratio_is_reduced_and_undoable() {
    let mut engine = Engine::default();
    let t = changed(run(&mut engine, set(32, 18)));
    assert_eq!((t.aspect_width, t.aspect_height), (16, 9));
    assert!(t.can_undo);
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!((t.aspect_width, t.aspect_height), (9, 16));
}

#[test]
fn invalid_aspect_ratios_are_rejected() {
    let mut engine = Engine::default();
    for (w, h) in [(0, 9), (9, 0), (5, 1)] {
        let e = run(&mut engine, set(w, h));
        assert!(
            matches!(e, Some(event::Kind::CommandFailed(_))),
            "{w}:{h} {e:?}"
        );
    }
}
