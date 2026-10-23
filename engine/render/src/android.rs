//! SPIKE (P1-056): Android decoder frames reach wgpu with no CPU copy. The platform layer
//! converts a MediaCodec frame to an RGBA8 AHardwareBuffer with one GLES pass (wgpu's Vulkan
//! backend cannot sample opaque YCbCr); this module imports that buffer as a Vulkan image.
//! Single-threaded and blocking: the render thread (P1-053) replaces the queue waits.

use std::ffi::{CStr, c_void};
use std::ptr::NonNull;

use ash::vk;
use wgpu::hal::api::Vulkan;
use wgpu::hal::vulkan;

use crate::RenderError;

#[link(name = "log")]
unsafe extern "C" {
    fn __android_log_write(
        priority: i32,
        tag: *const std::ffi::c_char,
        text: *const std::ffi::c_char,
    ) -> i32;
}

/// SPIKE (P1-004): writes `text` to logcat under the "framix" tag (stderr goes nowhere on
/// Android). Never pass paths or user data.
pub fn log(text: &str) {
    const INFO: i32 = 4;
    let Ok(text) = std::ffi::CString::new(text) else {
        return;
    };
    // SAFETY: both strings are NUL-terminated and live for the call.
    unsafe { __android_log_write(INFO, c"framix".as_ptr(), text.as_ptr()) };
}

/// Device extensions the import needs, enabled when the adapter has them all.
const AHB_EXTENSIONS: [&CStr; 2] = [
    ash::android::external_memory_android_hardware_buffer::NAME,
    ash::ext::queue_family_foreign::NAME,
];

/// Opens the device. On Vulkan with the AHB extensions it goes through wgpu-hal to enable them
/// (returns `true` with the device); otherwise it is a plain request, which can import frames
/// only on the GLES backend.
pub(crate) fn request_device(
    adapter: &wgpu::Adapter,
    desc: &wgpu::DeviceDescriptor<'_>,
) -> Result<(wgpu::Device, wgpu::Queue, bool), RenderError> {
    // SAFETY: as_hal only borrows wgpu's adapter; it is dropped before the device is made.
    let opened = unsafe { adapter.as_hal::<Vulkan>() }
        .filter(|hal| {
            let caps = hal.physical_device_capabilities();
            // The AHB extension builds on 1.1 core (external memory, dedicated allocation,
            // sampler YCbCr), which wgpu-hal does not enable as extensions on a 1.0 device.
            caps.properties().api_version >= vk::API_VERSION_1_1
                && AHB_EXTENSIONS.iter().all(|e| caps.supports_extension(e))
        })
        .map(|hal| {
            // SAFETY: the callback only adds extensions the adapter reports as supported.
            unsafe {
                hal.open_with_callback(
                    desc.required_features,
                    &desc.required_limits,
                    &desc.memory_hints,
                    Some(Box::new(|args| args.extensions.extend(AHB_EXTENSIONS))),
                )
            }
        });
    match opened {
        Some(open) => {
            let open = open.map_err(|e| RenderError::Android(e.to_string()))?;
            // SAFETY: `open` was made from this adapter's hal adapter with `desc`'s features.
            let (device, queue) = unsafe { adapter.create_device_from_hal(open, desc) }?;
            Ok((device, queue, true))
        }
        None => {
            let (device, queue) = pollster::block_on(adapter.request_device(desc))?;
            // The GLES fallback imports through an EGLImage instead (P1-004).
            let gles = adapter.get_info().backend == wgpu::Backend::Gl;
            Ok((device, queue, gles))
        }
    }
}

/// `AHardwareBuffer_Desc` from the NDK (android/hardware_buffer.h).
#[repr(C)]
#[derive(Default)]
struct AHardwareBufferDesc {
    width: u32,
    height: u32,
    layers: u32,
    format: u32,
    usage: u64,
    stride: u32,
    rfu0: u32,
    rfu1: u64,
}

/// AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE: required to create a SAMPLED Vulkan image on it.
const AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE: u64 = 1 << 8;

