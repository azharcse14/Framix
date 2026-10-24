//! run_export_with: progress, cancel and failures (P1-035).

use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use framix_app::export::{Encoder, EncoderConfig, EncoderHost, ExportError, run_export_with};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;
use framix_core::timeline::Timeline;

/// Counts frames and records how the file was finished; cancels before frame `cancel_at`.
struct Enc {
    frames: Arc<AtomicUsize>,
    finished: Arc<Mutex<Option<bool>>>,
    cancel_at: Option<(usize, Arc<AtomicBool>)>,
    fail: bool,
}

impl Encoder for Enc {
    fn frame(&mut self, _: Time) -> Result<PlatformTexture, String> {
        if self.fail {
            return Err("no buffer".into());
        }
        let n = self.frames.fetch_add(1, Ordering::SeqCst) + 1;
        if let Some((at, flag)) = &self.cancel_at
            && n == *at
        {
            flag.store(true, Ordering::SeqCst);
        }
        Ok(PlatformTexture { id: 1, handle: 1 })
    }
    fn finish(self: Box<Self>, ok: bool) -> Result<(), String> {
        *self.finished.lock().unwrap() = Some(ok);
        Ok(())
    }
}

struct Host {
    frames: Arc<AtomicUsize>,
    finished: Arc<Mutex<Option<bool>>>,
    cancel_at: Option<(usize, Arc<AtomicBool>)>,
    fail: bool,
}

impl EncoderHost for Host {
    fn open(&self, _: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        Ok(Box::new(Enc {
            frames: self.frames.clone(),
            finished: self.finished.clone(),
            cancel_at: self.cancel_at.clone(),
            fail: self.fail,
        }))
    }
}

struct Draw;
impl PreviewRenderer for Draw {
    fn draw(&mut self, _: PlatformTexture, _: Time, _: Option<&Layer>) -> Result<(), DrawError> {
        Ok(())
    }
}

fn host(cancel_at: Option<(usize, Arc<AtomicBool>)>, fail: bool) -> Host {
    Host {
        frames: Arc::default(),
        finished: Arc::default(),
        cancel_at,
        fail,
    }
}

/// `seconds` of one video clip; 30 fps by default.
fn timeline(seconds: i64) -> Timeline {
    let mut tl = Timeline::default();
    let video = Media::validate(RawMedia {
        uri: "media/v.mov".into(),
        kind: MediaKind::Video,
        duration_value: seconds,
        duration_timescale: 1,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    tl.import(vec![video]).unwrap();
    assert_eq!(tl.duration(), Time(seconds * TICKS_PER_SECOND));
    tl
}

#[test]
fn progress_is_one_per_percent_rising_and_ends_at_the_last_frame() {
    let h = host(None, false);
    let mut seen = Vec::new();
    // 20 s at 30 fps: 600 frames.
    run_export_with(
        &timeline(20),
        &mut Draw,
        &h,
        "/o.mp4",
        &AtomicBool::new(false),
        &mut |f, n| seen.push((f, n)),
    )
    .unwrap();
    assert!(seen.len() <= 101, "{}", seen.len());
    assert!(seen.len() >= 100);
    assert!(seen.windows(2).all(|w| w[0].0 < w[1].0));
    assert!(seen.iter().all(|&(_, n)| n == 600));
    assert_eq!(seen.last(), Some(&(600, 600)));
}

#[test]
fn a_short_export_still_reports_its_last_frame() {
    let h = host(None, false);
    let mut seen = Vec::new();
    run_export_with(
        &timeline(1),
        &mut Draw,
        &h,
        "/o.mp4",
        &AtomicBool::new(false),
        &mut |f, n| seen.push((f, n)),
    )
    .unwrap();
    assert_eq!(seen.last(), Some(&(30, 30)));
}

#[test]
fn cancel_stops_at_the_next_frame_and_cancels_the_file() {
    let flag = Arc::new(AtomicBool::new(false));
    let h = host(Some((5, flag.clone())), false);
    let result = run_export_with(
        &timeline(10),
        &mut Draw,
        &h,
        "/o.mp4",
        &flag,
        &mut |_, _| {},
    );
    assert_eq!(result, Err(ExportError::Cancelled));
    assert_eq!(h.frames.load(Ordering::SeqCst), 5);
    assert_eq!(*h.finished.lock().unwrap(), Some(false));
}

#[test]
fn a_failure_says_why() {
    let h = host(None, true);
    let result = run_export_with(
        &timeline(1),
        &mut Draw,
        &h,
        "/o.mp4",
        &AtomicBool::new(false),
        &mut |_, _| {},
    );
    assert_eq!(result, Err(ExportError::Failed("no buffer".into())));
    assert_eq!(*h.finished.lock().unwrap(), Some(false));
}
