//! GpuRenderer composites every layer bottom to top (P1-071): an upper picture covers only its
//! own frame, the bars around the canvas stay black, and a layer that can't be decoded leaves
//! the ones under it. Runs on the host GPU (macOS).
#![cfg(target_vendor = "apple")]

mod common;

use common::{Texture, bgra_target, ptr, rgb};
use objc2_metal::{
    MTLCreateSystemDefaultDevice, MTLDevice, MTLOrigin, MTLPixelFormat, MTLRegion, MTLSize,
    MTLStorageMode, MTLTexture, MTLTextureDescriptor, MTLTextureUsage,
};

use framix_app::preview::{Decoder, DrawError, Frame, PlatformTexture, PreviewRenderer};
use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, ClipTransform, MediaId, Timeline, TrackKind};
use framix_render::GpuRenderer;

const RED: [u8; 3] = [255, 0, 0];
const GREEN: [u8; 3] = [0, 255, 0];

/// A shader-readable RGBA8 Metal texture of one color.
fn picture(rgba: [u8; 4]) -> Texture {
    let device = MTLCreateSystemDefaultDevice().expect("Metal device");
    let (w, h) = (4usize, 4usize);
    let bytes: Vec<u8> = rgba.repeat(w * h);
    // SAFETY: plain descriptor setup on a fresh object; `bytes` holds w*h RGBA8 pixels.
    unsafe {
        let desc = MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
            MTLPixelFormat::RGBA8Unorm,
            w,
            h,
            false,
        );
        desc.setUsage(MTLTextureUsage::ShaderRead);
        desc.setStorageMode(MTLStorageMode::Shared);
        let texture = device.newTextureWithDescriptor(&desc).expect("texture");
        texture.replaceRegion_mipmapLevel_withBytes_bytesPerRow(
            MTLRegion {
                origin: MTLOrigin { x: 0, y: 0, z: 0 },
                size: MTLSize {
                    width: w,
                    height: h,
                    depth: 1,
                },
            },
            0,
            std::ptr::NonNull::new(bytes.as_ptr().cast_mut().cast()).unwrap(),
            w * 4,
        );
        texture
    }
}

/// Answers every photo with this texture handle, or fails when there is none. The test keeps
/// the texture alive (a retained id<MTLTexture> is not Send).
struct OneFrame(Option<usize>);

impl Decoder for OneFrame {
    fn frame(&mut self, _: &Media, _: Time, _: Option<u32>) -> Result<Frame, String> {
        let texture = self.0.ok_or("unreadable")?;
        Ok(Frame::Rgba { texture })
    }
}

/// A red color under a 2:1 photo at half size, on a 16:9 canvas.
fn pip() -> Timeline {
    let mut tl = Timeline::default();
    tl.set_aspect(AspectRatio::LANDSCAPE_16_9);
    tl.restore_media(MediaId(1), Media::solid(0xff00_00ff));
    tl.restore_media(
        MediaId(2),
        Media::validate(RawMedia {
            uri: "media/p.png".into(),
            kind: MediaKind::Image,
            duration_value: 0,
            duration_timescale: 0,
            width: 1000,
            height: 500,
            rotation: 0,
            codec: String::new(),
        })
        .unwrap(),
    );
    let clip = |media| ClipPlacement {
        media: MediaId(media),
        source_start: Time(0),
        start: Time(0),
        duration: Time(1000),
    };
    let low = tl.add_track(TrackKind::Video);
    let high = tl.add_track(TrackKind::Video);
    tl.insert_clip(low, clip(1)).unwrap();
    let top = tl.insert_clip(high, clip(2)).unwrap();
    tl.set_clip_transform(
        top,
        ClipTransform {
            scale: 500,
            ..ClipTransform::default()
        },
    )
    .unwrap();
    tl
}

fn draw(decoded: Option<&Texture>, target: &Texture, tl: &Timeline) -> Result<(), DrawError> {
    let decoded = decoded.map(|t| ptr(t) as usize);
    // SAFETY: the target is a live BGRA render-target id<MTLTexture>, the decoder's frame a live
    // RGBA8 texture, both on the system default device.
    let mut renderer = unsafe { GpuRenderer::new(Some(Box::new(OneFrame(decoded)))) };
    renderer.draw(
        PlatformTexture {
            id: 1,
            handle: ptr(target) as usize,
        },
        Time(0),
        &mut tl.layers_at(Time(0)),
    )
}

#[test]
fn the_upper_picture_covers_only_its_frame() {
    let target = bgra_target(32, 18);
    draw(Some(&picture([0, 255, 0, 255])), &target, &pip()).expect("draw");
    assert_eq!(rgb(&target, 16, 9), GREEN, "centre: the photo");
    assert_eq!(rgb(&target, 1, 1), RED, "corner: the color under it");
}

#[test]
fn the_bars_around_the_canvas_stay_black() {
    // 64x18 holds a 32x18 canvas with 16 px bars each side.
    let target = bgra_target(64, 18);
    draw(Some(&picture([0, 255, 0, 255])), &target, &pip()).expect("draw");
    assert_eq!(rgb(&target, 2, 9), [0, 0, 0]);
    assert_eq!(rgb(&target, 17, 1), RED);
    assert_eq!(rgb(&target, 32, 9), GREEN);
}

#[test]
fn an_undecodable_top_leaves_the_layer_under_it() {
    let target = bgra_target(32, 18);
    assert!(matches!(
        draw(None, &target, &pip()),
        Err(DrawError::Decode(_))
    ));
    assert_eq!(rgb(&target, 16, 9), RED);
    assert_eq!(rgb(&target, 1, 1), RED);
}

#[test]
fn no_layers_draw_black() {
    let target = bgra_target(8, 8);
    draw(None, &target, &Timeline::default()).expect("draw");
    assert_eq!(rgb(&target, 4, 4), [0, 0, 0]);
}
