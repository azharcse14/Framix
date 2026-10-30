//! Preview proxies (P1-039, docs/adr/0007-proxy-media.md): big videos get a smaller copy made in
//! the background; the preview draws from it once it is ready, export never does.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, ImportMedia, MediaItem, MediaKind, NewProject, OpenProject,
    SaveProject, Undo, command,
};
use framix_app::proxy::{ProxyHost, ProxyRequest};
use framix_app::store::ProjectStore;
use framix_core::time::Time;
use framix_core::timeline::Layer;

type Requests = Arc<Mutex<Vec<ProxyRequest>>>;

struct Proxies(Requests);

impl ProxyHost for Proxies {
    fn request(&self, request: ProxyRequest) -> Result<(), String> {
        self.0.lock().unwrap().push(request);
        Ok(())
    }
}

struct Refusing;

impl ProxyHost for Refusing {
    fn request(&self, _: ProxyRequest) -> Result<(), String> {
        Err("no platform".into())
    }
}

/// Each draw's (uri, proxy side), or None for an empty canvas.
type Draws = Arc<Mutex<Vec<Option<(String, Option<u32>)>>>>;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

struct Renderer(Draws);

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layer: Option<&Layer>,
    ) -> Result<(), DrawError> {
        let seen = layer.map(|l| (l.media.uri().to_owned(), l.proxy_side));
        self.0.lock().unwrap().push(seen);
        Ok(())
    }
}

#[derive(Clone, Default)]
struct MemStore(Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>);

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.0.lock().unwrap().insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let files = self.0.lock().unwrap();
        files
            .get(path)
            .cloned()
            .ok_or_else(|| io::ErrorKind::NotFound.into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) {
    engine.handle(Command { kind: Some(kind) });
}

fn video(uri: &str, width: u32, height: u32) -> MediaItem {
    MediaItem {
        uri: uri.into(),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width,
        height,
        rotation: 0,
        codec: "hvc1".into(),
    }
}

fn import(engine: &mut Engine, items: Vec<MediaItem>) {
    run(engine, command::Kind::ImportMedia(ImportMedia { items }));
}

fn setup() -> (Engine, Requests, Draws) {
    let requests = Requests::default();
    let draws = Draws::default();
    let mut engine = Engine::with_store(Box::new(MemStore::default()))
        .with_proxies(Box::new(Proxies(requests.clone())))
        .with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    (engine, requests, draws)
}

fn asked(requests: &Requests) -> Vec<(String, u32)> {
    let requests = requests.lock().unwrap();
    requests
        .iter()
        .map(|r| (r.uri.clone(), r.key.max_side))
        .collect()
}

fn last_draw(draws: &Draws) -> Option<(String, Option<u32>)> {
    draws.lock().unwrap().last().cloned().flatten()
}

#[test]
fn only_videos_over_1080p_get_a_proxy_with_their_size() {
    let (mut engine, requests, _) = setup();
    import(
        &mut engine,
        vec![
            video("media/hd.mp4", 1920, 1080),
            video("media/uhd.mov", 3840, 2160),
        ],
    );
    assert_eq!(asked(&requests), vec![("media/uhd.mov".into(), 1920)]);
}

#[test]
fn one_proxy_is_made_at_a_time() {
    let (mut engine, requests, _) = setup();
    import(
        &mut engine,
        vec![
            video("media/a.mov", 3840, 2160),
            video("media/b.mov", 2560, 1440),
        ],
    );
    assert_eq!(asked(&requests), vec![("media/a.mov".into(), 1920)]);
    let first = requests.lock().unwrap()[0].key;
    engine.proxy_ready(first, Err("disk full".into()));
    assert_eq!(
        asked(&requests),
        vec![("media/a.mov".into(), 1920), ("media/b.mov".into(), 1280)],
        "a failure starts the next one too"
    );
}

#[test]
fn the_preview_switches_to_the_proxy_once_it_is_ready() {
    let (mut engine, requests, draws) = setup();
    import(&mut engine, vec![video("media/uhd.mov", 3840, 2160)]);
    assert_eq!(last_draw(&draws), Some(("media/uhd.mov".into(), None)));
    let draws_before = draws.lock().unwrap().len();
    let key = requests.lock().unwrap()[0].key;
    engine.proxy_ready(key, Ok(()));
    assert_eq!(
        draws.lock().unwrap().len(),
        draws_before + 1,
        "redrawn once"
    );
    assert_eq!(
        last_draw(&draws),
        Some(("media/uhd.mov".into(), Some(1920)))
    );
}

