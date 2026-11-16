//! Migrated format 1 projects (SYS-039 review): missing media is never drawn, exported or
//! thumbnailed, and only clips' unlisted media becomes missing.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewRenderer};
use framix_app::project::{ProjectError, decode};
use framix_app::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};
use framix_app::proto::{Command, OpenProject, RequestThumbnails, command, event};
use framix_app::store::ProjectStore;
use framix_app::thumbnail::{ThumbnailHost, ThumbnailRequest};
use framix_core::media::MediaError;
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Layer, MediaId, TimelineError};
use prost::Message as _;

const V1: &[u8] = include_bytes!("fixtures/project_v1.framix");
const DAY: i64 = 24 * 3600 * TICKS_PER_SECOND;

#[test]
fn a_v1_clip_has_no_layer() {
    let t = decode(V1).unwrap();
    for time in [0, 50, 120] {
        assert_eq!(t.layers_at(Time(time)).count(), 0, "at {time}");
    }
}

struct Encoding;

impl Encoder for Encoding {
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
        Ok(Box::new(Encoding))
    }
}

/// Fails like the real renderer when asked to decode a layer with no file.
struct Renderer;

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        if layers.filter(|l| l.media.uri().is_empty()).count() > 0 {
            return Err(DrawError::Gpu("no file to decode".into()));
        }
        Ok(())
    }
}

#[test]
fn a_migrated_v1_project_exports() {
    let t = decode(V1).unwrap();
    run_export(&t, &mut Renderer, &Host, "/out.mp4").unwrap();
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

type Requests = Arc<Mutex<Vec<ThumbnailRequest>>>;

struct Thumbs(Requests);

impl ThumbnailHost for Thumbs {
    fn request(&self, request: ThumbnailRequest) -> Result<(), String> {
        self.0.lock().unwrap().push(request);
        Ok(())
    }
}

#[test]
fn missing_media_gets_no_thumbnails() {
    let store = MemStore::default();
    store.save(Path::new("v1"), V1).unwrap();
    let requests = Requests::default();
    let mut engine =
        Engine::with_store(Box::new(store)).with_thumbnails(Box::new(Thumbs(requests.clone())));
    engine.handle(Command {
        id: 0,
        kind: Some(command::Kind::OpenProject(OpenProject {
            path: "v1".into(),
            ..Default::default()
        })),
    });
    let reply = engine.handle(Command {
        id: 0,
        kind: Some(command::Kind::RequestThumbnails(RequestThumbnails {
            media_id: 7,
            times: vec![0],
            max_side: 64,
        })),
    });
    assert!(
        matches!(reply.kind, Some(event::Kind::CommandFailed(_))),
        "{reply:?}"
    );
    assert!(requests.lock().unwrap().is_empty());
}

fn clip(media_id: u64, source_start: i64, start: i64, duration: i64) -> SavedClip {
    SavedClip {
        media_id,
        source_start,
        start,
        duration,
        ..Default::default()
    }
}

fn v1(media: Vec<SavedMedia>, clips: Vec<SavedClip>) -> Vec<u8> {
    ProjectFile {
        format_version: 1,
        min_reader_version: 1,
        tracks: vec![SavedTrack {
            kind: SavedTrackKind::Video as i32,
            clips,
            ..Default::default()
        }],
        media,
        ..Default::default()
    }
    .encode_to_vec()
}

#[test]
fn shared_missing_media_lasts_to_the_furthest_source_end() {
    let t = decode(&v1(vec![], vec![clip(3, 50, 0, 10), clip(3, 0, 10, 30)])).unwrap();
    let media = t.media(MediaId(3)).unwrap();
    assert!(media.is_missing());
    assert_eq!(media.duration(), Time(60));
}

#[test]
fn a_source_end_over_a_day_is_refused() {
    assert!(matches!(
        decode(&v1(vec![], vec![clip(3, 0, 0, DAY + 1)])),
        Err(ProjectError::InvalidMedia(MediaError::BadDuration))
    ));
}

#[test]
fn bad_v1_ranges_are_refused_by_the_timeline() {
    for c in [clip(3, 0, 0, 0), clip(3, 0, 0, -5), clip(3, -10, 0, 5)] {
        assert!(
            matches!(
                decode(&v1(vec![], vec![c])),
                Err(ProjectError::Invalid(
                    TimelineError::NonPositiveDuration | TimelineError::NegativeTime
                ))
            ),
            "{c:?}"
        );
    }
}

fn saved(kind: SavedMediaKind, uri: &str, duration: i64) -> SavedMedia {
    SavedMedia {
        id: 3,
        uri: uri.into(),
        kind: kind as i32,
        duration,
        width: 10,
        height: 10,
        ..Default::default()
    }
}

fn v5(media: SavedMedia) -> Vec<u8> {
    ProjectFile {
        format_version: 5,
        min_reader_version: 5,
        media: vec![media],
        ..Default::default()
    }
    .encode_to_vec()
}

#[test]
fn a_saved_missing_video_needs_a_duration() {
    assert!(matches!(
        decode(&v5(saved(SavedMediaKind::Video, "", 0))),
        Err(ProjectError::InvalidMedia(MediaError::BadDuration))
    ));
}

#[test]
fn a_saved_image_with_no_uri_is_refused() {
    assert!(matches!(
        decode(&v5(saved(SavedMediaKind::Image, "", 0))),
        Err(ProjectError::InvalidMedia(MediaError::BadUri))
    ));
}

#[test]
fn media_a_v1_file_lists_stays_as_listed() {
    let listed = saved(SavedMediaKind::Video, "media/a.mp4", TICKS_PER_SECOND);
    let t = decode(&v1(vec![listed], vec![clip(3, 0, 0, 10)])).unwrap();
    let media = t.media(MediaId(3)).unwrap();
    assert!(!media.is_missing());
    assert_eq!(media.uri(), "media/a.mp4");
}
