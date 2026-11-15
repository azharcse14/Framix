//! P1-119: a queued preview draw allocates nothing on the engine thread in steady state; the
//! layer list and its media are recycled, not collected and cloned anew per draw.

use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;
use std::sync::mpsc::{Receiver, SyncSender, sync_channel};

use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_app::render_thread::RenderThread;
use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipTransform, Layer, MediaId};

/// Counts allocations made on threads that switched counting on.
struct Counting;

thread_local! {
    static COUNTING: Cell<bool> = const { Cell::new(false) };
    static COUNT: Cell<usize> = const { Cell::new(0) };
}

fn note() {
    if COUNTING.with(Cell::get) {
        COUNT.with(|c| c.set(c.get() + 1));
    }
}

// SAFETY: forwards to the system allocator unchanged; counting touches only const-initialized
// thread-locals, which never allocate.
unsafe impl GlobalAlloc for Counting {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        note();
        // SAFETY: the caller's contract for `layout` is passed through.
        unsafe { System.alloc(layout) }
    }
    unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
        note();
        // SAFETY: as above.
        unsafe { System.alloc_zeroed(layout) }
    }
    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, size: usize) -> *mut u8 {
        note();
        // SAFETY: `ptr` came from this allocator (so from System) with `layout`.
        unsafe { System.realloc(ptr, layout, size) }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        // SAFETY: `ptr` came from this allocator (so from System) with `layout`.
        unsafe { System.dealloc(ptr, layout) }
    }
}

#[global_allocator]
static ALLOC: Counting = Counting;

/// Says when each draw is done, so the test paces draws like playback does.
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
        uri: format!("media/{name}.mp4"),
        kind: MediaKind::Video,
        duration_value: 4,
        duration_timescale: 1,
        width: 16,
        height: 16,
        rotation: 0,
        codec: "avc1".into(),
    })
    .unwrap()
}

fn draw(renderer: &mut RenderThread, done: &Receiver<()>, time: i64, media: &[Media]) {
    let mut layers = media.iter().enumerate().map(|(i, m)| Layer {
        media_id: MediaId(i as u64),
        media: m,
        source_time: Time(time),
        transform: ClipTransform::default(),
        canvas: AspectRatio::default(),
        proxy_side: None,
    });
    let target = PlatformTexture { id: 7, handle: 70 };
    renderer.draw(target, Time(time), &mut layers).unwrap();
    done.recv().unwrap();
}

#[test]
fn steady_state_queued_draws_do_not_allocate_per_draw() {
    const DRAWS: usize = 1000;
    let (tx, done) = sync_channel(1);
    let mut renderer = RenderThread::spawn(
        move || Box::new(Paced(tx)) as Box<dyn PreviewRenderer>,
        |_| {},
        |_| {},
    )
    .unwrap();
    let media = [media("a"), media("b")];
    // The first draw waits; a few more warm the recycled lists up.
    for time in 0..10 {
        draw(&mut renderer, &done, time, &media);
    }
    COUNTING.with(|c| c.set(true));
    for time in 0..DRAWS as i64 {
        draw(&mut renderer, &done, time, &media);
    }
    COUNTING.with(|c| c.set(false));
    let allocations = COUNT.with(Cell::get);
    // std's mpsc channel allocates one block per 31 messages; anything per draw is a bug.
    assert!(
        allocations < DRAWS / 10,
        "{allocations} allocations for {DRAWS} queued draws"
    );
}