#[test]
fn a_failed_proxy_keeps_the_original() {
    let (mut engine, requests, draws) = setup();
    import(&mut engine, vec![video("media/uhd.mov", 3840, 2160)]);
    let key = requests.lock().unwrap()[0].key;
    engine.proxy_ready(key, Err("unreadable".into()));
    assert_eq!(last_draw(&draws), Some(("media/uhd.mov".into(), None)));
}

#[test]
fn an_answer_for_an_earlier_project_is_ignored() {
    let (mut engine, requests, draws) = setup();
    import(&mut engine, vec![video("media/a.mov", 3840, 2160)]);
    let old = requests.lock().unwrap()[0].key;
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    // Media ids restart, so the new project's first media has the same id.
    import(&mut engine, vec![video("media/b.mov", 3840, 2160)]);
    engine.proxy_ready(old, Ok(()));
    assert_eq!(last_draw(&draws), Some(("media/b.mov".into(), None)));
}

#[test]
fn opening_a_project_asks_for_its_proxies_again() {
    let (mut engine, requests, _) = setup();
    import(&mut engine, vec![video("media/a.mov", 3840, 2160)]);
    run(
        &mut engine,
        command::Kind::SaveProject(SaveProject { path: "p".into() }),
    );
    run(
        &mut engine,
        command::Kind::OpenProject(OpenProject { path: "p".into() }),
    );
    assert_eq!(
        asked(&requests),
        vec![("media/a.mov".into(), 1920), ("media/a.mov".into(), 1920)],
        "the platform reuses a proxy file it already has"
    );
}

#[test]
fn undo_and_redo_do_not_ask_twice() {
    let (mut engine, requests, _) = setup();
    import(&mut engine, vec![video("media/a.mov", 3840, 2160)]);
    run(&mut engine, command::Kind::Undo(Undo {}));
    run(&mut engine, command::Kind::Redo(framix_app::proto::Redo {}));
    assert_eq!(asked(&requests).len(), 1);
}

#[test]
fn a_refusing_platform_leaves_the_preview_on_the_original() {
    let draws = Draws::default();
    let mut engine = Engine::default()
        .with_proxies(Box::new(Refusing))
        .with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    import(&mut engine, vec![video("media/a.mov", 3840, 2160)]);
    assert_eq!(last_draw(&draws), Some(("media/a.mov".into(), None)));
}

struct NullEncoder;

impl Encoder for NullEncoder {
    fn frame(&mut self, _: Time) -> Result<PlatformTexture, String> {
        Ok(PlatformTexture { id: 1, handle: 1 })
    }
    fn finish(self: Box<Self>, _: bool) -> Result<(), String> {
        Ok(())
    }
}

struct NullHost;

impl EncoderHost for NullHost {
    fn open(&self, _: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        Ok(Box::new(NullEncoder))
    }
}

#[test]
fn export_reads_the_original_even_with_a_ready_proxy() {
    let (mut engine, requests, _) = setup();
    let mut engine_with_export = std::mem::take(&mut engine).with_export();
    import(
        &mut engine_with_export,
        vec![video("media/a.mov", 3840, 2160)],
    );
    let key = requests.lock().unwrap()[0].key;
    engine_with_export.proxy_ready(key, Ok(()));
    run(
        &mut engine_with_export,
        command::Kind::ExportProject(framix_app::proto::ExportProject {
            path: "out.mp4".into(),
        }),
    );
    let job = engine_with_export
        .take_export_job()
        .expect("export accepted");
    let draws = Draws::default();
    run_export(
        &job.timeline,
        &mut Renderer(draws.clone()),
        &NullHost,
        &job.path,
    )
    .unwrap();
    let draws = draws.lock().unwrap();
    assert!(!draws.is_empty());
    assert!(
        draws
            .iter()
            .all(|d| d.as_ref().is_some_and(|(_, side)| side.is_none()))
    );
}
