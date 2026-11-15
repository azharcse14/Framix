//! A queued preview draw on the engine thread: queue it and wait until the render thread drew
//! it (with a renderer that does nothing), as playback does once per frame. The numbers to
//! compare before and after a change to the render thread (.claude/rules/performance.md).

use std::sync::mpsc::{SyncSender, sync_channel};

use criterion::{Criterion, criterion_group, criterion_main};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_app::render_thread::RenderThread;
use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipTransform, Layer, MediaId};

struct Paced(SyncSender<()>);

impl PreviewRenderer for Paced {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        layers.for_each(drop);
        let _ = self.0.send(());
        Ok(())
    }
}

fn media(name: &str) -> Media {
    Media::validate(RawMedia {
        uri: format!("content://media/external/video/media/{name}"),
        kind: MediaKind::Video,
        duration_value: 4,
        duration_timescale: 1,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: "avc1".into(),
    })
    .expect("valid media")
}

fn queued_draw(c: &mut Criterion) {
    let (tx, done) = sync_channel(1);
    let mut renderer = RenderThread::spawn(
        move || Box::new(Paced(tx)) as Box<dyn PreviewRenderer>,
        |_| {},
        |_| {},
    )
    .expect("render thread");
    let media = [media("a"), media("b"), media("c")];
    let target = PlatformTexture { id: 7, handle: 70 };
    let mut time = 0;
    c.bench_function("queued draw, 3 layers", |b| {
        b.iter(|| {
            time += 1;
            let mut layers = media.iter().enumerate().map(|(i, m)| Layer {
                media_id: MediaId(i as u64),
                media: m,
                source_time: Time(time),
                transform: ClipTransform::default(),
                canvas: AspectRatio::default(),
                proxy_side: None,
            });
            renderer
                .draw(target, Time(time), &mut layers)
                .expect("draw");
            done.recv().expect("drawn");
        })
    });
}

criterion_group!(benches, queued_draw);
criterion_main!(benches);
