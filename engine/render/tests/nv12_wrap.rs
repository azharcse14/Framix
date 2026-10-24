//! A decoder frame reaches wgpu with no copy (P1-002): VideoToolbox hands out IOSurface-backed
//! NV12 buffers, so this builds the same two-plane IOSurface, wraps a Metal texture on each
//! plane, and checks the YCbCr -> RGB pass. Runs on the host GPU (macOS).
#![cfg(target_vendor = "apple")]

mod common;

use common::{Texture, bgra_target, ptr, rgb};

use framix_render::{Gpu, Placement, YcbcrMatrix, YcbcrRange, YcbcrSpace};
use objc2_core_foundation::{CFArray, CFDictionary, CFNumber, CFRetained, CFString, CFType};
use objc2_io_surface::{
    IOSurfaceLockOptions, IOSurfaceRef, kIOSurfaceAllocSize, kIOSurfaceHeight,
    kIOSurfacePixelFormat, kIOSurfacePlaneBytesPerElement, kIOSurfacePlaneBytesPerRow,
    kIOSurfacePlaneHeight, kIOSurfacePlaneInfo, kIOSurfacePlaneOffset, kIOSurfacePlaneSize,
    kIOSurfacePlaneWidth, kIOSurfaceWidth,
};
use objc2_metal::{
    MTLCreateSystemDefaultDevice, MTLDevice, MTLPixelFormat, MTLStorageMode, MTLTextureDescriptor,
    MTLTextureUsage,
};

const W: usize = 16;
const H: usize = 8;
/// '420v', kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: what VideoToolbox decodes to.
const NV12_VIDEO: i32 = 0x3432_3076;
/// '420f', kCVPixelFormatType_420YpCbCr8BiPlanarFullRange.
const NV12_FULL: i32 = 0x3432_3066;

/// Y, Cb, Cr per quadrant: top-left, top-right, bottom-left, bottom-right.
type Quadrants = [[u8; 3]; 4];

fn number(v: usize) -> CFRetained<CFNumber> {
    CFNumber::new_isize(v as isize)
}

fn dictionary(pairs: &[(&CFString, &CFType)]) -> CFRetained<CFDictionary<CFString, CFType>> {
    let (keys, values): (Vec<_>, Vec<_>) = pairs.iter().copied().unzip();
    CFDictionary::from_slices(&keys, &values)
}

/// A two-plane NV12 IOSurface filled with flat quadrants.
fn nv12_surface(format: i32, quadrants: &Quadrants) -> CFRetained<IOSurfaceRef> {
    let (cw, ch) = (W / 2, H / 2);
    let (y_size, c_size) = (W * H, cw * 2 * ch);
    // SAFETY: the keys are the documented IOSurface property names with the value types the
    // IOSurface docs give (CFNumber, an array of plane dictionaries).
    let surface = unsafe {
        let plane = |w: usize, h: usize, bpe: usize, offset: usize, size: usize| {
            let values = [w, h, bpe, w * bpe, offset, size].map(number);
            let keys = [
                kIOSurfacePlaneWidth,
                kIOSurfacePlaneHeight,
                kIOSurfacePlaneBytesPerElement,
                kIOSurfacePlaneBytesPerRow,
                kIOSurfacePlaneOffset,
                kIOSurfacePlaneSize,
            ];
            let pairs: Vec<_> = keys.iter().zip(&values).map(|(k, v)| (*k, &***v)).collect();
            dictionary(&pairs)
        };
        let planes = [plane(W, H, 1, 0, y_size), plane(cw, ch, 2, y_size, c_size)];
        let planes = CFArray::from_retained_objects(&planes);
        let (w, h, f, size) = (
            number(W),
            number(H),
            CFNumber::new_i32(format),
            number(y_size + c_size),
        );
        let props = dictionary(&[
            (kIOSurfaceWidth, &w),
            (kIOSurfaceHeight, &h),
            (kIOSurfacePixelFormat, &f),
            (kIOSurfaceAllocSize, &size),
            (kIOSurfacePlaneInfo, &planes),
        ]);
        IOSurfaceRef::new(props.as_opaque()).expect("IOSurface")
    };
    let quadrant = |x: usize, y: usize, w: usize, h: usize| {
        quadrants[usize::from(y >= h / 2) * 2 + usize::from(x >= w / 2)]
    };
    // SAFETY: locked for writing; each write stays inside its plane's rows.
    unsafe {
        surface.lock(IOSurfaceLockOptions::empty(), std::ptr::null_mut());
        let luma = surface.base_address_of_plane(0).as_ptr().cast::<u8>();
        let luma_row = surface.bytes_per_row_of_plane(0);
        for y in 0..H {
            for x in 0..W {
                *luma.add(y * luma_row + x) = quadrant(x, y, W, H)[0];
            }
        }
        let chroma = surface.base_address_of_plane(1).as_ptr().cast::<u8>();
        let chroma_row = surface.bytes_per_row_of_plane(1);
        for y in 0..ch {
            for x in 0..cw {
                let [_, cb, cr] = quadrant(x, y, cw, ch);
                *chroma.add(y * chroma_row + x * 2) = cb;
                *chroma.add(y * chroma_row + x * 2 + 1) = cr;
            }
        }
        surface.unlock(IOSurfaceLockOptions::empty(), std::ptr::null_mut());
    }
    surface
}

