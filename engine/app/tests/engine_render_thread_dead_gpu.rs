//! P1-053 review: with the render thread, a GPU that never draws still answers the texture with
//! CommandFailed (not PreviewReady then PreviewLost, which made Dart ask for a new texture
//! forever), and a draw that panics on the render thread counts as a lost texture.

use std::sync::mpsc::{Receiver, channel};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, ImportMedia, MediaItem, MediaKind, Seek, command, event,
};
use framix_app::render_thread::RenderThread;
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;

struct Host(Arc<Mutex<Vec<i64>>>);

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
    fn release_texture(&self, texture: PlatformTexture) {
        self.0.lock().unwrap().push(texture.id);
    }
}

/// Draw number `fail_from` and later fail: GPU error, or a panic.
struct Gpu {
    draws: u32,
    fail_from: u32,
    panics: bool,
}

impl PreviewRenderer for Gpu {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.draws += 1;
        if self.draws < self.fail_from {
            return Ok(());
        }
        assert!(!self.panics, "draw panicked");
        Err(DrawError::Gpu("no GPU".into()))
    }
}

fn run(engine: &mut Engine, kind: command::Kind) {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    });
}

fn engine(gpu: Gpu, released: Arc<Mutex<Vec<i64>>>) -> (Engine, Receiver<i64>) {
    let (lost_tx, lost) = channel();
    let render = RenderThread::spawn(
        move || Box::new(gpu) as Box<dyn PreviewRenderer>,
        |_| {},
        move |id| {
            let _ = lost_tx.send(id);
        },
    )
    .unwrap();
    let host = render.host(Box::new(Host(released)));
    let mut engine = Engine::default().with_preview(host, Box::new(render));
    run(
        &mut engine,
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
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    (engine, lost)
}

#[test]
fn a_gpu_that_never_draws_answers_the_texture_with_command_failed() {
    let released = Arc::new(Mutex::new(Vec::new()));
    let gpu = Gpu {
        draws: 0,
        fail_from: 1,
        panics: false,
    };
    let (mut engine, lost) = engine(gpu, released.clone());
    let answer = engine.preview_texture_ready(Ok(PlatformTexture { id: 1, handle: 1 }));
    assert!(
        matches!(answer.kind, Some(event::Kind::CommandFailed(_))),
        "{answer:?}"
    );
    assert_eq!(*released.lock().unwrap(), vec![1]);
    assert_eq!(engine.flush_preview(), None);
    assert!(lost.recv_timeout(Duration::from_millis(100)).is_err());
}

#[test]
fn a_redraw_that_panics_on_the_render_thread_is_reported_lost() {
    let released = Arc::new(Mutex::new(Vec::new()));
    let gpu = Gpu {
        draws: 0,
        fail_from: 2,
        panics: true,
    };
    let (mut engine, lost) = engine(gpu, released);
    let answer = engine.preview_texture_ready(Ok(PlatformTexture { id: 1, handle: 1 }));
    assert!(matches!(answer.kind, Some(event::Kind::PreviewReady(_))));
    run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
    assert_eq!(lost.recv_timeout(Duration::from_secs(5)), Ok(1));
}
