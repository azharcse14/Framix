//! A project switch redraws the preview (P1-060 review): media ids restart in every project,
//! so another project's picture can have the same layer key as the one shown.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, ImportMedia, MediaItem, MediaKind, OpenProject, SaveProject, command,
};
use framix_app::store::ProjectStore;
use framix_core::time::Time;
use framix_core::timeline::Layer;

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

/// The media uri of each draw.
type Draws = Arc<Mutex<Vec<Option<String>>>>;

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
        let uri = layer.map(|l| l.media.uri().to_owned());
        self.0.lock().unwrap().push(uri);
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) {
    engine.handle(Command { kind: Some(kind) });
}

fn import(engine: &mut Engine, uri: &str) {
    let item = MediaItem {
        uri: uri.into(),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: "avc1".into(),
    };
    run(
        engine,
        command::Kind::ImportMedia(ImportMedia { items: vec![item] }),
    );
}

#[test]
fn opening_a_project_with_the_same_layer_key_redraws() {
    let store = MemStore::default();
    let mut other = Engine::with_store(Box::new(store.clone()));
    import(&mut other, "media/b.mp4");
    run(
        &mut other,
        command::Kind::SaveProject(SaveProject { path: "b".into() }),
    );

    let draws = Draws::default();
    let mut engine = Engine::with_store(Box::new(store))
        .with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    import(&mut engine, "media/a.mp4");
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    run(
        &mut engine,
        command::Kind::OpenProject(OpenProject { path: "b".into() }),
    );

    assert_eq!(
        draws.lock().unwrap().last().cloned().flatten().as_deref(),
        Some("media/b.mp4"),
        "the opened project's picture is shown"
    );
}