#[link(name = "android")]
unsafe extern "C" {
    fn AHardwareBuffer_describe(buffer: *const c_void, desc: *mut AHardwareBufferDesc);
    fn ANativeWindow_getWidth(window: *mut c_void) -> i32;
    fn ANativeWindow_acquire(window: *mut c_void);
    fn ANativeWindow_release(window: *mut c_void);
    fn ANativeWindow_getHeight(window: *mut c_void) -> i32;
}

/// The window's size, or `SurfaceUnusable` if it has none.
///
/// # Safety
/// `window` must be a live `ANativeWindow*` for the call.
/// An owned reference to an ANativeWindow, released on drop.
pub(crate) struct WindowRef(NonNull<c_void>);

impl WindowRef {
    /// Takes a reference of its own to `window`.
    ///
    /// # Safety
    /// `window` must be a live `ANativeWindow*` for the call.
    pub(crate) unsafe fn acquire(window: NonNull<c_void>) -> Self {
        // SAFETY: live per the contract; balanced by the release in Drop.
        unsafe { ANativeWindow_acquire(window.as_ptr()) };
        Self(window)
    }

    pub(crate) fn as_ptr(&self) -> *mut c_void {
        self.0.as_ptr()
    }
}

impl Drop for WindowRef {
    fn drop(&mut self) {
        // SAFETY: this struct holds one reference, taken in acquire.
        unsafe { ANativeWindow_release(self.0.as_ptr()) };
    }
}

// SAFETY: ANativeWindow reference counting is thread-safe; the pointer is only compared and
// released.
unsafe impl Send for WindowRef {}

pub(crate) unsafe fn window_size(window: NonNull<c_void>) -> Result<(u32, u32), RenderError> {
    // SAFETY: `window` is live per the contract.
    let (width, height) = unsafe {
        (
            ANativeWindow_getWidth(window.as_ptr()),
            ANativeWindow_getHeight(window.as_ptr()),
        )
    };
    match (u32::try_from(width), u32::try_from(height)) {
        (Ok(w), Ok(h)) if w > 0 && h > 0 => Ok((w, h)),
        _ => Err(RenderError::SurfaceUnusable),
    }
}

/// Imports an RGBA8 AHardwareBuffer as a sampled wgpu texture, without copying.
///
/// # Safety
/// `ahb` must be a live `AHardwareBuffer*` for the call, the GPU work that wrote it must be done,
/// and nothing may write it while the returned texture is used. `device` must have been opened by
/// [`request_device`] with the AHB extensions, or be on the GLES backend. No other thread may
/// use wgpu's queue (submit or present) during the call: on Vulkan it submits on the raw
/// VkQueue behind wgpu.
pub(crate) unsafe fn import_ahb(
    device: &wgpu::Device,
    ahb: NonNull<c_void>,
) -> Result<wgpu::Texture, RenderError> {
    let mut desc = AHardwareBufferDesc::default();
    // SAFETY: `ahb` is live per the contract; `desc` is a valid out pointer.
    unsafe { AHardwareBuffer_describe(ahb.as_ptr(), &mut desc) };
    let max_side = device.limits().max_texture_dimension_2d;
    if !(1..=max_side).contains(&desc.width)
        || !(1..=max_side).contains(&desc.height)
        || desc.layers != 1
        || desc.usage & AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE == 0
    {
        return Err(RenderError::InvalidTexture);
    }
    // SAFETY: as_hal only borrows wgpu's device for the raw handles.
    let Some(hal) = (unsafe { device.as_hal::<Vulkan>() }) else {
        // SAFETY: forwarded from this function's contract; not Vulkan means the GLES fallback
        // (request_device enables imports only for those two).
        return unsafe { crate::android_gles::import_ahb(device, ahb, desc.width, desc.height) };
    };
    // SAFETY: the extension was enabled by request_device (contract), so its functions load.
    let (raw, image, memory) = unsafe { import_image(&hal, ahb, desc.width, desc.height) }?;
    let size = wgpu::Extent3d {
        width: desc.width,
        height: desc.height,
        depth_or_array_layers: 1,
    };
    let free: wgpu::hal::DropCallback = Box::new(move || {
        // SAFETY: wgpu calls this once, when it is done with the image.
        unsafe {
            raw.destroy_image(image, None);
            raw.free_memory(memory, None);
        }
    });
    let texture = {
        let hal_desc = wgpu::hal::TextureDescriptor {
            label: Some("decoder frame"),
            size,
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Rgba8Unorm,
            usage: wgpu::TextureUses::RESOURCE,
            memory_flags: wgpu::hal::MemoryFlags::empty(),
            view_formats: Vec::new(),
        };
        // SAFETY: `image` was created to match `hal_desc` and its memory stays valid until the
        // drop callback frees both.
        unsafe {
            hal.texture_from_raw(
                image,
                &hal_desc,
                Some(free),
                vulkan::TextureMemory::External,
            )
        }
    };
    drop(hal);
    // SAFETY: the hal texture is on this device, its descriptor matches, and import_image left it
    // in SHADER_READ_ONLY_OPTIMAL, which RESOURCE means.
    Ok(unsafe {
        device.create_texture_from_hal::<Vulkan>(
            texture,
            &wgpu::TextureDescriptor {
                label: Some("decoder frame"),
                size,
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::Rgba8Unorm,
                usage: wgpu::TextureUsages::TEXTURE_BINDING,
                view_formats: &[],
            },
            wgpu::TextureUses::RESOURCE,
        )
    })
}

