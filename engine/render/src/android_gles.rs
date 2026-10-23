//! SPIKE (P1-004): the GLES-backend twin of [`crate::android::import_ahb`]. On phones where
//! wgpu falls back to GLES, the RGBA8 AHardwareBuffer from the platform's OES pass is bound to
//! a GL texture through an EGLImage, still without a copy. EGL and GL come from the system
//! libraries; extension functions from eglGetProcAddress.

use std::ffi::{CStr, c_char, c_void};
use std::num::NonZeroU32;
use std::ptr::NonNull;

use wgpu::hal::api::Gles;

use crate::RenderError;

const EGL_NATIVE_BUFFER_ANDROID: i32 = 0x3140;
const EGL_IMAGE_PRESERVED_KHR: i32 = 0x30D2;
const EGL_TRUE: i32 = 1;
const EGL_NONE: i32 = 0x3038;
const GL_TEXTURE_2D: u32 = 0x0DE1;
const GL_NO_ERROR: u32 = 0;

#[link(name = "EGL")]
unsafe extern "C" {
    fn eglGetCurrentDisplay() -> *mut c_void;
    fn eglGetProcAddress(name: *const c_char) -> *mut c_void;
}

#[link(name = "GLESv2")]
unsafe extern "C" {
    fn glGenTextures(n: i32, textures: *mut u32);
    fn glBindTexture(target: u32, texture: u32);
    fn glDeleteTextures(n: i32, textures: *const u32);
    fn glGetError() -> u32;
}

type GetNativeClientBuffer = unsafe extern "C" fn(buffer: *const c_void) -> *mut c_void;
type CreateImage = unsafe extern "C" fn(
    display: *mut c_void,
    context: *mut c_void,
    target: u32,
    buffer: *mut c_void,
    attribs: *const i32,
) -> *mut c_void;
type DestroyImage = unsafe extern "C" fn(display: *mut c_void, image: *mut c_void) -> u32;
type ImageTargetTexture = unsafe extern "C" fn(target: u32, image: *mut c_void);

/// Loads an EGL/GL extension function, or says which is missing.
///
/// # Safety
/// `F` must be the function's real signature.
unsafe fn proc<F>(name: &CStr) -> Result<F, RenderError> {
    // SAFETY: `name` is a NUL-terminated string.
    let ptr = unsafe { eglGetProcAddress(name.as_ptr()) };
    if ptr.is_null() {
        return Err(RenderError::Android(format!(
            "no {}",
            name.to_string_lossy()
        )));
    }
    // SAFETY: a non-null proc address is that function; `F` matches it per the contract.
    Ok(unsafe { std::mem::transmute_copy::<*mut c_void, F>(&ptr) })
}

/// Imports an RGBA8 AHardwareBuffer of `width` x `height` as a sampled wgpu texture on the
/// GLES backend, without copying.
///
/// # Safety
/// As [`crate::android::import_ahb`]: `ahb` is live for the call, the GPU work that wrote it
/// is done, and nothing writes it while the texture is used. `device` is on the GLES backend.
pub(crate) unsafe fn import_ahb(
    device: &wgpu::Device,
    ahb: NonNull<c_void>,
    width: u32,
    height: u32,
) -> Result<wgpu::Texture, RenderError> {
    // SAFETY: as_hal only borrows wgpu's device; it is dropped before the texture is wrapped.
    let hal = unsafe { device.as_hal::<Gles>() }.ok_or(RenderError::InvalidTexture)?;
    let name = {
        // Makes wgpu's EGL context current on this thread for the calls below.
        let _gl = hal.context().lock();
        // SAFETY: each name is the EGL/GL entry point with the matching signature
        // (EGL_ANDROID_get_native_client_buffer, EGL_KHR_image_base, GL_OES_EGL_image).
        let (client_buffer, create, destroy, target) = unsafe {
            (
                proc::<GetNativeClientBuffer>(c"eglGetNativeClientBufferANDROID")?,
                proc::<CreateImage>(c"eglCreateImageKHR")?,
                proc::<DestroyImage>(c"eglDestroyImageKHR")?,
                proc::<ImageTargetTexture>(c"glEGLImageTargetTexture2DOES")?,
            )
        };
        // SAFETY: wgpu's context is current (lock above); `ahb` is live per the contract; the
        // image is destroyed once, after the texture took its own reference to the storage.
        unsafe {
            let display = eglGetCurrentDisplay();
            let buffer = client_buffer(ahb.as_ptr());
            let attribs = [EGL_IMAGE_PRESERVED_KHR, EGL_TRUE, EGL_NONE];
            let image = create(
                display,
                std::ptr::null_mut(),
                EGL_NATIVE_BUFFER_ANDROID as u32,
                buffer,
                attribs.as_ptr(),
            );
            if image.is_null() {
                return Err(RenderError::Android("eglCreateImageKHR failed".into()));
            }
            let mut name = 0;
            glGenTextures(1, &mut name);
            glBindTexture(GL_TEXTURE_2D, name);
            target(GL_TEXTURE_2D, image);
            let error = glGetError();
            glBindTexture(GL_TEXTURE_2D, 0);
            destroy(display, image);
            match NonZeroU32::new(name) {
                Some(name) if error == GL_NO_ERROR => name,
                _ => {
                    glDeleteTextures(1, &name);
                    return Err(RenderError::Android(format!(
                        "EGLImage texture failed: GL error {error:#x}"
                    )));
                }
            }
        }
    };
    let size = wgpu::Extent3d {
        width,
        height,
        depth_or_array_layers: 1,
    };
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
    // SAFETY: `name` is a GL_TEXTURE_2D holding the AHB's RGBA8 storage at `size`; with no drop
    // callback wgpu owns it and deletes it.
    let texture = unsafe { hal.texture_from_raw(name, &hal_desc, None) };
    drop(hal);
    // SAFETY: the hal texture is on this device and matches the descriptor.
    Ok(unsafe {
        device.create_texture_from_hal::<Gles>(
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
