//! Export: renders every frame of a timeline snapshot into buffers the platform encoder owns
//! (docs/adr/0005-export-encoder.md). Runs on the export worker, never the engine thread.

use std::sync::Arc;
use std::sync::atomic::AtomicBool;

use framix_core::time::Time;
use framix_core::timeline::Timeline;

use crate::preview::{PlatformTexture, PreviewRenderer};

/// What the platform encoder is opened with.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncoderConfig {
    /// Frame width in pixels (even).
    pub width: u32,
    /// Frame height in pixels (even).
    pub height: u32,
    /// Frames per second.
    pub fps: u32,
    /// Video bitrate in kbit/s.
    pub kbps: u32,
    /// Where the file goes.
    pub path: String,
}

/// One open platform encoder. Calls block; they run on the export worker.
pub trait Encoder: Send {
    /// The buffer for the frame at `time`, as a render target. The previous frame is appended
    /// when this is called.
    fn frame(&mut self, time: Time) -> Result<PlatformTexture, String>;
    /// Appends the last frame and closes the file (`ok`), or cancels and removes it.
    fn finish(self: Box<Self>, ok: bool) -> Result<(), String>;
}

/// Opens platform encoders.
pub trait EncoderHost: Send + Sync {
    /// Opens an encoder for `config`.
    fn open(&self, config: &EncoderConfig) -> Result<Box<dyn Encoder>, String>;
}

/// Renders `timeline` frame by frame into an encoder opened from its export settings. A partial
/// last frame is encoded whole. Any failure cancels the file.
pub fn run_export(
    timeline: &Timeline,
    renderer: &mut dyn PreviewRenderer,
    host: &dyn EncoderHost,
    path: &str,
) -> Result<(), String> {
    let settings = timeline.export();
    let (width, height) = settings.frame_size(timeline.aspect());
    let config = EncoderConfig {
        width,
        height,
        fps: settings.fps.per_second(),
        kbps: settings.effective_kbps(timeline.aspect()),
        path: path.to_owned(),
    };
    let rate = settings.fps.rate();
    let frames = frame_count(rate, timeline.duration()).ok_or("timeline too long")?;
    let mut encoder = host.open(&config)?;
    let rendered = (0..frames).try_for_each(|n| {
        let time = rate.frame_to_time(n).ok_or("frame time out of range")?;
        let target = encoder.frame(time)?;
        renderer.draw(target, time)
    });
    match rendered {
        Ok(()) => encoder.finish(true),
        Err(e) => {
            // The render error is the one worth reporting; the cancel's own result is not.
            let _ = encoder.finish(false);
            Err(e)
        }
    }
}

/// Frames needed to cover `duration` at `rate`, counting a partial last frame.
fn frame_count(rate: framix_core::time::Rate, duration: Time) -> Option<i64> {
    let whole = rate.time_to_frame(duration)?;
    let covered = rate.frame_to_time(whole)?;
    Some(if covered < duration { whole + 1 } else { whole })
}

/// An accepted export, for the worker: a snapshot of the timeline and where the file goes.
#[derive(Debug, Clone)]
pub struct ExportJob {
    /// The timeline as it was when the export was accepted.
    pub timeline: Timeline,
    /// Output path.
    pub path: String,
    /// Set to stop the export at its next frame.
    pub cancel: Arc<AtomicBool>,
}

/// Why an export did not finish.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ExportError {
    /// The cancel flag was set.
    #[error("cancelled")]
    Cancelled,
    /// Opening, rendering or encoding failed.
    #[error("{0}")]
    Failed(String),
}

/// [`run_export`] that stops when `cancel` is set and reports `progress(frame, frames)` once
/// per whole percent and for the last frame.
pub fn run_export_with(
    _timeline: &Timeline,
    _renderer: &mut dyn PreviewRenderer,
    _host: &dyn EncoderHost,
    _path: &str,
    _cancel: &AtomicBool,
    _progress: &mut dyn FnMut(u32, u32),
) -> Result<(), ExportError> {
    Err(ExportError::Failed("not implemented yet".into()))
}
