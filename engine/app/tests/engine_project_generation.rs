//! TimelineChanged.project (P1-062): a new number for each project the engine starts, so the
//! UI knows when to drop what it cached for the old one.

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, NewProject, TimelineChanged, TrackKind, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> TimelineChanged {
    let reply = engine.handle(Command {
        id: 0,
        kind: Some(kind),
    });
    match reply.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn a_new_project_gets_a_new_number_and_edits_keep_it() {
    let mut engine = Engine::default();
    let first = run(&mut engine, command::Kind::GetTimeline(Default::default())).project;
    let edited = run(
        &mut engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    )
    .project;
    assert_eq!(edited, first, "an edit is the same project");
    let next = run(&mut engine, command::Kind::NewProject(NewProject {})).project;
    assert_ne!(next, first);
    let again = run(&mut engine, command::Kind::NewProject(NewProject {})).project;
    assert_ne!(again, next);
}
