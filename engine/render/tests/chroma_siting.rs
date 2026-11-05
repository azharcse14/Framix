//! H.264 and HEVC default to left-sited 4:2:0 chroma (chroma_sample_loc_type 0): each chroma
//! sample sits on the even luma column, vertically between two rows (P1-058). Runs on the host
//! GPU (macOS).
#![cfg(target_vendor = "apple")]

mod common;

use common::{bgra_target, ptr, rgb};

use framix_render::{Gpu, Placement, YcbcrMatrix, YcbcrRange, YcbcrSpace};

const W: u32 = 16;
const H: u32 = 4;
const SPACE: YcbcrSpace = YcbcrSpace {
    matrix: YcbcrMatrix::Bt709,
    range: YcbcrRange::Video,
};

fn plane(
    gpu: &Gpu,
    (w, h): (u32, u32),
    format: wgpu::TextureFormat,
    bytes: &[u8],
) -> wgpu::Texture {
    let texture = gpu.device().create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: w,
            height: h,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    gpu.queue().write_texture(
        texture.as_image_copy(),
        bytes,
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(bytes.len() as u32 / h),
            rows_per_image: None,
        },
        texture.size(),
    );
    texture
}

/// Red at luma columns `xs` (middle row) of a gray frame whose Cr per chroma column is `cr`.
fn red_at(gpu: &Gpu, cr: impl Fn(u32) -> u8, xs: [usize; 2]) -> [u8; 2] {
    let (cw, ch) = (W / 2, H / 2);
    let y = plane(
        gpu,
        (W, H),
        wgpu::TextureFormat::R8Unorm,
        &vec![128; (W * H) as usize],
    );
    let cbcr: Vec<u8> = (0..ch)
        .flat_map(|_| (0..cw).flat_map(|x| [128, cr(x)]))
        .collect();
    let cbcr = plane(gpu, (cw, ch), wgpu::TextureFormat::Rg8Unorm, &cbcr);
    let target = bgra_target(W as usize, H as usize);
    // SAFETY: `target` is a live id<MTLTexture> on the system default device.
    let out = unsafe { gpu.wrap_metal_texture(ptr(&target)) }.expect("wrap target");
    gpu.draw_nv12(&out, &y, &cbcr, SPACE, &Placement::FILL)
        .expect("draw");
    xs.map(|x| rgb(&target, x, H as usize / 2)[0])
}

#[test]
fn chroma_is_left_sited() {
    let gpu = Gpu::new().expect("gpu");
    // Cr steps from 64 to 192 between chroma columns 3 and 4, i.e. luma columns 6 and 8;
    // no value clips at gray luma.
    let [at_7, at_8] = red_at(&gpu, |x| if x < 4 { 64 } else { 192 }, [7, 8]);
    let [neutral, _] = red_at(&gpu, |_| 128, [7, 8]);
    let [full, _] = red_at(&gpu, |_| 192, [7, 8]);
    // Luma column 7 lies halfway between chroma samples 3 (column 6) and 4 (column 8); column
    // 8 is chroma sample 4 itself. Center siting would give a quarter and three quarters.
    assert!(
        at_7.abs_diff(neutral) <= 2,
        "column 7: {at_7}, want ~{neutral}"
    );
    assert!(at_8.abs_diff(full) <= 2, "column 8: {at_8}, want ~{full}");
}
