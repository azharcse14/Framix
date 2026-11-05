//! Export draws every visible video layer of each frame, bottom to top (P1-071).

use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{ClipPlacement, ClipTransform, Layer, MediaId, Timeline, TrackKind};

struct Buffers;

impl Encoder for Buffers {
    fn frame(&mut self, _: Time) -> Result<PlatformTexture, String> {
        Ok(PlatformTexture { id: 1, handle: 1 })
    }
    fn finish(self: Box<Self>, _: bool) -> Result<(), String> {
        Ok(())
    }
}

struct Host;

impl EncoderHost for Host {
    fn open(&self, _: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        Ok(Box::new(Buffers))
    }
}

/// Media ids drawn per frame, bottom to top.
#[derive(Default)]
struct Renderer(Vec<Vec<u64>>);

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.0.push(layers.map(|l| l.media_id.0).collect());
        Ok(())
    }
}

fn video() -> Media {
    Media::validate(RawMedia {
        uri: "media/v.mp4".into(),
        kind: MediaKind::Video,
        duration_value: 10_000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: "avc1".into(),
    })
    .unwrap()
}

#[test]
fn frames_under_both_clips_draw_both() {
    let tenth = TICKS_PER_SECOND / 10;
    let mut tl = Timeline::default();
    tl.set_aspect(AspectRatio::LANDSCAPE_16_9);
    tl.restore_media(MediaId(1), video());
    tl.restore_media(MediaId(2), video());
    let low = tl.add_track(TrackKind::Video);
    let high = tl.add_track(TrackKind::Video);
    let clip = |media, duration| ClipPlacement {
        media: MediaId(media),
        source_start: Time(0),
        start: Time(0),
        duration: Time(duration),
    };
    tl.insert_clip(low, clip(1, 2 * tenth)).unwrap();
    let top = tl.insert_clip(high, clip(2, tenth)).unwrap();
    tl.set_clip_transform(
        top,
        ClipTransform {
            scale: 500,
            ..ClipTransform::default()
        },
    )
    .unwrap();
    let mut renderer = Renderer::default();
    run_export(&tl, &mut renderer, &Host, "/out.mp4").unwrap();
    // 0.2 s at 30 fps: frames 0-2 are under both clips, 3-5 under the bottom only.
    assert_eq!(
        renderer.0,
        [
            vec![1, 2],
            vec![1, 2],
            vec![1, 2],
            vec![1],
            vec![1],
            vec![1]
        ]
    );
}
