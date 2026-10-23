use framix_app::engine::Engine;
use framix_app::project::{FORMAT_VERSION, ProjectError, decode, encode};
use framix_app::project_proto::{ProjectFile, SavedMedia, SavedMediaKind};
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, TimelineChanged, Undo, command, event,
};
use framix_core::media::{Media, MediaKind as CoreKind, RawMedia};
use framix_core::timeline::Timeline;
use prost::Message as _;

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine.handle(Command { kind: Some(kind) }).kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn item(uri: &str, kind: MediaKind, ms: i64) -> MediaItem {
    MediaItem {
        uri: uri.into(),
        kind: kind as i32,
        duration_value: ms,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: "avc1".into(),
    }
}

fn import(items: Vec<MediaItem>) -> command::Kind {
    command::Kind::ImportMedia(ImportMedia { items })
}

#[test]
fn import_adds_clips_as_one_undo_step() {
    let mut engine = Engine::default();
    let items = vec![
        item("content://media/external/video/1", MediaKind::Video, 2000),
        item("content://media/external/images/2", MediaKind::Image, 0),
    ];
    let t = changed(run(&mut engine, import(items)));
    assert_eq!(t.tracks.len(), 1);
    assert_eq!(t.tracks[0].clips.len(), 2);
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert!(t.tracks.is_empty(), "the whole import undoes at once");
}

#[test]
fn one_bad_item_refuses_the_whole_import() {
    let mut engine = Engine::default();
    let items = vec![
        item("content://media/external/video/1", MediaKind::Video, 2000),
        item("../../etc/passwd", MediaKind::Video, 2000),
    ];
    let e = run(&mut engine, import(items));
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
    let unknown_kind = vec![item("media/a.mov", MediaKind::Unspecified, 1000)];
    let e = run(&mut engine, import(unknown_kind));
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
    let t = changed(run(
        &mut engine,
        command::Kind::GetTimeline(Default::default()),
    ));
    assert!(t.tracks.is_empty());
}

fn media(uri: &str) -> Media {
    Media::validate(RawMedia {
        uri: uri.into(),
        kind: CoreKind::Video,
        duration_value: 1500,
        duration_timescale: 1000,
        width: 1280,
        height: 720,
        rotation: 270,
        codec: "hvc1".into(),
    })
    .unwrap()
}

#[test]
fn media_round_trips_through_the_project_file() {
    let mut tl = Timeline::default();
    tl.import(vec![media("media/a1.mov")]).unwrap();
    let bytes = encode(&tl);
    let file = ProjectFile::decode(bytes.as_slice()).unwrap();
    assert_eq!(
        (file.format_version, file.min_reader_version),
        // Format 3 (P1-029) needs reader 3.
        (FORMAT_VERSION, 3)
    );
    let opened = decode(&bytes).unwrap();
    let clip = opened.tracks()[0].clips()[0];
    let m = opened
        .media(clip.media)
        .expect("clip still points at its media");
    assert_eq!(
        (m.uri(), m.size(), m.rotation(), m.codec()),
        ("media/a1.mov", (1280, 720), 270, "hvc1")
    );
}

#[test]
fn tampered_media_in_a_file_is_refused() {
    let bytes = ProjectFile {
        format_version: 2,
        min_reader_version: 2,
        media: vec![SavedMedia {
            id: 1,
            uri: "/private/var/secret.mov".into(),
            kind: SavedMediaKind::Video as i32,
            duration: 100,
            width: 10,
            height: 10,
            rotation: 0,
            codec: String::new(),
        }],
        ..Default::default()
    }
    .encode_to_vec();
    assert!(matches!(decode(&bytes), Err(ProjectError::InvalidMedia(_))));
}

#[test]
fn v1_files_still_open_and_new_ids_avoid_their_media_ids() {
    let mut t = decode(include_bytes!("fixtures/project_v1.framix")).unwrap();
    // The v1 fixture's clips refer to media 7, 8 and 9, which the file does not list.
    let fresh = t.import(vec![media("media/new.mov")]).unwrap();
    let new_media = t.tracks()[0]
        .clips()
        .iter()
        .find(|c| c.id == fresh[0])
        .unwrap()
        .media;
    assert!(
        new_media.0 > 9,
        "new media id {new_media:?} must not collide with 7..=9"
    );
}
