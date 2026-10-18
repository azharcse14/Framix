//! CreatePreview through the preview ports (P1-005, docs/adr/0003-platform-callbacks.md).

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{Command, CreatePreview, PreviewReady, command, event};

/// What the fakes saw, in order.
#[derive(Debug, PartialEq)]
enum Call {
    CreateTexture(u32, u32),
    Draw(PlatformTexture),
    FrameAvailable(i64),
}

type Log = Arc<Mutex<Vec<Call>>>;

struct FakeHost {
    log: Log,
    refuse: bool,
}

impl PreviewHost for FakeHost {
    fn create_texture(&self, width: u32, height: u32) -> Result<(), String> {
        if self.refuse {
            return Err("no platform".into());
        }
        self.log
            .lock()
            .unwrap()
            .push(Call::CreateTexture(width, height));
        Ok(())
    }

    fn frame_available(&self, id: i64) {
        self.log.lock().unwrap().push(Call::FrameAvailable(id));
    }
}

struct FakeRenderer {
    log: Log,
    fail: bool,
}

impl PreviewRenderer for FakeRenderer {
    fn draw(&mut self, target: PlatformTexture) -> Result<(), String> {
        if self.fail {
            return Err("device lost".into());
        }
        self.log.lock().unwrap().push(Call::Draw(target));
        Ok(())
    }
}

fn engine(refuse: bool, fail: bool) -> (Engine, Log) {
    let log = Log::default();
    let engine = Engine::default().with_preview(
        Box::new(FakeHost {
            log: log.clone(),
            refuse,
        }),
        Box::new(FakeRenderer {
            log: log.clone(),
            fail,
        }),
    );
    (engine, log)
}

fn create(width: u32, height: u32) -> Command {
    Command {
        kind: Some(command::Kind::CreatePreview(CreatePreview {
            width,
            height,
        })),
    }
}

fn kind(e: framix_app::proto::Event) -> event::Kind {
    e.kind.expect("event has a kind")
}

const TEXTURE: PlatformTexture = PlatformTexture {
    id: 7,
    handle: 0x1234,
};

#[test]
fn create_is_accepted_and_asks_the_platform_for_a_texture() {
    let (mut engine, log) = engine(false, false);
    assert_eq!(
        kind(engine.handle(create(1280, 720))),
        event::Kind::CommandAccepted(Default::default())
    );
    assert_eq!(*log.lock().unwrap(), [Call::CreateTexture(1280, 720)]);
}

#[test]
fn a_ready_texture_is_drawn_signalled_and_reported() {
    let (mut engine, log) = engine(false, false);
    engine.handle(create(1280, 720));
    assert_eq!(
        kind(engine.preview_texture_ready(Ok(TEXTURE))),
        event::Kind::PreviewReady(PreviewReady { texture_id: 7 })
    );
    assert_eq!(
        *log.lock().unwrap(),
        [
            Call::CreateTexture(1280, 720),
            Call::Draw(TEXTURE),
            Call::FrameAvailable(7)
        ]
    );
}

#[test]
fn a_platform_failure_is_reported_and_nothing_is_drawn() {
    let (mut engine, log) = engine(false, false);
    engine.handle(create(1280, 720));
    assert!(matches!(
        kind(engine.preview_texture_ready(Err("no IOSurface".into()))),
        event::Kind::CommandFailed(_)
    ));
    assert_eq!(*log.lock().unwrap(), [Call::CreateTexture(1280, 720)]);
}

#[test]
fn a_draw_failure_is_reported_and_no_frame_is_signalled() {
    let (mut engine, log) = engine(false, true);
    engine.handle(create(1280, 720));
    assert!(matches!(
        kind(engine.preview_texture_ready(Ok(TEXTURE))),
        event::Kind::CommandFailed(_)
    ));
    assert_eq!(*log.lock().unwrap(), [Call::CreateTexture(1280, 720)]);
}

#[test]
fn bad_sizes_are_refused_before_asking_the_platform() {
    for (w, h) in [(0, 720), (1280, 0), (8193, 720), (1280, 8193)] {
        let (mut engine, log) = engine(false, false);
        assert!(
            matches!(
                kind(engine.handle(create(w, h))),
                event::Kind::CommandFailed(_)
            ),
            "{w}x{h}"
        );
        assert!(log.lock().unwrap().is_empty(), "{w}x{h}");
    }
    let (mut engine, _) = engine(false, false);
    assert!(matches!(
        kind(engine.handle(create(8192, 8192))),
        event::Kind::CommandAccepted(_)
    ));
}

#[test]
fn create_fails_when_the_platform_refuses() {
    let (mut engine, _) = engine(true, false);
    assert!(matches!(
        kind(engine.handle(create(1280, 720))),
        event::Kind::CommandFailed(_)
    ));
}

#[test]
fn create_fails_without_a_preview() {
    assert!(matches!(
        kind(Engine::default().handle(create(1280, 720))),
        event::Kind::CommandFailed(_)
    ));
}

#[test]
fn a_texture_nobody_asked_for_is_refused() {
    let (mut engine, log) = engine(false, false);
    assert!(matches!(
        kind(engine.preview_texture_ready(Ok(TEXTURE))),
        event::Kind::CommandFailed(_)
    ));
    assert!(log.lock().unwrap().is_empty());
}
