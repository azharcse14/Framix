//! GPU rendering with wgpu. SPIKE (P1-001): renders a test pattern straight into memory Flutter
//! shows, with no copies: on iOS an IOSurface-backed Metal texture, on Android the window of a
//! Flutter SurfaceProducer (its buffers are the HardwareBuffers Flutter samples).

use framix_app::preview::{PlatformTexture, PreviewRenderer};

#[cfg(target_os = "android")]
mod android;
use thiserror::Error;

/// Preview texture format: what the platform layer allocates (kCVPixelFormatType_32BGRA).
pub const PREVIEW_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Bgra8Unorm;

/// The RGBA frame blit: fullscreen vertex stage plus src/blit.wgsl.
const BLIT_WGSL: &str = concat!(
    include_str!("../shaders/common/fullscreen.wgsl"),
    include_str!("blit.wgsl"),
);

/// Why the GPU could not be set up.
#[derive(Debug, Error)]
pub enum RenderError {
    /// No usable adapter for this platform's backends (or no GPU at all).
    #[error("no GPU adapter: {0}")]
    NoAdapter(#[from] wgpu::RequestAdapterError),
    /// The adapter refused a device.
    #[error("no GPU device: {0}")]
    NoDevice(#[from] wgpu::RequestDeviceError),
    /// The external texture was null, empty, of a format or usage the call does not take, not
    /// a plain 2D single-mip texture, or from another GPU than the one wgpu opened.
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
    /// A Vulkan call of the Android frame import failed, or the device cannot import frames
    /// (GLES backend, or no AHardwareBuffer extensions).
    #[cfg(target_os = "android")]
    #[error("Android frame import: {0}")]
    Android(String),
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

impl YcbcrSpace {
    /// Every space, in [`YcbcrSpace::index`] order.
    const ALL: [Self; 4] = [
        Self::new(YcbcrMatrix::Bt601, YcbcrRange::Video),
        Self::new(YcbcrMatrix::Bt601, YcbcrRange::Full),
        Self::new(YcbcrMatrix::Bt709, YcbcrRange::Video),
        Self::new(YcbcrMatrix::Bt709, YcbcrRange::Full),
    ];

    const fn new(matrix: YcbcrMatrix, range: YcbcrRange) -> Self {
        Self { matrix, range }
    }

    /// Position in [`YcbcrSpace::ALL`].
    fn index(self) -> usize {
        let matrix = match self.matrix {
            YcbcrMatrix::Bt601 => 0,
            YcbcrMatrix::Bt709 => 2,
        };
        matrix + usize::from(self.range == YcbcrRange::Full)
    }

    /// The `Ycbcr` uniform of shaders/common/ycbcr.wgsl: kr, kb (f32), video_range, pad (u32).
    fn uniform(self) -> [u8; 16] {
        let (kr, kb): (f32, f32) = match self.matrix {
            YcbcrMatrix::Bt601 => (0.299, 0.114),
            YcbcrMatrix::Bt709 => (0.2126, 0.0722),
        };
        let video = u32::from(self.range == YcbcrRange::Video);
        let mut out = [0; 16];
        out[0..4].copy_from_slice(&kr.to_le_bytes());
        out[4..8].copy_from_slice(&kb.to_le_bytes());
        out[8..12].copy_from_slice(&video.to_le_bytes());
        out
    }
}

/// What one Metal wrap accepts and how wgpu sees the result.
#[cfg(target_vendor = "apple")]
struct MetalWrap {
    /// Maps an accepted Metal format to its wgpu format; None rejects it.
    format: fn(objc2_metal::MTLPixelFormat) -> Option<wgpu::TextureFormat>,
    /// Metal usage the texture must have.
    needs: objc2_metal::MTLTextureUsage,
    usage: wgpu::TextureUsages,
    state: wgpu::TextureUses,
    label: &'static str,
}

/// The NV12 -> RGB pass: pipeline, plane sampler, and one read-only uniform per YcbcrSpace,
/// so concurrent draws never share a buffer that is being rewritten.
struct Nv12Pass {
    pipeline: wgpu::RenderPipeline,
    spaces: [wgpu::Buffer; 4],
}

impl Nv12Pass {
    fn new(device: &wgpu::Device) -> Self {
        let source = concat!(
            include_str!("../shaders/common/fullscreen.wgsl"),
            include_str!("../shaders/common/ycbcr.wgsl"),
            include_str!("nv12.wgsl"),
        );
        Self {
            pipeline: fullscreen_pipeline(device, "nv12", source, PREVIEW_FORMAT),
            spaces: YcbcrSpace::ALL.map(|space| {
                use wgpu::util::DeviceExt as _;
                device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("nv12 space"),
                    contents: &space.uniform(),
                    usage: wgpu::BufferUsages::UNIFORM,
                })
            }),
        }
    }
}

/// A GPU device plus its pipelines. One per engine.
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
    /// Linear filtering for decoder frames: scales them and upsamples NV12's half-size chroma.
    frame_sampler: wgpu::Sampler,
    nv12: Nv12Pass,
    blit: wgpu::RenderPipeline,
    /// The device was opened with the AHardwareBuffer import extensions.
    #[cfg(target_os = "android")]
    imports_frames: bool,
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
        let desc = wgpu::DeviceDescriptor {
            required_limits: adapter.limits(),
            ..Default::default()
        };
        #[cfg(target_os = "android")]
        let (device, queue, imports_frames) = android::request_device(&adapter, &desc)?;
        #[cfg(not(target_os = "android"))]
        let (device, queue) = pollster::block_on(adapter.request_device(&desc))?;
        let pipeline = test_pattern_pipeline(&device, PREVIEW_FORMAT);
        let frame_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("decoder frames"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });
        let nv12 = Nv12Pass::new(&device);
        let blit = fullscreen_pipeline(&device, "rgba frame", BLIT_WGSL, PREVIEW_FORMAT);
        Ok(Self {
            instance,
            adapter,
            device,
            queue,
            pipeline,
            frame_sampler,
            nv12,
            blit,
            #[cfg(target_os = "android")]
            imports_frames,
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
        self.draw(target, &self.pipeline, None)
    }

    /// Draws an RGBA8 frame (a decoder frame already converted to RGB, e.g. the Android GLES
    /// pass's HardwareBuffer) into `target` and waits until the GPU is done.
    pub fn draw_rgba(
        &self,
        target: &wgpu::Texture,
        frame: &wgpu::Texture,
    ) -> Result<(), RenderError> {
        if target.format() != PREVIEW_FORMAT || frame.format() != wgpu::TextureFormat::Rgba8Unorm {
            return Err(RenderError::InvalidTexture);
        }
        let bind_group = self.rgba_bind_group(&self.blit, frame);
        self.draw(target, &self.blit, Some(&bind_group))
    }

    /// The blit pass's bindings for `frame`.
    fn rgba_bind_group(
        &self,
        pipeline: &wgpu::RenderPipeline,
        frame: &wgpu::Texture,
    ) -> wgpu::BindGroup {
        // SPIKE: a bind group per frame; the render thread (P1-053) will pool them.
        self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("rgba frame"),
            layout: &pipeline.get_bind_group_layout(0),
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(
                        &frame.create_view(&Default::default()),
                    ),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::Sampler(&self.frame_sampler),
                },
            ],
        })
    }

    /// Imports an RGBA8 AHardwareBuffer (a decoder frame the platform layer converted) as a
    /// texture for [`Gpu::draw_to_android_window`], without copying.
    ///
    /// # Safety
    /// `ahb` must be a live `AHardwareBuffer*` for the call, the GPU work that wrote it must be
    /// done, and nothing may write it while the returned texture is used. No other thread may
    /// use this `Gpu`'s queue (draw, present) during the call.
    #[cfg(target_os = "android")]
    pub unsafe fn import_android_frame(
        &self,
        ahb: std::ptr::NonNull<std::ffi::c_void>,
    ) -> Result<wgpu::Texture, RenderError> {
        if !self.imports_frames {
            return Err(RenderError::Android(
                "device has no AHardwareBuffer import".to_owned(),
            ));
        }
        // SAFETY: forwarded from this function's contract; the device was opened with the
        // import extensions (checked above).
        unsafe { android::import_ahb(&self.device, ahb) }
    }

    /// Converts an NV12 frame (`y` R8Unorm, `cbcr` RG8Unorm at half size) to RGB into `target`
    /// and waits until the GPU is done.
    pub fn draw_nv12(
        &self,
        target: &wgpu::Texture,
        y: &wgpu::Texture,
        cbcr: &wgpu::Texture,
        space: YcbcrSpace,
    ) -> Result<(), RenderError> {
        if target.format() != PREVIEW_FORMAT
            || y.format() != wgpu::TextureFormat::R8Unorm
            || cbcr.format() != wgpu::TextureFormat::Rg8Unorm
        {
            return Err(RenderError::InvalidTexture);
        }
        let pass = &self.nv12;
        // SPIKE: a bind group per frame; the render thread (P1-053) will pool them.
        let bind_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("nv12 frame"),
            layout: &pass.pipeline.get_bind_group_layout(0),
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(
                        &y.create_view(&Default::default()),
                    ),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::TextureView(
                        &cbcr.create_view(&Default::default()),
                    ),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: wgpu::BindingResource::Sampler(&self.frame_sampler),
                },
                wgpu::BindGroupEntry {
                    binding: 3,
                    resource: pass.spaces[space.index()].as_entire_binding(),
                },
            ],
        });
        self.draw(target, &pass.pipeline, Some(&bind_group))
    }

    fn draw(
        &self,
        target: &wgpu::Texture,
        pipeline: &wgpu::RenderPipeline,
        bind_group: Option<&wgpu::BindGroup>,
    ) -> Result<(), RenderError> {
        let view = target.create_view(&Default::default());
        let mut encoder = self.device.create_command_encoder(&Default::default());
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("fullscreen"),
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
            pass.set_bind_group(0, bind_group, &[]);
            pass.draw(0..3, 0..1);
        }
        self.queue.submit([encoder.finish()]);
        // SPIKE: blocking wait; the real render thread will signal via a fence instead.
        self.device.poll(wgpu::PollType::wait_indefinitely())?;
        Ok(())
    }

    /// Draws one frame into an Android window and presents it: `source` (an imported decoder
    /// frame) or, without one, the test pattern. The window's buffers are what Flutter's
    /// SurfaceProducer samples, so nothing is copied.
    ///
    /// # Safety
    /// `window` must be a live `ANativeWindow*` that outlives this call.
    #[cfg(target_os = "android")]
    pub unsafe fn draw_to_android_window(
        &self,
        window: std::ptr::NonNull<std::ffi::c_void>,
        source: Option<&wgpu::Texture>,
    ) -> Result<(), RenderError> {
        // SAFETY: the caller guarantees a live window for the whole call.
        let (width, height) = unsafe { android::window_size(window) }?;
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
        let linear = config.format.remove_srgb_suffix();
        if caps.formats.contains(&linear) {
            config.format = linear;
        }
        surface.configure(&self.device, &config);
        let frame = match surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(frame)
            | wgpu::CurrentSurfaceTexture::Suboptimal(frame) => frame,
            _ => return Err(RenderError::SurfaceUnusable),
        };
        // SPIKE: one frame, so the pipeline is built per call.
        match source {
            Some(source) => {
                let pipeline =
                    fullscreen_pipeline(&self.device, "rgba frame", BLIT_WGSL, config.format);
                let bind_group = self.rgba_bind_group(&pipeline, source);
                self.draw(&frame.texture, &pipeline, Some(&bind_group))?;
            }
            None => self.draw(
                &frame.texture,
                &test_pattern_pipeline(&self.device, config.format),
                None,
            )?,
        }
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
        use objc2_metal::{MTLPixelFormat, MTLTextureUsage};
        let wrap = MetalWrap {
            format: |f| (f == MTLPixelFormat::BGRA8Unorm).then_some(PREVIEW_FORMAT),
            needs: MTLTextureUsage::RenderTarget,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            // The first pass clears it.
            state: wgpu::TextureUses::UNINITIALIZED,
            label: "flutter preview",
        };
        // SAFETY: forwarded from this function's contract.
        unsafe { self.wrap_metal(mtl_texture, wrap) }
    }

    /// Wraps one plane of a decoder frame (a Metal texture on an IOSurface plane: R8Unorm luma
    /// or RG8Unorm chroma) for sampling, without copying.
    ///
    /// # Safety
    /// `mtl_texture` must be null or a live `id<MTLTexture>`. It is retained here, so the caller
    /// may release its own reference. The decoder must have finished writing the frame, and the
    /// frame (its CVPixelBuffer) must stay alive and unwritten for as long as the returned
    /// texture is used: the decoder's pool recycles the IOSurface once the buffer is released.
    #[cfg(target_vendor = "apple")]
    pub unsafe fn wrap_metal_plane(
        &self,
        mtl_texture: *mut std::ffi::c_void,
    ) -> Result<wgpu::Texture, RenderError> {
        use objc2_metal::{MTLPixelFormat, MTLTextureUsage};
        let wrap = MetalWrap {
            format: |f| match f {
                MTLPixelFormat::R8Unorm => Some(wgpu::TextureFormat::R8Unorm),
                MTLPixelFormat::RG8Unorm => Some(wgpu::TextureFormat::Rg8Unorm),
                _ => None,
            },
            needs: MTLTextureUsage::ShaderRead,
            usage: wgpu::TextureUsages::TEXTURE_BINDING,
            // The decoder already wrote the pixels.
            state: wgpu::TextureUses::RESOURCE,
            label: "decoder plane",
        };
        // SAFETY: forwarded from this function's contract.
        unsafe { self.wrap_metal(mtl_texture, wrap) }
    }

    /// The checks and hal import shared by the Metal wraps.
    ///
    /// # Safety
    /// `mtl_texture` must be null or a live `id<MTLTexture>`.
    #[cfg(target_vendor = "apple")]
    unsafe fn wrap_metal(
        &self,
        mtl_texture: *mut std::ffi::c_void,
        wrap: MetalWrap,
    ) -> Result<wgpu::Texture, RenderError> {
        use objc2::rc::Retained;
        use objc2::runtime::ProtocolObject;
        use objc2_metal::{MTLResource, MTLTexture, MTLTextureType};
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
        let format = (wrap.format)(raw.pixelFormat()).ok_or(RenderError::InvalidTexture)?;
        if width == 0
            || height == 0
            || raw.textureType() != MTLTextureType::Type2D
            || raw.mipmapLevelCount() != 1
            || !raw.usage().contains(wrap.needs)
            || !same_device
        {
            return Err(RenderError::InvalidTexture);
        }
        let size = wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        };
        // SAFETY: format, size, type, mip count and usage were checked above.
        let hal = unsafe {
            Device::texture_from_raw(
                raw,
                format,
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
        // SAFETY: `hal` is on wgpu's own device (checked above) and the descriptor matches it.
        Ok(unsafe {
            self.device.create_texture_from_hal::<Metal>(
                hal,
                &wgpu::TextureDescriptor {
                    label: Some(wrap.label),
                    size,
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format,
                    usage: wrap.usage,
                    view_formats: &[],
                },
                wrap.state,
            )
        })
    }
}