/// Creates a VkImage on the AHB's memory and moves it from the foreign queue family into
/// SHADER_READ_ONLY_OPTIMAL. Returns the device, image and memory, owned by the caller.
///
/// # Safety
/// As [`import_ahb`].
unsafe fn import_image(
    hal: &vulkan::Device,
    ahb: NonNull<c_void>,
    width: u32,
    height: u32,
) -> Result<(ash::Device, vk::Image, vk::DeviceMemory), RenderError> {
    let vk_err = |e: vk::Result| RenderError::Android(e.to_string());
    let device = hal.raw_device().clone();
    let ahb_fn = ash::android::external_memory_android_hardware_buffer::Device::new(
        hal.shared_instance().raw_instance(),
        &device,
    );
    let buffer = ahb.as_ptr().cast::<vk::AHardwareBuffer>();
    let mut format = vk::AndroidHardwareBufferFormatPropertiesANDROID::default();
    let mut props = vk::AndroidHardwareBufferPropertiesANDROID::default().push_next(&mut format);
    // SAFETY: `buffer` is live (contract); `props` chains one valid struct.
    unsafe { ahb_fn.get_android_hardware_buffer_properties(buffer, &mut props) }.map_err(vk_err)?;
    let (allocation_size, memory_types) = (props.allocation_size, props.memory_type_bits);
    if format.format != vk::Format::R8G8B8A8_UNORM || memory_types == 0 {
        return Err(RenderError::InvalidTexture);
    }

    let mut external = vk::ExternalMemoryImageCreateInfo::default()
        .handle_types(vk::ExternalMemoryHandleTypeFlags::ANDROID_HARDWARE_BUFFER_ANDROID);
    let image_info = vk::ImageCreateInfo::default()
        .push_next(&mut external)
        .image_type(vk::ImageType::TYPE_2D)
        .format(vk::Format::R8G8B8A8_UNORM)
        .extent(vk::Extent3D {
            width,
            height,
            depth: 1,
        })
        .mip_levels(1)
        .array_layers(1)
        .samples(vk::SampleCountFlags::TYPE_1)
        .tiling(vk::ImageTiling::OPTIMAL)
        .usage(vk::ImageUsageFlags::SAMPLED)
        .sharing_mode(vk::SharingMode::EXCLUSIVE)
        .initial_layout(vk::ImageLayout::UNDEFINED);
    // SAFETY: a plain image create on wgpu's device with a fully initialised create info.
    let image = unsafe { device.create_image(&image_info, None) }.map_err(vk_err)?;

    let mut import = vk::ImportAndroidHardwareBufferInfoANDROID::default().buffer(buffer);
    let mut dedicated = vk::MemoryDedicatedAllocateInfo::default().image(image);
    let alloc = vk::MemoryAllocateInfo::default()
        .allocation_size(allocation_size)
        .memory_type_index(memory_types.trailing_zeros())
        .push_next(&mut import)
        .push_next(&mut dedicated);
    // SAFETY: imports the AHB's memory (the driver takes its own AHB reference) as a dedicated
    // allocation for `image`; on failure the image is destroyed before returning.
    let memory = unsafe {
        device
            .allocate_memory(&alloc, None)
            .and_then(|memory| {
                device
                    .bind_image_memory(image, memory, 0)
                    .map(|()| memory)
                    .inspect_err(|_| device.free_memory(memory, None))
            })
            .inspect_err(|_| device.destroy_image(image, None))
    }
    .map_err(vk_err)?;

    // SAFETY: `image` and `memory` are ours and unused by wgpu yet; the caller keeps wgpu's
    // queue to itself (contract).
    if let Err(e) = unsafe { acquire_from_foreign(hal, &device, image) } {
        // SAFETY: as above; nothing else holds them.
        unsafe {
            device.destroy_image(image, None);
            device.free_memory(memory, None);
        }
        return Err(vk_err(e));
    }
    Ok((device, image, memory))
}

