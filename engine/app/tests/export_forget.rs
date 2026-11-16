//! run_export lets the renderer forget the encoder's render target once the encoder finished
//! (P1-069): on Android the renderer keeps a wgpu surface on the codec's input window, and
//! dropping it before the codec drained could lose queued frames.

use std::sync::{Arc, Mutex};

use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Resolution};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Layer, Timeline};

#[derive(Debug, Clone, PartialEq)]
enum Call {
    Draw(usize),
    Finish(bool),
    Forget(usize),
}

#[derive(Clone, Default)]
struct Log(Arc<Mutex<Vec<Call>>>);

impl Log {
    fn push(&self, c: Call) {
        self.0.lock().unwrap().push(c);
    }
    fn calls(&self) -> Vec<Call> {
        self.0.lock().unwrap().clone()
    }
}

/// Hands out the same window every frame, like the Android codec's input Surface.
const WINDOW: usize = 0xA11;

struct Window {
    log: Log,
    fail_first_frame: bool,
}

impl Encoder for Window {
    fn frame(&mut self, _: Time) -> Result<PlatformTexture, String> {
        if self.fail_first_frame {
            return Err("no buffer".into());
        }
        Ok(PlatformTexture {
            id: 0,
            handle: WINDOW,
        })
    }
    fn finish(self: Box<Self>, ok: bool) -> Result<(), String> {
        self.log.push(Call::Finish(ok));
        Ok(())
    }
}

struct Host {
    log: Log,
    fail_first_frame: bool,
}

impl EncoderHost for Host {
    fn open(&self, _: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        Ok(Box::new(Window {
            log: self.log.clone(),
            fail_first_frame: self.fail_first_frame,
        }))
    }
}

struct Renderer {
    log: Log,
    fail: bool,
}

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        target: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.log.push(Call::Draw(target.handle));
        if self.fail {
            return Err(DrawError::Gpu("gpu".into()));
        }
        Ok(())
    }
    fn forget(&mut self, target: PlatformTexture) {
        self.log.push(Call::Forget(target.handle));
    }
}

/// Two frames of video at 30 fps.
fn timeline() -> Timeline {
    let mut tl = Timeline::default();
    tl.set_aspect(AspectRatio::new(16, 9).unwrap());
    tl.set_export(ExportSettings {
        resolution: Resolution::P720,
        fps: FrameRate::F30,
        bitrate: Bitrate::Auto,
    });
    let video = Media::validate(RawMedia {
        uri: "media/v.mov".into(),
        kind: MediaKind::Video,
        duration_value: 2 * TICKS_PER_SECOND / 30,
        duration_timescale: TICKS_PER_SECOND as u32,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    tl.import(vec![video]).unwrap();
    tl
}

fn export(fail_first_frame: bool, fail_draw: bool) -> Vec<Call> {
    let log = Log::default();
    let host = Host {
        log: log.clone(),
        fail_first_frame,
    };
    let mut renderer = Renderer {
        log: log.clone(),
        fail: fail_draw,
    };
    let _ = run_export(&timeline(), &mut renderer, &host, "out.mp4");
    log.calls()
}

#[test]
fn the_target_is_forgotten_once_the_encoder_finished() {
    assert_eq!(
        export(false, false),
        vec![
            Call::Draw(WINDOW),
            Call::Draw(WINDOW),
            Call::Finish(true),
            Call::Forget(WINDOW),
        ]
    );
}

#[test]
fn a_failed_draw_still_forgets_the_target_after_the_cancel() {
    assert_eq!(
        export(false, true),
        vec![
            Call::Draw(WINDOW),
            Call::Finish(false),
            Call::Forget(WINDOW)
        ]
    );
}

#[test]
fn nothing_is_forgotten_when_no_target_was_handed_out() {
    assert_eq!(export(true, false), vec![Call::Finish(false)]);
}
