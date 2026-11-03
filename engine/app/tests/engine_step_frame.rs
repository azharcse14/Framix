//! StepFrame (P1-025): the playhead moves whole frames at the project's export rate.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ExportFps, ExportResolution, ImportMedia, MediaItem, MediaKind, Seek,
    SetExportSettings, StepFrame, command, event,
};
use framix_core::time::TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

/// The playhead after `kind`, which must answer PlayheadChanged.
fn playhead(engine: &mut Engine, kind: command::Kind) -> i64 {
    match run(engine, kind) {
        Some(event::Kind::PlayheadChanged(p)) => p.time,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

fn step(frames: i32) -> command::Kind {
    command::Kind::StepFrame(StepFrame { frames })
}

/// An engine holding one 2 s video.
fn with_video() -> Engine {
    let mut engine = Engine::default();
    let item = MediaItem {
        color: 0,
        uri: "content://media/external/video/1".into(),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: "avc1".into(),
    };
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items: vec![item] }),
    );
    engine
}

#[test]
fn steps_whole_frames_at_the_export_rate() {
    let mut engine = with_video();
    // The default export rate is 30 fps.
    let frame = TICKS_PER_SECOND / 30;
    assert_eq!(playhead(&mut engine, step(1)), frame);
    assert_eq!(playhead(&mut engine, step(2)), 3 * frame);
    assert_eq!(playhead(&mut engine, step(-1)), 2 * frame);

    let seek = Seek {
        time: frame + 5,
        snap_within: 0,
    };
    assert_eq!(playhead(&mut engine, command::Kind::Seek(seek)), frame + 5);
    assert_eq!(playhead(&mut engine, step(-1)), 0, "back from inside a frame");

    let settings = SetExportSettings {
        resolution: ExportResolution::ExportResolution1080p as i32,
        fps: ExportFps::ExportFps60 as i32,
        kbps: 0,
    };
    run(&mut engine, command::Kind::SetExportSettings(settings));
    assert_eq!(playhead(&mut engine, step(1)), TICKS_PER_SECOND / 60);
}

#[test]
fn steps_stay_inside_the_timeline() {
    let mut engine = with_video();
    assert_eq!(playhead(&mut engine, step(-5)), 0);
    assert_eq!(
        playhead(&mut engine, step(i32::MAX)),
        2 * TICKS_PER_SECOND,
        "clamped to the end"
    );
}
