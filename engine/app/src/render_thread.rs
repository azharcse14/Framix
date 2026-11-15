//! The preview's render thread (P1-053): draws, and the decodes under them, leave the engine
//! thread. The engine queues a draw and goes on; a burst of draws for one texture (a scrub)
//! draws only the latest; Flutter hears of a frame only once it is drawn.

use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread::JoinHandle;

use framix_core::media::Media;
use framix_core::time::Time;
use framix_core::timeline::{Layer, LayerKey};

use crate::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};

enum Job {
    Draw(PlatformTexture, Time, Vec<(Media, LayerKey)>),
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
    thread: Option<JoinHandle<()>>,
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
        let thread = std::thread::Builder::new()
            .name("framix-render".into())
            .spawn(move || serve(make(), &inbox, &signal, &lost))?;
        Ok(Self {
            jobs,
            thread: Some(thread),
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
    /// Queues the draw and returns at once.
    fn draw(
        &mut self,
        target: PlatformTexture,
        time: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        // ponytail: one Vec and a Media clone per draw (~30/s while playing); pool them if a
        // profile shows it.
        let layers = layers.map(|l| (l.media.clone(), l.key())).collect();
        self.jobs
            .send(Job::Draw(target, time, layers))
            .map_err(|_| DrawError::Gpu("render thread stopped".into()))
    }

    /// Returns once the render thread has dropped what it kept for `target`.
    fn forget(&mut self, target: PlatformTexture) {
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

/// Runs jobs until Stop. Each wake takes everything queued and skips a draw or signal that a
/// later one for the same texture replaces.
fn serve(
    mut renderer: Box<dyn PreviewRenderer>,
    inbox: &Receiver<Job>,
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
                Job::Draw(target, time, layers) => {
                    let replaced = later
                        .iter()
                        .any(|j| matches!(j, Job::Draw(t, ..) if t.id == target.id));
                    if replaced || gone.contains(&target.id) {
                        continue;
                    }
                    if draw(renderer.as_mut(), *target, *time, layers) {
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
        batch.clear();
    }
}

/// Draws one job; returns whether the target was lost (a GPU failure or a panic).
fn draw(
    renderer: &mut dyn PreviewRenderer,
    target: PlatformTexture,
    time: Time,
    layers: &[(Media, LayerKey)],
) -> bool {
    let mut layers = layers.iter().map(|(media, key)| Layer {
        media_id: key.media,
        media,
        source_time: key.source_time,
        transform: key.transform,
        canvas: key.canvas,
        proxy_side: key.proxy_side,
    });
    let drawn = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        renderer.draw(target, time, &mut layers)
    }));
    // A frame that can't be decoded shows black; the preview itself works.
    matches!(drawn, Err(_) | Ok(Err(DrawError::Gpu(_))))
}
