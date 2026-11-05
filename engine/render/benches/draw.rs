//! The preview's draws at 1080p on the host GPU (macOS): the numbers to compare before and
//! after a hot-path change (.claude/rules/performance.md). Each iteration waits for the GPU.

use criterion::{Criterion, criterion_group, criterion_main};
use framix_render::{Gpu, PREVIEW_FORMAT, Placement, YcbcrMatrix, YcbcrRange, YcbcrSpace};

const W: u32 = 1920;
const H: u32 = 1080;

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

fn draws(c: &mut Criterion) {
    let gpu = Gpu::new().expect("gpu");
    let sampled = wgpu::TextureUsages::TEXTURE_BINDING;
    let target = texture(
        &gpu,
        (W, H),
        PREVIEW_FORMAT,
        wgpu::TextureUsages::RENDER_ATTACHMENT,
    );
    let y = texture(&gpu, (W, H), wgpu::TextureFormat::R8Unorm, sampled);
    let cbcr = texture(&gpu, (W / 2, H / 2), wgpu::TextureFormat::Rg8Unorm, sampled);
    let rgba = texture(&gpu, (W, H), wgpu::TextureFormat::Rgba8Unorm, sampled);
    let space = YcbcrSpace {
        matrix: YcbcrMatrix::Bt709,
        range: YcbcrRange::Video,
    };
    c.bench_function("draw_nv12 1080p", |b| {
        b.iter(|| {
            gpu.draw_nv12(&target, &y, &cbcr, space, &Placement::FILL)
                .expect("draw")
        });
    });
    c.bench_function("draw_rgba 1080p", |b| {
        b.iter(|| {
            gpu.draw_rgba(&target, &rgba, &Placement::FILL)
                .expect("draw")
        });
    });
}

criterion_group!(benches, draws);
criterion_main!(benches);
