//! Export: renders every frame of a timeline snapshot into buffers the platform encoder owns
//! (docs/adr/0005-export-encoder.md). Runs on the export worker, never the engine thread.

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

/// Renders `timeline` frame by frame into an encoder opened from its export settings.
pub fn run_export(
    _timeline: &Timeline,
    _renderer: &mut dyn PreviewRenderer,
    _host: &dyn EncoderHost,
    _path: &str,
) -> Result<(), String> {
    Err("not implemented yet".into())
}

/// An accepted export, for the worker: a snapshot of the timeline and where the file goes.
#[derive(Debug, Clone)]
pub struct ExportJob {
    /// The timeline as it was when the export was accepted.
    pub timeline: Timeline,
    /// Output path.
    pub path: String,
}
