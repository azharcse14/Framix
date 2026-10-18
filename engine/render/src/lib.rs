//! GPU rendering with wgpu. SPIKE (P1-001): renders a test pattern straight into memory Flutter
//! shows, with no copies: on iOS an IOSurface-backed Metal texture, on Android the window of a
//! Flutter SurfaceProducer (its buffers are the HardwareBuffers Flutter samples).

use thiserror::Error;

/// Preview texture format: what the platform layer allocates (kCVPixelFormatType_32BGRA).
pub const PREVIEW_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Bgra8Unorm;

/// Why the GPU could not be set up.
#[derive(Debug, Error)]
pub enum RenderError {
    /// No usable adapter for this platform's backends (or no GPU at all).
    #[error("no GPU adapter: {0}")]
    NoAdapter(#[from] wgpu::RequestAdapterError),
    /// The adapter refused a device.
    #[error("no GPU device: {0}")]
    NoDevice(#[from] wgpu::RequestDeviceError),
    /// The external texture was null, empty, not BGRA8Unorm, not a render target, or from
    /// another GPU than the one wgpu opened.
    #[error("invalid external texture")]
    InvalidTexture,
    /// Waiting for the GPU failed (timeout or device lost).
    #[error("GPU wait failed: {0}")]
    Wait(#[from] wgpu::PollError),
    /// The platform window could not become a wgpu surface.
    #[error("no surface: {0}")]
    Surface(#[from] wgpu::CreateSurfaceError),
    /// The surface is not usable by this adapter, or gave no frame to draw into.
    #[error("surface unusable")]
    SurfaceUnusable,
}

/// A GPU device plus the test-pattern pipeline. One per engine.
pub struct Gpu {
    // Only the Android path makes surfaces; iOS renders into textures it is handed.
    #[cfg_attr(
        not(target_os = "android"),
        expect(dead_code, reason = "Android surfaces only")
    )]
    instance: wgpu::Instance,
    #[cfg_attr(
        not(target_os = "android"),
        expect(dead_code, reason = "Android surfaces only")
    )]
    adapter: wgpu::Adapter,
    device: wgpu::Device,
    queue: wgpu::Queue,
    pipeline: wgpu::RenderPipeline,
}

