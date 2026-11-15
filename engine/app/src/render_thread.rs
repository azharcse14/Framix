//! The preview's render thread (P1-053): draws, and the decodes under them, leave the engine
//! thread. The engine queues a draw and goes on; a burst of draws for one texture (a scrub)
//! draws only the latest; Flutter hears of a frame only once it is drawn. The layer lists sent
//! with draws come back to be refilled, so a steady stream of draws allocates nothing (P1-119).

use std::sync::mpsc::{Receiver, Sender, SyncSender, channel, sync_channel};
use std::thread::JoinHandle;

use framix_core::media::Media;
use framix_core::time::Time;
use framix_core::timeline::{Layer, LayerKey};

use crate::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};

/// How a draw went, for a caller that waits on it.
type Reply = Sender<Result<(), DrawError>>;

/// A draw's layers, owned so they can cross to the render thread.
type Layers = Vec<(Media, LayerKey)>;

/// Layer lists kept for reuse; one in flight and one queued is the usual steady state.
const SPARE_LISTS: usize = 4;

enum Job {
    /// Draw; with a reply the caller waits for the result, and the draw is never skipped.
    Draw(PlatformTexture, Time, Layers, Option<Reply>),
    /// Tell Flutter that texture `id` holds a new frame; queued after its draw.
    Signal(i64),
    /// Drop what the renderer keeps for the texture, then answer.
    Forget(PlatformTexture, Sender<()>),
    Stop,
}

/// A [`PreviewRenderer`] whose draws run on its own thread, with a renderer made there (so
/// thread-bound GPU state stays on one thread). Dropping it stops and joins the thread.
pub struct RenderThread {
    jobs: Sender<Job>,
    /// Layer lists the render thread is done with.
    spare: Receiver<Layers>,
    thread: Option<JoinHandle<()>>,
    /// Textures drawn once; until then a draw waits for its result.
    drawn: Vec<i64>,
}

impl RenderThread {
    /// Starts the thread and makes the renderer on it with `make`. On that thread, `signal`
    /// tells Flutter a texture holds a new frame, and `lost` reports a texture a draw lost on
    /// the GPU (once; later draws into it are skipped).
    pub fn spawn(
        make: impl FnOnce() -> Box<dyn PreviewRenderer> + Send + 'static,
        signal: impl Fn(i64) + Send + 'static,
        lost: impl Fn(i64) + Send + 'static,
    ) -> std::io::Result<Self> {
        let (jobs, inbox) = channel();
        let (recycle, spare) = sync_channel(SPARE_LISTS);
        let thread = std::thread::Builder::new()
            .name("framix-render".into())
            .spawn(move || serve(make(), &inbox, &recycle, &signal, &lost))?;
        Ok(Self {
            jobs,
            spare,
            thread: Some(thread),
            drawn: Vec::new(),
        })
    }

    /// Wraps the engine's `host`: frame signals go through this thread, after their draw.
    pub fn host(&self, host: Box<dyn PreviewHost>) -> Box<dyn PreviewHost> {
        Box::new(Host {
            inner: host,
            jobs: self.jobs.clone(),
        })
    }
}

impl PreviewRenderer for RenderThread {
    /// The first draw into a texture waits for its result, so a GPU that can't draw fails
    /// CreatePreview instead of a PreviewReady that is lost right after (P1-053 review); later
    /// draws are queued and return at once, a failure reaching `lost`.
    fn draw(
        &mut self,
        target: PlatformTexture,
        time: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        let mut list = self.spare.try_recv().unwrap_or_default();
        refill(&mut list, layers);
        let layers = list;
        let stopped = || DrawError::Gpu("render thread stopped".into());
        if self.drawn.contains(&target.id) {
            return self
                .jobs
                .send(Job::Draw(target, time, layers, None))
                .map_err(|_| stopped());
        }
        let (reply, result) = channel();
        self.jobs
            .send(Job::Draw(target, time, layers, Some(reply)))
            .map_err(|_| stopped())?;
        let drawn = result.recv().map_err(|_| stopped())?;
        if !matches!(drawn, Err(DrawError::Gpu(_))) {
            self.drawn.push(target.id);
        }
        drawn
    }

