//! UX-035 re-review: a panic while answering a CreatePreview is a preview failure
//! (FAILURE_KIND_PREVIEW) only while a CreatePreview awaits its answer; a panic on an answer
//! nobody asked for is a plain internal error.

use framix_app::engine::{Engine, preview_answer_panicked};
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{Command, CreatePreview, Event, FailureKind, command, event};
use framix_core::time::Time;
use framix_core::timeline::Layer;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

struct Gpu;

impl PreviewRenderer for Gpu {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        Ok(())
    }
}

fn engine() -> Engine {
    Engine::default().with_preview(Box::new(Host), Box::new(Gpu))
}

fn kind(answer: &Event) -> FailureKind {
    let Some(event::Kind::CommandFailed(failed)) = &answer.kind else {
        panic!("not a CommandFailed: {answer:?}");
    };
    assert_eq!(failed.command_id, 0, "{answer:?}");
    FailureKind::try_from(failed.kind).unwrap()
}

#[test]
fn a_panic_while_a_create_preview_awaits_its_answer_is_a_preview_failure() {
    let mut engine = engine();
    engine.handle(Command {
        id: 3,
        kind: Some(command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        })),
    });
    assert!(engine.awaits_preview());
    let answer = preview_answer_panicked(engine.awaits_preview());
    assert_eq!(kind(&answer), FailureKind::Preview);
}

#[test]
fn a_panic_on_an_answer_nobody_asked_for_is_no_preview_failure() {
    let engine = engine();
    assert!(!engine.awaits_preview());
    let answer = preview_answer_panicked(engine.awaits_preview());
    assert_eq!(kind(&answer), FailureKind::Unspecified);
}
