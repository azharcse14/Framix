//! P1-053: the preview draws on its own thread. Draws (and their decodes) leave the engine
//! thread, a burst of draws for one texture draws only the latest, Flutter hears of a frame
//! only after it is drawn, a GPU loss comes back through `lost`, and `forget` returns only
//! once the render thread let go of the texture.

use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};
use std::thread::ThreadId;
use std::time::Duration;

use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::render_thread::RenderThread;
use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipTransform, Layer};

const TEXTURE: PlatformTexture = PlatformTexture { id: 7, handle: 70 };
const WAIT: Duration = Duration::from_secs(5);

#[derive(Debug, Clone, PartialEq, Eq)]
enum Step {
    Draw(i64, Time, Vec<String>),
    Signal(i64),
    Forget(i64),
    Lost(i64),
}

type Log = Arc<Mutex<Vec<Step>>>;

/// Records every draw and the thread it ran on; the first draw waits for `gate`, failing draws
/// are those whose time is in `fail`.
struct Recorder {
    log: Log,
    threads: Arc<Mutex<Vec<ThreadId>>>,
    gate: Option<Receiver<()>>,
    fail: Vec<Time>,
}

impl PreviewRenderer for Recorder {
    fn draw(
        &mut self,
        target: PlatformTexture,
        time: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        if let Some(gate) = self.gate.take() {
            gate.recv_timeout(WAIT).unwrap();
        }
        self.threads
            .lock()
            .unwrap()
            .push(std::thread::current().id());
        let uris = layers.map(|l| l.media.uri().to_string()).collect();
        self.log
            .lock()
            .unwrap()
            .push(Step::Draw(target.id, time, uris));
        match self.fail.contains(&time) {
            true => Err(DrawError::Gpu("device lost".into())),
            false => Ok(()),
        }
    }

    fn forget(&mut self, target: PlatformTexture) {
        std::thread::sleep(Duration::from_millis(20));
        self.log.lock().unwrap().push(Step::Forget(target.id));
    }
}

/// The engine-side host: frame signals go through the render thread's wrapper.
struct Host {
    released: Arc<Mutex<Vec<i64>>>,
}

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {
        panic!("frame_available must be signalled by the render thread");
    }
    fn release_texture(&self, texture: PlatformTexture) {
        self.released.lock().unwrap().push(texture.id);
    }
}

struct Fixture {
    renderer: RenderThread,
    host: Box<dyn PreviewHost>,
    log: Log,
    threads: Arc<Mutex<Vec<ThreadId>>>,
    released: Arc<Mutex<Vec<i64>>>,
    gate: Sender<()>,
    lost: Receiver<i64>,
}

fn fixture(fail: Vec<Time>) -> Fixture {
    let log = Log::default();
    let threads = Arc::new(Mutex::new(Vec::new()));
    let released = Arc::new(Mutex::new(Vec::new()));
    let (gate, gate_rx) = channel();
    let (lost_tx, lost) = channel();
    let recorder = Recorder {
        log: log.clone(),
        threads: threads.clone(),
        gate: Some(gate_rx),
        fail,
    };
    let signals = log.clone();
    let losses = log.clone();
    let renderer = RenderThread::spawn(
        move || Box::new(recorder) as Box<dyn PreviewRenderer>,
        move |id| signals.lock().unwrap().push(Step::Signal(id)),
        move |id| {
            losses.lock().unwrap().push(Step::Lost(id));
            lost_tx.send(id).unwrap();
        },
    )
    .unwrap();
    let host = renderer.host(Box::new(Host {
        released: released.clone(),
    }));
    Fixture {
        renderer,
        host,
        log,
        threads,
        released,
        gate,
        lost,
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

/// Draws `media` at `time` into the test texture, then signals it, as the engine does.
fn draw(f: &mut Fixture, time: i64, media: &Media) {
    let layer = Layer {
        media_id: framix_core::timeline::MediaId(1),
        media,
        source_time: Time(time),
        transform: ClipTransform::default(),
        canvas: AspectRatio::default(),
        proxy_side: None,
    };
    f.renderer
        .draw(TEXTURE, Time(time), &mut std::iter::once(layer))
        .unwrap();
    f.host.frame_available(TEXTURE.id);
}

/// Waits until the render thread has handled everything queued so far.
fn settle(f: &mut Fixture) {
    f.renderer.forget(PlatformTexture { id: -1, handle: 0 });
}

fn steps(f: &Fixture) -> Vec<Step> {
    let mut log = f.log.lock().unwrap().clone();
    log.retain(|s| *s != Step::Forget(-1));
    log
}

#[test]
fn draws_run_on_the_render_thread_and_signal_after_the_draw() {
    let mut f = fixture(vec![]);
    f.gate.send(()).unwrap();
    draw(&mut f, 1, &media("a"));
    settle(&mut f);
    assert_eq!(
        steps(&f),
        vec![
            Step::Draw(7, Time(1), vec!["media/a.mp4".into()]),
            Step::Signal(7),
        ]
    );
    let threads = f.threads.lock().unwrap();
    assert_eq!(threads.len(), 1);
    assert_ne!(threads[0], std::thread::current().id());
}

#[test]
fn draws_queued_behind_a_slow_draw_draw_only_the_latest() {
    let mut f = fixture(vec![]);
    let m = media("a");
    draw(&mut f, 1, &m);
    // Let the first draw start and block on the gate before the burst.
    std::thread::sleep(Duration::from_millis(50));
    for time in 2..=5 {
        draw(&mut f, time, &m);
    }
    f.gate.send(()).unwrap();
    settle(&mut f);
    let draws: Vec<Time> = steps(&f)
        .into_iter()
        .filter_map(|s| match s {
            Step::Draw(_, t, _) => Some(t),
            _ => None,
        })
        .collect();
    assert_eq!(draws, vec![Time(1), Time(5)]);
    assert_eq!(steps(&f).last(), Some(&Step::Signal(7)));
}

#[test]
fn a_gpu_loss_is_reported_once_and_the_lost_texture_is_not_drawn_again() {
    let mut f = fixture(vec![Time(1)]);
    f.gate.send(()).unwrap();
    let m = media("a");
    draw(&mut f, 1, &m);
    assert_eq!(f.lost.recv_timeout(WAIT), Ok(7));
    draw(&mut f, 2, &m);
    settle(&mut f);
    assert_eq!(
        steps(&f),
        vec![Step::Draw(7, Time(1), vec!["media/a.mp4".into()]), Step::Lost(7)]
    );
    assert!(f.lost.try_recv().is_err(), "reported once");
}

#[test]
fn forget_returns_after_the_render_thread_let_go_and_release_goes_to_the_host() {
    let mut f = fixture(vec![]);
    f.gate.send(()).unwrap();
    draw(&mut f, 1, &media("a"));
    f.renderer.forget(TEXTURE);
    assert_eq!(steps(&f).last(), Some(&Step::Forget(7)));
    f.host.release_texture(TEXTURE);
    assert_eq!(*f.released.lock().unwrap(), vec![7]);
}

#[test]
fn dropping_the_render_thread_stops_it() {
    let f = fixture(vec![]);
    f.gate.send(()).unwrap();
    let Fixture { renderer, host, .. } = f;
    drop(host);
    drop(renderer);
}
