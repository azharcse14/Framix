//! UX-035: a CreatePreview that fails after it was accepted (the platform or the GPU could not
//! make the texture) answers with id 0, so its CommandFailed carries FAILURE_KIND_PREVIEW; the
//! UI tells it from other id-0 failures and shows "preview unavailable" in the canvas.

use framix_app::engine::Engine;
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

struct Gpu {
    fail: bool,
}

impl PreviewRenderer for Gpu {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        if self.fail {
            return Err(DrawError::Gpu("device lost".into()));
        }
        Ok(())
    }
}

fn engine(gpu_fails: bool) -> Engine {
    Engine::default().with_preview(Box::new(Host), Box::new(Gpu { fail: gpu_fails }))
}

fn request(engine: &mut Engine) {
    engine.handle(Command {
        id: 3,
        kind: Some(command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        })),
    });
}

/// The failure's kind by name, so the test compiles before the kind exists.
fn kind_name(answer: &Event) -> &'static str {
    let Some(event::Kind::CommandFailed(failed)) = &answer.kind else {
        panic!("not a CommandFailed: {answer:?}");
    };
    assert_eq!(failed.command_id, 0, "{answer:?}");
    FailureKind::try_from(failed.kind)
        .map(|k| k.as_str_name())
        .unwrap_or("unknown kind")
}

#[test]
fn a_platform_that_cannot_make_the_texture_fails_as_a_preview_failure() {
    let mut engine = engine(false);
    request(&mut engine);
    let answer = engine.preview_texture_ready(Err("no surface".into()));
    assert_eq!(kind_name(&answer), "FAILURE_KIND_PREVIEW");
}

#[test]
fn a_gpu_that_cannot_draw_the_first_frame_fails_as_a_preview_failure() {
    let mut engine = engine(true);
    request(&mut engine);
    let answer = engine.preview_texture_ready(Ok(PlatformTexture { id: 1, handle: 1 }));
    assert_eq!(kind_name(&answer), "FAILURE_KIND_PREVIEW");
}

#[test]
fn a_stray_answer_nobody_asked_for_is_no_preview_failure() {
    // A shown preview must not be called unavailable because of an answer to nothing.
    let mut engine = engine(false);
    let answer = engine.preview_texture_ready(Err("no surface".into()));
    assert_eq!(kind_name(&answer), "FAILURE_KIND_UNSPECIFIED");
}