/// A Metal texture on one plane of `surface`, as the iOS app makes them from a CVPixelBuffer.
fn plane_texture(surface: &IOSurfaceRef, plane: usize, format: MTLPixelFormat) -> Texture {
    let device = MTLCreateSystemDefaultDevice().expect("Metal device");
    // SAFETY: the descriptor matches the plane's size and element format.
    unsafe {
        let desc = MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
            format,
            surface.width_of_plane(plane),
            surface.height_of_plane(plane),
            false,
        );
        desc.setUsage(MTLTextureUsage::ShaderRead);
        desc.setStorageMode(MTLStorageMode::Shared);
        device
            .newTextureWithDescriptor_iosurface_plane(&desc, surface, plane)
            .expect("texture on IOSurface plane")
    }
}

/// Draws `quadrants` through the NV12 pass and returns the RGB at each quadrant's center.
fn convert(format: i32, quadrants: &Quadrants, space: YcbcrSpace) -> [[u8; 3]; 4] {
    let gpu = Gpu::new().expect("gpu");
    let surface = nv12_surface(format, quadrants);
    let luma = plane_texture(&surface, 0, MTLPixelFormat::R8Unorm);
    let chroma = plane_texture(&surface, 1, MTLPixelFormat::RG8Unorm);
    let target = bgra_target(W, H);
    // SAFETY: all three are live id<MTLTexture>s on the system default device.
    let (y, cbcr, out) = unsafe {
        (
            gpu.wrap_metal_plane(ptr(&luma)).expect("wrap luma"),
            gpu.wrap_metal_plane(ptr(&chroma)).expect("wrap chroma"),
            gpu.wrap_metal_texture(ptr(&target)).expect("wrap target"),
        )
    };
    gpu.draw_nv12(&out, &y, &cbcr, space, &Placement::FILL)
        .expect("draw");
    let (qx, qy) = (W / 4, H / 4);
    [
        rgb(&target, qx, qy),
        rgb(&target, W - qx, qy),
        rgb(&target, qx, H - qy),
        rgb(&target, W - qx, H - qy),
    ]
}

fn assert_close(got: [[u8; 3]; 4], want: [[u8; 3]; 4]) {
    for (g, w) in got.iter().zip(&want) {
        assert!(
            g.iter().zip(w).all(|(a, b)| a.abs_diff(*b) <= 2),
            "got {got:?}, want {want:?}"
        );
    }
}

#[test]
fn converts_bt709_video_range_planes() {
    // BT.709 video range codes for red, green, blue and mid gray.
    let quadrants = [
        [63, 102, 240],
        [173, 42, 26],
        [32, 240, 118],
        [126, 128, 128],
    ];
    let space = YcbcrSpace {
        matrix: YcbcrMatrix::Bt709,
        range: YcbcrRange::Video,
    };
    let got = convert(NV12_VIDEO, &quadrants, space);
    assert_close(
        got,
        [[255, 0, 0], [0, 255, 0], [0, 0, 255], [128, 128, 128]],
    );
}

#[test]
fn converts_bt601_full_range_planes() {
    // BT.601 full range (JPEG) codes for red, green, blue and mid gray.
    let quadrants = [
        [76, 85, 255],
        [150, 44, 21],
        [29, 255, 107],
        [128, 128, 128],
    ];
    let space = YcbcrSpace {
        matrix: YcbcrMatrix::Bt601,
        range: YcbcrRange::Full,
    };
    let got = convert(NV12_FULL, &quadrants, space);
    assert_close(
        got,
        [[254, 0, 0], [0, 255, 1], [0, 0, 254], [128, 128, 128]],
    );
}

#[test]
fn rejects_planes_of_the_wrong_format_or_usage() {
    let gpu = Gpu::new().expect("gpu");
    let surface = nv12_surface(NV12_VIDEO, &[[16, 128, 128]; 4]);
    let render_only = {
        let device = MTLCreateSystemDefaultDevice().expect("Metal device");
        // SAFETY: plain descriptor setup on a fresh object.
        unsafe {
            let desc =
                MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
                    MTLPixelFormat::R8Unorm,
                    W,
                    H,
                    false,
                );
            desc.setUsage(MTLTextureUsage::RenderTarget);
            device.newTextureWithDescriptor(&desc).expect("texture")
        }
    };
    let bgra = bgra_target(W, H);
    // SAFETY: null is rejected before use; the others are live id<MTLTexture>s.
    unsafe {
        assert!(gpu.wrap_metal_plane(std::ptr::null_mut()).is_err());
        assert!(gpu.wrap_metal_plane(ptr(&render_only)).is_err());
        assert!(gpu.wrap_metal_plane(ptr(&bgra)).is_err());
    }

    // Planes swapped: luma must be R8, chroma RG8.
    let luma = plane_texture(&surface, 0, MTLPixelFormat::R8Unorm);
    let chroma = plane_texture(&surface, 1, MTLPixelFormat::RG8Unorm);
    let target = bgra_target(W, H);
    // SAFETY: live id<MTLTexture>s on the system default device.
    let (y, cbcr, out) = unsafe {
        (
            gpu.wrap_metal_plane(ptr(&luma)).expect("wrap luma"),
            gpu.wrap_metal_plane(ptr(&chroma)).expect("wrap chroma"),
            gpu.wrap_metal_texture(ptr(&target)).expect("wrap target"),
        )
    };
    let space = YcbcrSpace {
        matrix: YcbcrMatrix::Bt709,
        range: YcbcrRange::Video,
    };
    assert!(
        gpu.draw_nv12(&out, &cbcr, &y, space, &Placement::FILL)
            .is_err()
    );
}
