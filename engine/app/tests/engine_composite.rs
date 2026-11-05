//! The preview and export draw every visible video layer, bottom to top (P1-071).

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    AddTrack, Command, CreatePreview, Event, ImportMedia, InsertClip, MediaItem, MediaKind, Seek,
    SetClipTransform, SetTrackFlags, TimelineChanged, TrackKind, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Layer, LayerKey};

const SECOND: i64 = TICKS_PER_SECOND;

/// The layer keys of each draw, bottom to top.
type Draws = Arc<Mutex<Vec<Vec<LayerKey>>>>;

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
        layers: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.0
            .lock()
            .unwrap()
            .push(layers.map(|l| l.key()).collect());
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn item(i: usize) -> MediaItem {
    MediaItem {
        color: 0,
        uri: format!("media/{i}.mp4"),
        kind: MediaKind::Video as i32,
        duration_value: 4000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 0,
        codec: "avc1".into(),
    }
}

/// Clip ids of the bottom and top layer, and the top track's id.
struct Pip {
    bottom: u64,
    top: u64,
    top_track: u64,
}

/// Media 0 on the first video track and media 1 on a second one above it, both 4 s from 0,
/// the top at half size; the preview is shown at 1 s.
fn pip() -> (Engine, Draws, Pip) {
    let draws = Draws::default();
    let mut engine =
        Engine::default().with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item(0)],
        }),
    ));
    let bottom = t.tracks[0].clips[0].id;
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item(1)],
        }),
    ));
    // Import appends to the first track: move media 1 up to a track of its own.
    let second = t.tracks[0].clips[1].clone();
    let t = changed(run(
        &mut engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ));
    let top_track = t.tracks.last().unwrap().id;
    let t = changed(run(
        &mut engine,
        command::Kind::InsertClip(InsertClip {
            track_id: top_track,
            media_id: second.media_id,
            source_start: 0,
            start: 0,
            duration: 4 * SECOND,
        }),
    ));
    let top = t.tracks.last().unwrap().clips[0].id;
    changed(run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: top,
            scale: 500,
            ..SetClipTransform::default()
        }),
    ));
    run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: SECOND,
            snap_within: 0,
        }),
    );
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    (
        engine,
        draws,
        Pip {
            bottom,
            top,
            top_track,
        },
    )
}

fn last(draws: &Draws) -> Vec<LayerKey> {
    draws.lock().unwrap().last().cloned().unwrap()
}

fn count(draws: &Draws) -> usize {
    draws.lock().unwrap().len()
}

#[test]
fn the_preview_draws_both_layers_bottom_first() {
    let (_, draws, _) = pip();
    let shown = last(&draws);
    assert_eq!(shown.len(), 2, "{shown:?}");
    assert_eq!(
        shown[1].transform.scale, 500,
        "the half-size top is drawn last"
    );
}

#[test]
fn an_edit_to_the_bottom_layer_redraws() {
    let (mut engine, draws, pip) = pip();
    let before = count(&draws);
    run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: pip.bottom,
            flip_h: true,
            ..SetClipTransform::default()
        }),
    );
    assert_eq!(count(&draws), before + 1);
    assert!(last(&draws)[0].transform.flip_h);
}

#[test]
fn an_edit_under_a_covering_top_does_not_redraw() {
    let (mut engine, draws, pip) = pip();
    run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: pip.top,
            scale: 1000,
            ..SetClipTransform::default()
        }),
    );
    assert_eq!(last(&draws).len(), 1, "a full-size top covers the bottom");
    let before = count(&draws);
    run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: pip.bottom,
            flip_h: true,
            ..SetClipTransform::default()
        }),
    );
    assert_eq!(count(&draws), before, "nothing seen changed");
}

#[test]
fn hiding_the_top_track_shows_only_the_bottom() {
    let (mut engine, draws, pip) = pip();
    run(
        &mut engine,
        command::Kind::SetTrackFlags(SetTrackFlags {
            track_id: pip.top_track,
            hidden: Some(true),
            ..SetTrackFlags::default()
        }),
    );
    let shown = last(&draws);
    assert_eq!(shown.len(), 1);
    assert_eq!(shown[0].transform.scale, 1000);
}
