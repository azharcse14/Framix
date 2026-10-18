//! Ports for the preview: the platform layer owns the texture Flutter shows, the GPU draws into
//! it (docs/adr/0003-platform-callbacks.md). Tests use fakes.

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

/// The GPU side of the preview.
pub trait PreviewRenderer: Send {
    /// Draws the current frame into `target` and returns once the GPU is done with it.
    fn draw(&mut self, target: PlatformTexture) -> Result<(), String>;
}