/// The fullscreen test-pattern pipeline for render targets of `format`.
fn test_pattern_pipeline(
    device: &wgpu::Device,
    format: wgpu::TextureFormat,
) -> wgpu::RenderPipeline {
    let source = concat!(
        include_str!("../shaders/common/fullscreen.wgsl"),
        include_str!("test_pattern.wgsl"),
    );
    fullscreen_pipeline(device, "test pattern", source, format)
}

/// A pipeline drawing one fullscreen triangle (`vs` from shaders/common/fullscreen.wgsl) with
/// fragment entry `fs` from `source`, into render targets of `format`.
fn fullscreen_pipeline(
    device: &wgpu::Device,
    label: &str,
    source: &str,
    format: wgpu::TextureFormat,
) -> wgpu::RenderPipeline {
    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some(label),
        source: wgpu::ShaderSource::Wgsl(source.into()),
    });
    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some(label),
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

/// [`PreviewRenderer`] on [`Gpu`]: draws the test pattern into the platform's texture. Opens
/// the GPU on first use.
pub struct GpuRenderer {
    gpu: Option<Gpu>,
}

impl GpuRenderer {
    /// A renderer that has not opened the GPU yet.
    ///
    /// # Safety
    /// `draw` must only get textures whose `handle` came from a successful
    /// `EnginePreviewTextureDone` (a live `id<MTLTexture>` on Apple, an owned `ANativeWindow*` on
    /// Android) and stays alive for the call.
    pub unsafe fn new() -> Self {
        Self { gpu: None }
    }
}