impl Gpu {
    /// Opens the default GPU: Metal on Apple platforms, Vulkan (GLES fallback) on Android.
    pub fn new() -> Result<Self, RenderError> {
        let backends = if cfg!(target_os = "android") {
            wgpu::Backends::VULKAN | wgpu::Backends::GL
        } else {
            wgpu::Backends::METAL
        };
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends,
            ..wgpu::InstanceDescriptor::new_without_display_handle()
        });
        let adapter =
            pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions::default()))?;
        // Ask only for what this adapter has: the iOS simulator's Metal device is below
        // wgpu's default limits.
        let (device, queue) =
            pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
                required_limits: adapter.limits(),
                ..Default::default()
            }))?;
        let pipeline = test_pattern_pipeline(&device, PREVIEW_FORMAT);
        Ok(Self {
            instance,
            adapter,
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
    pub fn draw_test_pattern(&self, target: &wgpu::Texture) -> Result<(), RenderError> {
        self.draw(target, &self.pipeline)
    }

    fn draw(
        &self,
        target: &wgpu::Texture,
        pipeline: &wgpu::RenderPipeline,
    ) -> Result<(), RenderError> {
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
            pass.set_pipeline(pipeline);
            pass.draw(0..3, 0..1);
        }
        self.queue.submit([encoder.finish()]);
        // SPIKE: blocking wait; the real render thread will signal via a fence instead.
        self.device.poll(wgpu::PollType::wait_indefinitely())?;
        Ok(())
    }

    /// Draws one test-pattern frame into an Android window and presents it. The window's
    /// buffers are what Flutter's SurfaceProducer samples, so nothing is copied.
    ///
    /// # Safety
    /// `window` must be a live `ANativeWindow*` that outlives this call.
    #[cfg(target_os = "android")]
    pub unsafe fn draw_to_android_window(
        &self,
        window: std::ptr::NonNull<std::ffi::c_void>,
        width: u32,
        height: u32,
    ) -> Result<(), RenderError> {
        use wgpu::rwh::{
            AndroidDisplayHandle, AndroidNdkWindowHandle, RawDisplayHandle, RawWindowHandle,
        };
        // SAFETY: the caller guarantees a live window for the whole call, and the surface is
        // dropped before returning.
        let surface = unsafe {
            self.instance
                .create_surface_unsafe(wgpu::SurfaceTargetUnsafe::RawHandle {
                    raw_display_handle: Some(
                        RawDisplayHandle::Android(AndroidDisplayHandle::new()),
                    ),
                    raw_window_handle: RawWindowHandle::AndroidNdk(AndroidNdkWindowHandle::new(
                        window,
                    )),
                })
        }?;
        let mut config = surface
            .get_default_config(&self.adapter, width, height)
            .ok_or(RenderError::SurfaceUnusable)?;
        // Same look as iOS: write the shader output as is, no sRGB encode.
        let caps = surface.get_capabilities(&self.adapter);
        if let Some(linear) = caps.formats.iter().find(|f| !f.is_srgb()) {
            config.format = *linear;
        }
        surface.configure(&self.device, &config);
        let frame = match surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(frame)
            | wgpu::CurrentSurfaceTexture::Suboptimal(frame) => frame,
            _ => return Err(RenderError::SurfaceUnusable),
        };
        // SPIKE: one frame, so the pipeline is built per call.
        self.draw(
            &frame.texture,
            &test_pattern_pipeline(&self.device, config.format),
        )?;
        self.queue.present(frame);
        Ok(())
    }

    /// Wraps a Metal texture owned by the platform layer as a render target, without copying.
    /// Size, format, usage and device are read from the texture and checked.
    ///
    /// # Safety
    /// `mtl_texture` must be null or a live `id<MTLTexture>`. It is retained here, so the caller
    /// may release its own reference.
    #[cfg(target_vendor = "apple")]
    pub unsafe fn wrap_metal_texture(
        &self,
        mtl_texture: *mut std::ffi::c_void,
    ) -> Result<wgpu::Texture, RenderError> {
        use objc2::rc::Retained;
        use objc2::runtime::ProtocolObject;
        use objc2_metal::{
            MTLPixelFormat, MTLResource, MTLTexture, MTLTextureType, MTLTextureUsage,
        };
        use wgpu::hal::{CopyExtent, api::Metal, metal::Device};

        // SAFETY: the caller guarantees null or a live id<MTLTexture>; retain() adds our own
        // reference and returns None for null.
        let raw = unsafe { Retained::retain(mtl_texture.cast::<ProtocolObject<dyn MTLTexture>>()) }
            .ok_or(RenderError::InvalidTexture)?;
        let (width, height) = (
            u32::try_from(raw.width()).map_err(|_| RenderError::InvalidTexture)?,
            u32::try_from(raw.height()).map_err(|_| RenderError::InvalidTexture)?,
        );
        // SAFETY: as_hal only borrows wgpu's Metal device to read its raw handle.
        let same_device = unsafe { self.device.as_hal::<Metal>() }.is_some_and(|hal| {
            std::ptr::eq(
                Retained::as_ptr(&raw.device()),
                Retained::as_ptr(hal.raw_device()),
            )
        });
        if width == 0
            || height == 0
            || raw.pixelFormat() != MTLPixelFormat::BGRA8Unorm
            || !raw.usage().contains(MTLTextureUsage::RenderTarget)
            || !same_device
        {
            return Err(RenderError::InvalidTexture);
        }
        let size = wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        };
        // SAFETY: format, size and usage were checked above; the platform layer creates plain 2D
        // single-mip textures (SpikePreview.swift).
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
        // SAFETY: `hal` is on wgpu's own device (checked above) and the descriptor matches it;
        // UNINITIALIZED makes the first pass clear it.
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

/// The fullscreen test-pattern pipeline for render targets of `format`.
fn test_pattern_pipeline(
    device: &wgpu::Device,
    format: wgpu::TextureFormat,
) -> wgpu::RenderPipeline {
    let shader = device.create_shader_module(wgpu::include_wgsl!("test_pattern.wgsl"));
    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
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
            targets: &[Some(format.into())],
        }),
        primitive: Default::default(),
        depth_stencil: None,
        multisample: Default::default(),
        multiview_mask: None,
        cache: None,
    })
}
