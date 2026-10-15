//! GPU rendering with wgpu. SPIKE (P1-001): renders a test pattern straight into a texture the
//! platform layer owns (an IOSurface-backed Metal texture that Flutter shows), with no copies.

use thiserror::Error;

/// Preview texture format: what the platform layer allocates (kCVPixelFormatType_32BGRA).
pub const PREVIEW_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Bgra8Unorm;

/// Why the GPU could not be set up.
#[derive(Debug, Error)]
pub enum RenderError {
    /// No Metal adapter (or no GPU at all).
    #[error("no GPU adapter: {0}")]
    NoAdapter(#[from] wgpu::RequestAdapterError),
    /// The adapter refused a device.
    #[error("no GPU device: {0}")]
    NoDevice(#[from] wgpu::RequestDeviceError),
    /// The external texture handle was null or the size was zero.
    #[error("invalid external texture")]
    InvalidTexture,
}

/// A GPU device plus the test-pattern pipeline. One per engine.
pub struct Gpu {
    device: wgpu::Device,
    queue: wgpu::Queue,
    pipeline: wgpu::RenderPipeline,
}

impl Gpu {
    /// Opens the default Metal device.
    pub fn new() -> Result<Self, RenderError> {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::METAL,
            ..wgpu::InstanceDescriptor::new_without_display_handle()
        });
        let adapter =
            pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions::default()))?;
        let (device, queue) =
            pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default()))?;
        let shader = device.create_shader_module(wgpu::include_wgsl!("test_pattern.wgsl"));
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("test pattern"),
            layout: None,
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs"),
                compilation_options: Default::default(),
                targets: &[Some(PREVIEW_FORMAT.into())],
            }),
            primitive: Default::default(),
            depth_stencil: None,
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        Ok(Self {
            device,
            queue,
            pipeline,
        })
    }

    /// The device, for creating textures (tests, offscreen targets).
    pub fn device(&self) -> &wgpu::Device {
        &self.device
    }

    /// The queue, for readbacks in tests.
    pub fn queue(&self) -> &wgpu::Queue {
        &self.queue
    }

    /// Draws the test pattern into `target` and waits until the GPU is done, so the platform
    /// layer can tell Flutter a new frame is ready right after this returns.
    pub fn draw_test_pattern(&self, target: &wgpu::Texture) {
        let view = target.create_view(&Default::default());
        let mut encoder = self.device.create_command_encoder(&Default::default());
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("test pattern"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                ..Default::default()
            });
            pass.set_pipeline(&self.pipeline);
            pass.draw(0..3, 0..1);
        }
        self.queue.submit([encoder.finish()]);
        // SPIKE: blocking wait; the real render thread will signal via a fence instead.
        let _ = self.device.poll(wgpu::PollType::wait_indefinitely());
    }

    /// Wraps a Metal texture owned by the platform layer as a render target, without copying.
    ///
    /// # Safety
    /// `mtl_texture` must be a live `id<MTLTexture>` created on the system default device, with
    /// format BGRA8Unorm, size `width` x `height`, usage including render target. It is retained
    /// here, so the caller may release its own reference.
    #[cfg(target_vendor = "apple")]
    pub unsafe fn wrap_metal_texture(
        &self,
        mtl_texture: *mut std::ffi::c_void,
        width: u32,
        height: u32,
    ) -> Result<wgpu::Texture, RenderError> {
        use objc2::rc::Retained;
        use objc2::runtime::ProtocolObject;
        use objc2_metal::{MTLTexture, MTLTextureType};
        use wgpu::hal::{CopyExtent, api::Metal, metal::Device};

        if width == 0 || height == 0 {
            return Err(RenderError::InvalidTexture);
        }
        // SAFETY: the caller guarantees a live id<MTLTexture>; retain() adds our own reference
        // and returns None for null.
        let raw = unsafe { Retained::retain(mtl_texture.cast::<ProtocolObject<dyn MTLTexture>>()) }
            .ok_or(RenderError::InvalidTexture)?;
        let size = wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        };
        // SAFETY: format, type, layers, mips and size describe `raw` as the caller guarantees.
        let hal = unsafe {
            Device::texture_from_raw(
                raw,
                PREVIEW_FORMAT,
                MTLTextureType::Type2D,
                1,
                1,
                CopyExtent {
                    width,
                    height,
                    depth: 1,
                },
                None,
            )
        };
        // SAFETY: `hal` is a texture from the same system default device wgpu opened, and the
        // descriptor below matches it; UNINITIALIZED makes the first pass clear it.
        Ok(unsafe {
            self.device.create_texture_from_hal::<Metal>(
                hal,
                &wgpu::TextureDescriptor {
                    label: Some("flutter preview"),
                    size,
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format: PREVIEW_FORMAT,
                    usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
                    view_formats: &[],
                },
                wgpu::TextureUses::UNINITIALIZED,
            )
        })
    }
}
