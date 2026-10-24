//! The preview draws the picture under the playhead (P1-060): the renderer gets the layer,
//! edits under a still playhead redraw, and a frame that can't be decoded keeps the preview.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::export::{Encoder, EncoderConfig, EncoderHost, run_export};
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, RemoveClip, Seek,
    SetClipTransform, TimelineChanged, command, event,
};
use framix_core::media::{Media, MediaKind as CoreKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Layer, LayerKey, MediaId, Timeline};

const SECOND: i64 = TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn seek(time: i64) -> command::Kind {
    command::Kind::Seek(Seek {
        time,
        snap_within: 0,
    })
}

fn item(i: usize, seconds: i64) -> MediaItem {
    MediaItem {
        uri: format!("media/{i}.mp4"),
        kind: MediaKind::Video as i32,
        duration_value: seconds * 1000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: "avc1".into(),
    }
}

/// What each draw showed: the layer's key and its media uri, or None for an empty canvas.
type Draws = Arc<Mutex<Vec<Option<(LayerKey, String)>>>>;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

struct Renderer {
    draws: Draws,
    /// Draw numbers (1-based) that fail to decode.
    undecodable: Vec<usize>,
}

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layer: Option<&Layer>,
    ) -> Result<(), DrawError> {
        let mut draws = self.draws.lock().unwrap();
        draws.push(layer.map(|l| (l.key(), l.media.uri().to_owned())));
        if self.undecodable.contains(&draws.len()) {
            return Err(DrawError::Decode("unreadable".into()));
        }
        Ok(())
    }
}

/// An engine with a shown preview and two clips (2 s, 3 s) back to back.
fn shown(undecodable: Vec<usize>) -> (Engine, Draws, TimelineChanged) {
    let draws = Draws::default();
    let mut engine = Engine::default().with_preview(
        Box::new(Host),
        Box::new(Renderer {
            draws: draws.clone(),
            undecodable,
        }),
    );
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item(0, 2), item(1, 3)],
        }),
    ));
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    (engine, draws, t)
}

fn uris(draws: &Draws) -> Vec<Option<String>> {
    draws
        .lock()
        .unwrap()
        .iter()
        .map(|d| d.as_ref().map(|(_, uri)| uri.clone()))
        .collect()
}

#[test]
fn the_renderer_gets_the_clip_under_the_playhead() {
    let (mut engine, draws, _) = shown(vec![]);
    run(&mut engine, seek(2 * SECOND + SECOND / 2));
    assert_eq!(
        uris(&draws),
        vec![Some("media/0.mp4".into()), Some("media/1.mp4".into())]
    );
    let last = draws.lock().unwrap().last().cloned().flatten().unwrap().0;
    assert_eq!(last.source_time, Time(SECOND / 2), "half a second into the second clip");
}

#[test]
fn an_edit_under_a_still_playhead_redraws_once() {
    let (mut engine, draws, t) = shown(vec![]);
    run(&mut engine, seek(SECOND));
    let first = t.tracks[0].clips[0].id;
    let before = draws.lock().unwrap().len();

    run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: first,
            flip_h: true,
            ..SetClipTransform::default()
        }),
    );
    assert_eq!(draws.lock().unwrap().len(), before + 1, "the flip shows at once");
    let last = draws.lock().unwrap().last().cloned().flatten().unwrap().0;
    assert!(last.transform.flip_h);

    run(&mut engine, command::Kind::GetTimeline(Default::default()));
    let second = t.tracks[0].clips[1].id;
    run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip { clip_id: second }),
    );
    assert_eq!(
        draws.lock().unwrap().len(),
        before + 1,
        "reads and edits elsewhere leave the picture alone"
    );
}

#[test]
fn removing_the_clip_under_the_playhead_clears_the_canvas() {
    let (mut engine, draws, t) = shown(vec![]);
    run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: t.tracks[0].clips[0].id,
        }),
    );
    // Removal leaves a gap: the playhead at 0 now shows nothing.
    assert_eq!(uris(&draws), vec![Some("media/0.mp4".into()), None]);
}

#[test]
fn a_frame_that_cannot_be_decoded_keeps_the_preview() {
    // The first frame (at 0) fails to decode.
    let (mut engine, draws, _) = shown(vec![1]);
    run(&mut engine, seek(SECOND));
    assert_eq!(
        draws.lock().unwrap().len(),
        2,
        "the next seek still draws: a missing file is not a dead GPU"
    );
}

// Export draws the same layers, and a frame it cannot decode fails the export.

#[derive(Default, Clone)]
struct Seen(Arc<Mutex<Vec<Option<MediaId>>>>);

struct ExportRenderer {
    seen: Seen,
    fail: bool,
}

impl PreviewRenderer for ExportRenderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        layer: Option<&Layer>,
    ) -> Result<(), DrawError> {
        self.seen.0.lock().unwrap().push(layer.map(|l| l.media_id));
        if self.fail {
            return Err(DrawError::Decode("unreadable".into()));
        }
        Ok(())
    }
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

fn one_clip_timeline() -> Timeline {
    let video = Media::validate(RawMedia {
        uri: "media/v.mp4".into(),
        kind: CoreKind::Video,
        duration_value: 1000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    let mut tl = Timeline::default();
    tl.import(vec![video]).unwrap();
    tl
}

#[test]
fn export_draws_the_clip_in_every_frame() {
    let seen = Seen::default();
    let tl = one_clip_timeline();
    let mut renderer = ExportRenderer {
        seen: seen.clone(),
        fail: false,
    };
    run_export(&tl, &mut renderer, &NullHost, "/out.mp4").unwrap();
    let seen = seen.0.lock().unwrap();
    assert!(!seen.is_empty());
    assert!(seen.iter().all(|m| m.is_some()), "the clip covers the whole export");
}

#[test]
fn export_fails_when_a_frame_cannot_be_decoded() {
    let tl = one_clip_timeline();
    let mut renderer = ExportRenderer {
        seen: Seen::default(),
        fail: true,
    };
    let err = run_export(&tl, &mut renderer, &NullHost, "/out.mp4").unwrap_err();
    assert!(err.contains("unreadable"), "{err}");
}
