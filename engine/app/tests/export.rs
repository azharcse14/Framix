//! run_export with fake renderer and encoder (P1-034).

use std::sync::{Arc, Mutex};

use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Resolution};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;
use framix_core::timeline::Timeline;

#[derive(Debug, Clone, PartialEq)]
enum Call {
    Open(EncoderConfig),
    Frame(Time),
    Draw(i64, Time),
    Finish(bool),
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

struct FakeEncoder {
    log: Log,
    next: i64,
    fail_frame_at: Option<i64>,
}

impl Encoder for FakeEncoder {
    fn frame(&mut self, time: Time) -> Result<PlatformTexture, String> {
        self.log.push(Call::Frame(time));
        if self.fail_frame_at == Some(self.next) {
            return Err("no buffer".into());
        }
        self.next += 1;
        Ok(PlatformTexture {
            id: self.next,
            handle: 0x1000 + self.next as usize,
        })
    }
    fn finish(self: Box<Self>, ok: bool) -> Result<(), String> {
        self.log.push(Call::Finish(ok));
        Ok(())
    }
}

struct FakeHost {
    log: Log,
    refuse: bool,
    fail_frame_at: Option<i64>,
}

impl EncoderHost for FakeHost {
    fn open(&self, config: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        self.log.push(Call::Open(config.clone()));
        if self.refuse {
            return Err("no encoder".into());
        }
        Ok(Box::new(FakeEncoder {
            log: self.log.clone(),
            next: 0,
            fail_frame_at: self.fail_frame_at,
        }))
    }
}

struct FakeRenderer {
    log: Log,
    fail_at: Option<usize>,
    draws: usize,
}

impl PreviewRenderer for FakeRenderer {
    fn draw(
        &mut self,
        target: PlatformTexture,
        time: Time,
        _: Option<&Layer>,
    ) -> Result<(), DrawError> {
        self.log.push(Call::Draw(target.id, time));
        self.draws += 1;
        if self.fail_at == Some(self.draws) {
            return Err(DrawError::Gpu("gpu".into()));
        }
        Ok(())
    }
}

/// A timeline with one video clip of `ticks`, export at `settings`, 16:9 canvas.
fn timeline(ticks: i64, settings: ExportSettings) -> Timeline {
    let mut tl = Timeline::default();
    tl.set_aspect(AspectRatio::new(16, 9).unwrap());
    tl.set_export(settings);
    let video = Media::validate(RawMedia {
        uri: "media/v.mov".into(),
        kind: MediaKind::Video,
        duration_value: ticks,
        duration_timescale: TICKS_PER_SECOND as u32,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    tl.import(vec![video]).unwrap();
    assert_eq!(tl.duration(), Time(ticks));
    tl
}

fn parts(fail_frame_at: Option<i64>, fail_draw_at: Option<usize>) -> (Log, FakeHost, FakeRenderer) {
    let log = Log::default();
    (
        log.clone(),
        FakeHost {
            log: log.clone(),
            refuse: false,
            fail_frame_at,
        },
        FakeRenderer {
            log,
            fail_at: fail_draw_at,
            draws: 0,
        },
    )
}

#[test]
fn every_frame_is_drawn_into_the_encoders_buffer() {
    let (log, host, mut renderer) = parts(None, None);
    let tl = timeline(TICKS_PER_SECOND / 10, ExportSettings::default());
    run_export(&tl, &mut renderer, &host, "/out.mp4").unwrap();
    let calls = log.calls();
    assert_eq!(
        calls[0],
        Call::Open(EncoderConfig {
            width: 1920,
            height: 1080,
            fps: 30,
            kbps: ExportSettings::default().effective_kbps(AspectRatio::new(16, 9).unwrap()),
            path: "/out.mp4".into(),
        })
    );
    // 0.1 s at 30 fps is 3 frames; each frame's buffer is drawn at that frame's time.
    let rate = FrameRate::F30.rate();
    let mut expected = Vec::new();
    for n in 0..3 {
        let t = rate.frame_to_time(n).unwrap();
        expected.push(Call::Frame(t));
        expected.push(Call::Draw(n + 1, t));
    }
    expected.push(Call::Finish(true));
    assert_eq!(calls[1..], expected[..]);
}

#[test]
fn a_partial_last_frame_is_still_encoded() {
    let (log, host, mut renderer) = parts(None, None);
    // Just over 2 s at 24 fps: 48 whole frames plus a partial one.
    let settings = ExportSettings {
        resolution: Resolution::P720,
        fps: FrameRate::F24,
        bitrate: Bitrate::kbps(5_000).unwrap(),
    };
    let tl = timeline(2 * TICKS_PER_SECOND + 1, settings);
    run_export(&tl, &mut renderer, &host, "/a.mp4").unwrap();
    let frames = log
        .calls()
        .iter()
        .filter(|c| matches!(c, Call::Frame(_)))
        .count();
    assert_eq!(frames, 49);
    match &log.calls()[0] {
        Call::Open(c) => assert_eq!((c.width, c.height, c.fps, c.kbps), (1280, 720, 24, 5_000)),
        other => panic!("{other:?}"),
    }
}

#[test]
fn a_draw_failure_cancels_the_file() {
    let (log, host, mut renderer) = parts(None, Some(2));
    let tl = timeline(TICKS_PER_SECOND, ExportSettings::default());
    assert!(run_export(&tl, &mut renderer, &host, "/x.mp4").is_err());
    assert_eq!(log.calls().last(), Some(&Call::Finish(false)));
    assert_eq!(
        log.calls()
            .iter()
            .filter(|c| matches!(c, Call::Draw(..)))
            .count(),
        2
    );
}

#[test]
fn a_buffer_failure_cancels_the_file() {
    let (log, host, mut renderer) = parts(Some(1), None);
    let tl = timeline(TICKS_PER_SECOND, ExportSettings::default());
    assert!(run_export(&tl, &mut renderer, &host, "/x.mp4").is_err());
    assert_eq!(log.calls().last(), Some(&Call::Finish(false)));
}

#[test]
fn an_encoder_that_will_not_open_is_an_error() {
    let (log, mut host, mut renderer) = parts(None, None);
    host.refuse = true;
    let tl = timeline(TICKS_PER_SECOND, ExportSettings::default());
    assert!(run_export(&tl, &mut renderer, &host, "/x.mp4").is_err());
    assert_eq!(log.calls().len(), 1, "nothing after the failed open");
}
