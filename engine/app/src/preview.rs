//! Ports for the preview: the platform layer owns the texture Flutter shows, the GPU draws into
//! it (docs/adr/0003-platform-callbacks.md). Tests use fakes.

use framix_core::media::Media;
use framix_core::time::Time;
use framix_core::timeline::Layer;

/// A texture the platform layer made for the preview.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlatformTexture {
    /// Flutter's texture id; the only part Dart sees.
    pub id: i64,
    /// Opaque GPU handle for the renderer (an `id<MTLTexture>` on iOS), never dereferenced here.
    pub handle: usize,
}

/// The platform layer (Swift/Kotlin) side of the preview. Calls must return at once.
pub trait PreviewHost: Send {
    /// Asks for a texture; the platform answers later through
    /// [`crate::engine::Engine::preview_texture_ready`]. An error means nothing was requested.
    fn create_texture(&self, width: u32, height: u32) -> Result<(), String>;
    /// Tells Flutter that texture `id` holds a new frame.
    fn frame_available(&self, id: i64);
}

/// Why a draw failed.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum DrawError {
    /// The GPU or the target is gone; later draws will fail too.
    #[error("{0}")]
    Gpu(String),
    /// The layer's frame could not be decoded (e.g. a missing file); the target shows black.
    #[error("{0}")]
    Decode(String),
}

/// The GPU side of the preview (and of export: one render path).
pub trait PreviewRenderer: Send {
    /// Draws `layer`, the picture at `time` (none: an empty canvas), into `target` and returns
    /// once the GPU is done with it.
    fn draw(
        &mut self,
        target: PlatformTexture,
        time: Time,
        layer: Option<&Layer>,
    ) -> Result<(), DrawError>;
}

/// The YCbCr -> RGB matrix a decoder frame was encoded with.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum YcbcrMatrix {
    /// ITU-R BT.601 (SD video, JPEG).
    Bt601,
    /// ITU-R BT.709 (HD video).
    Bt709,
}

/// Whether Y and CbCr use the video (16-235/240) or the full (0-255) code range.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum YcbcrRange {
    /// Y 16-235, CbCr 16-240 (8-bit codes).
    Video,
    /// 0-255.
    Full,
}

/// How to turn a frame's YCbCr samples into RGB.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct YcbcrSpace {
    /// Conversion matrix.
    pub matrix: YcbcrMatrix,
    /// Code range.
    pub range: YcbcrRange,
}

/// A decoded picture as GPU handles the renderer imports; never dereferenced here.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Frame {
    /// Video: luma and interleaved chroma planes (`id<MTLTexture>` R8 and RG8 on iOS).
    Nv12 {
        /// Luma plane.
        y: usize,
        /// Chroma plane, half size.
        cbcr: usize,
        /// Colour space of the samples.
        space: YcbcrSpace,
    },
    /// A photo: one RGBA8 texture.
    Rgba {
        /// The texture.
        texture: usize,
    },
}

/// Decodes media into GPU frames (docs/adr/0006-decoder-port.md). Calls block until the frame
/// is ready; one decoder per thread.
pub trait Decoder: Send {
    /// The frame of `media` at `source_time` (photos ignore it). Its handles stay valid until
    /// the next call or until the decoder is dropped.
    fn frame(&mut self, media: &Media, source_time: Time) -> Result<Frame, String>;
}