/// One barrier on wgpu's queue: the image leaves the foreign (GLES) queue family for wgpu's and
/// becomes SHADER_READ_ONLY_OPTIMAL. Waits until it ran.
///
/// # Safety
/// `image` must be a fresh color image on `device` (wgpu's device behind `hal`), and no other
/// thread may submit to wgpu's queue meanwhile (SPIKE: the caller is the only GPU user).
unsafe fn acquire_from_foreign(
    hal: &vulkan::Device,
    device: &ash::Device,
    image: vk::Image,
) -> Result<(), vk::Result> {
    let family = hal.queue_family_index();
    let pool_info = vk::CommandPoolCreateInfo::default()
        .flags(vk::CommandPoolCreateFlags::TRANSIENT)
        .queue_family_index(family);
    // SAFETY: plain object creation on wgpu's device; everything is destroyed below.
    unsafe {
        let pool = device.create_command_pool(&pool_info, None)?;
        let run = || -> Result<(), vk::Result> {
            let cmd = device.allocate_command_buffers(
                &vk::CommandBufferAllocateInfo::default()
                    .command_pool(pool)
                    .level(vk::CommandBufferLevel::PRIMARY)
                    .command_buffer_count(1),
            )?[0]; // One buffer was asked for, so index 0 exists.
            device.begin_command_buffer(
                cmd,
                &vk::CommandBufferBeginInfo::default()
                    .flags(vk::CommandBufferUsageFlags::ONE_TIME_SUBMIT),
            )?;
            // UNDEFINED as the old layout is what AHB importers (Skia, Dawn) use with the
            // foreign family; the foreign release keeps the contents.
            let barrier = vk::ImageMemoryBarrier::default()
                .src_access_mask(vk::AccessFlags::empty())
                .dst_access_mask(vk::AccessFlags::SHADER_READ)
                .old_layout(vk::ImageLayout::UNDEFINED)
                .new_layout(vk::ImageLayout::SHADER_READ_ONLY_OPTIMAL)
                .src_queue_family_index(vk::QUEUE_FAMILY_FOREIGN_EXT)
                .dst_queue_family_index(family)
                .image(image)
                .subresource_range(vk::ImageSubresourceRange {
                    aspect_mask: vk::ImageAspectFlags::COLOR,
                    base_mip_level: 0,
                    level_count: 1,
                    base_array_layer: 0,
                    layer_count: 1,
                });
            device.cmd_pipeline_barrier(
                cmd,
                vk::PipelineStageFlags::TOP_OF_PIPE,
                vk::PipelineStageFlags::FRAGMENT_SHADER,
                vk::DependencyFlags::empty(),
                &[],
                &[],
                &[barrier],
            );
            device.end_command_buffer(cmd)?;
            let fence = device.create_fence(&vk::FenceCreateInfo::default(), None)?;
            let submitted = device
                .queue_submit(
                    hal.raw_queue(),
                    &[vk::SubmitInfo::default().command_buffers(&[cmd])],
                    fence,
                )
                .and_then(|()| device.wait_for_fences(&[fence], true, u64::MAX));
            // SPIKE: on a failed wait (device lost) the fence, pool, image and memory are freed
            // while the submit may still be pending; the device is unusable by then anyway.
            device.destroy_fence(fence, None);
            submitted
        };
        let result = run();
        device.destroy_command_pool(pool, None);
        result
    }
}