    /// Returns once the render thread has dropped what it kept for `target`.
    fn forget(&mut self, target: PlatformTexture) {
        self.drawn.retain(|id| *id != target.id);
        let (done, wait) = channel();
        if self.jobs.send(Job::Forget(target, done)).is_ok() {
            // An error means the thread is gone, and with it everything it kept.
            let _ = wait.recv();
        }
    }
}

impl Drop for RenderThread {
    fn drop(&mut self) {
        let _ = self.jobs.send(Job::Stop);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

struct Host {
    inner: Box<dyn PreviewHost>,
    jobs: Sender<Job>,
}

impl PreviewHost for Host {
    fn create_texture(&self, width: u32, height: u32) -> Result<(), String> {
        self.inner.create_texture(width, height)
    }

    fn frame_available(&self, id: i64) {
        let _ = self.jobs.send(Job::Signal(id));
    }

    fn release_texture(&self, texture: PlatformTexture) {
        self.inner.release_texture(texture);
    }
}

/// Copies `layers` into `list`, reusing its entries and their strings.
fn refill(list: &mut Layers, layers: &mut dyn Iterator<Item = Layer<'_>>) {
    let mut len = 0;
    for layer in layers {
        match list.get_mut(len) {
            Some((media, key)) => {
                media.clone_from(layer.media);
                *key = layer.key();
            }
            None => list.push((layer.media.clone(), layer.key())),
        }
        len += 1;
    }
    list.truncate(len);
}

/// Runs jobs until Stop. Each wake takes everything queued and skips a draw or signal that a
/// later one for the same texture replaces.
fn serve(
    mut renderer: Box<dyn PreviewRenderer>,
    inbox: &Receiver<Job>,
    recycle: &SyncSender<Layers>,
    signal: &dyn Fn(i64),
    lost: &dyn Fn(i64),
) {
    let mut gone: Vec<i64> = Vec::new();
    let mut batch: Vec<Job> = Vec::new();
    while let Ok(first) = inbox.recv() {
        batch.push(first);
        batch.extend(inbox.try_iter());
        for (i, job) in batch.iter().enumerate() {
            let later = &batch[i + 1..];
            match job {
                Job::Draw(target, time, layers, Some(reply)) => {
                    let _ = reply.send(draw(renderer.as_mut(), *target, *time, layers));
                }
                Job::Draw(target, time, layers, None) => {
                    let replaced = later
                        .iter()
                        .any(|j| matches!(j, Job::Draw(t, ..) if t.id == target.id));
                    if replaced || gone.contains(&target.id) {
                        continue;
                    }
                    if let Err(DrawError::Gpu(_)) = draw(renderer.as_mut(), *target, *time, layers)
                    {
                        gone.push(target.id);
                        lost(target.id);
                    }
                }
                Job::Signal(id) => {
                    let replaced = later.iter().any(|j| matches!(j, Job::Signal(s) if s == id));
                    if !replaced && !gone.contains(id) {
                        signal(*id);
                    }
                }
                Job::Forget(target, done) => {
                    let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                        renderer.forget(*target)
                    }));
                    gone.retain(|id| *id != target.id);
                    let _ = done.send(());
                }
                Job::Stop => return,
            }
        }
        for job in batch.drain(..) {
            if let Job::Draw(_, _, layers, _) = job {
                // Full (or the engine side gone): the list is simply dropped.
                let _ = recycle.try_send(layers);
            }
        }
    }
}

/// Draws one job; a panic counts as a GPU failure (the target is lost).
fn draw(
    renderer: &mut dyn PreviewRenderer,
    target: PlatformTexture,
    time: Time,
    layers: &[(Media, LayerKey)],
) -> Result<(), DrawError> {
    let mut layers = layers.iter().map(|(media, key)| Layer {
        media_id: key.media,
        media,
        source_time: key.source_time,
        transform: key.transform,
        canvas: key.canvas,
        proxy_side: key.proxy_side,
    });
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        renderer.draw(target, time, &mut layers)
    }))
    .unwrap_or_else(|_| Err(DrawError::Gpu("draw panicked".into())))
}
