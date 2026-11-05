//! The draws check their textures and answer InvalidTexture instead of letting wgpu fail
//! (P1-058): a chroma plane that is not half the luma, or a texture without the usage the pass
//! needs. Plain wgpu textures, so it runs on the host GPU (macOS).
#![cfg(target_vendor = "apple")]

use framix_app::preview::{YcbcrMatrix, YcbcrRange, YcbcrSpace};
use framix_render::{Gpu, Placement, RenderError};

const SPACE: YcbcrSpace = YcbcrSpace {
    matrix: YcbcrMatrix::Bt709,
    range: YcbcrRange::Video,
};

fn texture(
    gpu: &Gpu,
    (width, height): (u32, u32),
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> wgpu::Texture {
    gpu.device().create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage,
        view_formats: &[],
    })
}

fn target(gpu: &Gpu, usage: wgpu::TextureUsages) -> wgpu::Texture {
    texture(gpu, (8, 8), wgpu::TextureFormat::Bgra8Unorm, usage)
}

fn plane(gpu: &Gpu, size: (u32, u32), chroma: bool, usage: wgpu::TextureUsages) -> wgpu::Texture {
    let format = if chroma {
        wgpu::TextureFormat::Rg8Unorm
    } else {
        wgpu::TextureFormat::R8Unorm
    };
    texture(gpu, size, format, usage)
}

const SAMPLED: wgpu::TextureUsages = wgpu::TextureUsages::TEXTURE_BINDING;
const RENDER: wgpu::TextureUsages = wgpu::TextureUsages::RENDER_ATTACHMENT;

fn invalid(result: Result<(), RenderError>) -> bool {
    matches!(result, Err(RenderError::InvalidTexture))
}

#[test]
fn odd_sized_planes_round_the_chroma_up() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, RENDER);
    let y = plane(&gpu, (5, 3), false, SAMPLED);
    let cbcr = plane(&gpu, (3, 2), true, SAMPLED);
    gpu.draw_nv12(&out, &y, &cbcr, SPACE, &Placement::FILL)
        .expect("draw");
}

#[test]
fn rejects_a_chroma_plane_that_is_not_half_the_luma() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, RENDER);
    let y = plane(&gpu, (8, 4), false, SAMPLED);
    for size in [(8, 4), (4, 4), (2, 2), (5, 2)] {
        let cbcr = plane(&gpu, size, true, SAMPLED);
        assert!(
            invalid(gpu.draw_nv12(&out, &y, &cbcr, SPACE, &Placement::FILL)),
            "chroma {size:?} for luma (8, 4)"
        );
    }
}

#[test]
fn rejects_planes_the_pass_cannot_sample() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, RENDER);
    let y = plane(&gpu, (8, 4), false, SAMPLED);
    let cbcr = plane(&gpu, (4, 2), true, SAMPLED);
    let y_unsampled = plane(&gpu, (8, 4), false, wgpu::TextureUsages::COPY_DST);
    let cbcr_unsampled = plane(&gpu, (4, 2), true, wgpu::TextureUsages::COPY_DST);
    assert!(invalid(gpu.draw_nv12(
        &out,
        &y_unsampled,
        &cbcr,
        SPACE,
        &Placement::FILL
    )));
    assert!(invalid(gpu.draw_nv12(
        &out,
        &y,
        &cbcr_unsampled,
        SPACE,
        &Placement::FILL
    )));
}

#[test]
fn rejects_a_target_the_pass_cannot_render_into() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, SAMPLED);
    let y = plane(&gpu, (8, 4), false, SAMPLED);
    let cbcr = plane(&gpu, (4, 2), true, SAMPLED);
    let rgba = texture(&gpu, (8, 4), wgpu::TextureFormat::Rgba8Unorm, SAMPLED);
    assert!(invalid(gpu.draw_nv12(
        &out,
        &y,
        &cbcr,
        SPACE,
        &Placement::FILL
    )));
    assert!(invalid(gpu.draw_rgba(&out, &rgba, &Placement::FILL)));
    assert!(invalid(gpu.draw_black(&out)));
}

#[test]
fn rejects_an_rgba_frame_the_pass_cannot_sample() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, RENDER);
    let rgba = texture(
        &gpu,
        (8, 4),
        wgpu::TextureFormat::Rgba8Unorm,
        wgpu::TextureUsages::COPY_DST,
    );
    assert!(invalid(gpu.draw_rgba(&out, &rgba, &Placement::FILL)));
}

fn layered(
    gpu: &Gpu,
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
    (layers, mips): (u32, u32),
) -> wgpu::Texture {
    gpu.device().create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: 8,
            height: 8,
            depth_or_array_layers: layers,
        },
        mip_level_count: mips,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage,
        view_formats: &[],
    })
}

#[test]
fn rejects_array_or_mipmapped_textures() {
    let gpu = Gpu::new().expect("gpu");
    let out = target(&gpu, RENDER);
    let rgba = wgpu::TextureFormat::Rgba8Unorm;
    let two_layers = layered(&gpu, rgba, SAMPLED, (2, 1));
    assert!(invalid(gpu.draw_rgba(&out, &two_layers, &Placement::FILL)));
    let frame = layered(&gpu, rgba, SAMPLED, (1, 1));
    for shape in [(2, 1), (1, 2)] {
        let out = layered(&gpu, wgpu::TextureFormat::Bgra8Unorm, RENDER, shape);
        assert!(
            invalid(gpu.draw_rgba(&out, &frame, &Placement::FILL)),
            "target layers/mips {shape:?}"
        );
    }
}

#[test]
fn the_test_pattern_rejects_a_target_of_another_format() {
    let gpu = Gpu::new().expect("gpu");
    let out = texture(&gpu, (8, 8), wgpu::TextureFormat::Rgba8Unorm, RENDER);
    assert!(invalid(gpu.draw_test_pattern(&out)));
}
