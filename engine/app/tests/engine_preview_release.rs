//! Preview textures go back to the platform (P1-055): every texture the engine stops using is
//! released once, after the renderer forgot it, and never one still shown.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, Seek, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;

/// What the fakes saw, in order.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Seen {
    Forgot(i64),
    Released(i64),
}

type Log = Arc<Mutex<Vec<Seen>>>;

struct Host(Log);

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
    fn release_texture(&self, texture: PlatformTexture) {
        self.0.lock().unwrap().push(Seen::Released(texture.id));
    }
}

/// Draws fail with a GPU error into the texture ids in `lose`.
struct Renderer {
    log: Log,
    lose: Arc<Mutex<Vec<i64>>>,
}

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        target: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        if self.lose.lock().unwrap().contains(&target.id) {
            return Err(DrawError::Gpu("lost".into()));
        }
        Ok(())
    }
    fn forget(&mut self, target: PlatformTexture) {
        self.log.lock().unwrap().push(Seen::Forgot(target.id));
    }
}

struct Fixture {
    engine: Engine,
    log: Log,
    lose: Arc<Mutex<Vec<i64>>>,
}

fn fixture() -> Fixture {
    let log = Log::default();
    let lose = Arc::new(Mutex::new(Vec::new()));
    let engine = Engine::default().with_preview(
        Box::new(Host(log.clone())),
        Box::new(Renderer {
            log: log.clone(),
            lose: lose.clone(),
        }),
    );
    Fixture { engine, log, lose }
}

fn texture(id: i64) -> PlatformTexture {
    PlatformTexture {
        id,
        handle: 100 + id as usize,
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn request(engine: &mut Engine) {
    run(
        engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
}

/// Requests and shows texture `id`.
fn show(f: &mut Fixture, id: i64) -> Event {
    request(&mut f.engine);
    f.engine.preview_texture_ready(Ok(texture(id)))
}

fn seen(f: &Fixture) -> Vec<Seen> {
    f.log.lock().unwrap().clone()
}

fn forgot_then_released(id: i64) -> Vec<Seen> {
    vec![Seen::Forgot(id), Seen::Released(id)]
}

#[test]
fn a_new_preview_releases_the_one_shown_before() {
    let mut f = fixture();
    show(&mut f, 1);
    assert_eq!(seen(&f), vec![], "the only preview stays");
    let ready = show(&mut f, 2);
    assert!(matches!(ready.kind, Some(event::Kind::PreviewReady(_))));
    assert_eq!(seen(&f), forgot_then_released(1));
}

#[test]
fn a_texture_the_first_draw_fails_on_is_released() {
    let mut f = fixture();
    f.lose.lock().unwrap().push(1);
    let failed = show(&mut f, 1);
    assert!(matches!(failed.kind, Some(event::Kind::CommandFailed(_))));
    assert_eq!(seen(&f), forgot_then_released(1));
}

#[test]
fn a_failed_new_texture_leaves_the_shown_one() {
    let mut f = fixture();
    show(&mut f, 1);
    f.lose.lock().unwrap().push(2);
    show(&mut f, 2);
    assert_eq!(seen(&f), forgot_then_released(2));
}

#[test]
fn a_texture_nobody_asked_for_is_released() {
    let mut f = fixture();
    let refused = f.engine.preview_texture_ready(Ok(texture(5)));
    assert!(matches!(refused.kind, Some(event::Kind::CommandFailed(_))));
    assert_eq!(seen(&f), forgot_then_released(5));
}

#[test]
fn a_texture_a_redraw_loses_is_released_and_reported() {
    let mut f = fixture();
    run(
        &mut f.engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                color: 0,
                uri: "content://media/external/video/0".into(),
                kind: MediaKind::Video as i32,
                duration_value: 4000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: "avc1".into(),
            }],
        }),
    );
    show(&mut f, 1);
    f.lose.lock().unwrap().push(1);
    run(
        &mut f.engine,
        command::Kind::Seek(Seek {
            time: TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
    let lost = f.engine.flush_preview().expect("PreviewLost");
    assert!(matches!(lost.kind, Some(event::Kind::PreviewLost(_))));
    assert_eq!(seen(&f), forgot_then_released(1));
}

#[test]
fn dropping_the_engine_releases_the_shown_texture() {
    let mut f = fixture();
    show(&mut f, 1);
    let log = f.log.clone();
    drop(f);
    assert_eq!(*log.lock().unwrap(), forgot_then_released(1));
}