impl PreviewRenderer for GpuRenderer {
    fn draw(&mut self, target: PlatformTexture) -> Result<(), String> {
        let gpu = match &mut self.gpu {
            Some(gpu) => gpu,
            empty => empty.insert(Gpu::new().map_err(|e| e.to_string())?),
        };
        draw_into(gpu, target)
    }
}

#[cfg(target_vendor = "apple")]
fn draw_into(gpu: &Gpu, target: PlatformTexture) -> Result<(), String> {
    // SAFETY: GpuRenderer::new's contract: the handle is a live id<MTLTexture> the platform
    // reported as made.
    let texture = unsafe { gpu.wrap_metal_texture(target.handle as *mut std::ffi::c_void) }
        .map_err(|e| e.to_string())?;
    gpu.draw_test_pattern(&texture).map_err(|e| e.to_string())
}

#[cfg(target_os = "android")]
fn draw_into(gpu: &Gpu, target: PlatformTexture) -> Result<(), String> {
    let window = std::ptr::NonNull::new(target.handle as *mut std::ffi::c_void)
        .ok_or("null preview window")?;
    // SAFETY: GpuRenderer::new's contract: the handle is a live ANativeWindow* the platform
    // reported as made; wgpu's surface is dropped inside the call.
    unsafe { gpu.draw_to_android_window(window, None) }.map_err(|e| e.to_string())
}

#[cfg(not(any(target_vendor = "apple", target_os = "android")))]
fn draw_into(_: &Gpu, _: PlatformTexture) -> Result<(), String> {
    Err("no platform texture support on this OS yet".to_owned())
}

#[cfg(test)]
mod tests {
    use super::YcbcrSpace;

    #[test]
    fn every_space_indexes_its_own_uniform() {
        for (i, space) in YcbcrSpace::ALL.into_iter().enumerate() {
            assert_eq!(space.index(), i, "{space:?}");
        }
    }
}
