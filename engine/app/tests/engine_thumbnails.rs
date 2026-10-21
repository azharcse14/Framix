//! Thumbnails (P1-021): the engine snaps and dedups requests, keeps at most two in flight, and
//! reports each made file once.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, RequestThumbnails, TimelineChanged, command,
    event,
};
use framix_app::thumbnail::{ThumbnailHost, ThumbnailKey, ThumbnailRequest};
use framix_core::media::MediaKind as CoreKind;
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::MediaId;

const SECOND: i64 = TICKS_PER_SECOND;

type Requests = Arc<Mutex<Vec<ThumbnailRequest>>>;

struct Host(Requests);

impl ThumbnailHost for Host {
    fn request(&self, request: ThumbnailRequest) -> Result<(), String> {
        self.0.lock().unwrap().push(request);
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn item(uri: &str, kind: MediaKind, ms: i64) -> MediaItem {
    MediaItem {
        uri: uri.into(),
        kind: kind as i32,
        duration_value: ms,
        duration_timescale: if ms > 0 { 1000 } else { 0 },
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: String::new(),
    }
}

/// An engine with one 4 s video and one photo; returns it, the requests log, and the media ids.
fn setup() -> (Engine, Requests, u64, u64) {
    let requests = Requests::default();
    let mut engine = Engine::default().with_thumbnails(Box::new(Host(requests.clone())));
    let t = match run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![
                item("content://media/external/video/1", MediaKind::Video, 4000),
                item("content://media/external/images/2", MediaKind::Image, 0),
            ],
        }),
    )
    .kind
    {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("{other:?}"),
    };
    let clips = &t.tracks[0].clips;
    (engine, requests, clips[0].media_id, clips[1].media_id)
}

fn ask(engine: &mut Engine, media_id: u64, times: &[i64], max_side: u32) -> Event {
    run(
        engine,
        command::Kind::RequestThumbnails(RequestThumbnails {
            media_id,
            times: times.to_vec(),
            max_side,
        }),
    )
}

fn accepted(e: &Event) -> bool {
    matches!(e.kind, Some(event::Kind::CommandAccepted(_)))
}

fn failed(e: &Event) -> bool {
    matches!(e.kind, Some(event::Kind::CommandFailed(_)))
}

fn times(requests: &Requests) -> Vec<i64> {
    requests
        .lock()
        .unwrap()
        .iter()
        .map(|r| r.key.time.0)
        .collect()
}

#[test]
fn times_snap_to_the_step_and_stay_inside_the_media() {
    let (mut engine, requests, video, _) = setup();
    assert!(accepted(&ask(
        &mut engine,
        video,
        &[SECOND + 5, 99 * SECOND],
        128
    )));
    // 1.0000001 s -> 1 s; 99 s -> the last step inside a 4 s video, 3 s.
    assert_eq!(times(&requests), vec![SECOND, 3 * SECOND]);
    let r = &requests.lock().unwrap()[0];
    assert_eq!(r.uri, "content://media/external/video/1");
    assert_eq!(r.kind, CoreKind::Video);
    assert_eq!(r.time_us, 1_000_000);
    assert_eq!(r.key.max_side, 128);
}

#[test]
fn photos_always_use_time_zero() {
    let (mut engine, requests, _, photo) = setup();
    assert!(accepted(&ask(&mut engine, photo, &[0, 2 * SECOND], 128)));
    assert_eq!(
        times(&requests),
        vec![0],
        "one thumbnail for the whole photo"
    );
}

#[test]
fn at_most_two_run_at_once_and_answers_start_the_next() {
    let (mut engine, requests, video, _) = setup();
    ask(
        &mut engine,
        video,
        &[0, SECOND, 2 * SECOND, 3 * SECOND],
        128,
    );
    assert_eq!(times(&requests), vec![0, SECOND], "two in flight");

    let key = |t: i64| ThumbnailKey {
        media: MediaId(video),
        time: Time(t),
        max_side: 128,
    };
    let ready = engine.thumbnail_ready(key(0), Ok("/cache/thumbs/a.jpg".into()));
    match ready.and_then(|e| e.kind) {
        Some(event::Kind::ThumbnailReady(r)) => {
            assert_eq!((r.media_id, r.time, r.max_side), (video, 0, 128));
            assert_eq!(r.path, "/cache/thumbs/a.jpg");
        }
        other => panic!("expected ThumbnailReady, got {other:?}"),
    }
    assert_eq!(
        times(&requests),
        vec![0, SECOND, 2 * SECOND],
        "next one started"
    );

    let failed = engine.thumbnail_ready(key(SECOND), Err("decode failed".into()));
    assert!(failed.is_none(), "a failure sends nothing");
    assert_eq!(times(&requests), vec![0, SECOND, 2 * SECOND, 3 * SECOND]);
}

#[test]
fn a_time_already_asked_for_is_not_made_again() {
    let (mut engine, requests, video, _) = setup();
    ask(&mut engine, video, &[0], 128);
    let key = ThumbnailKey {
        media: MediaId(video),
        time: Time(0),
        max_side: 128,
    };
    engine.thumbnail_ready(key, Ok("/a.jpg".into()));
    ask(&mut engine, video, &[0, 10], 128);
    assert_eq!(
        times(&requests),
        vec![0],
        "ready, and 10 ticks snaps to the same key"
    );
    ask(&mut engine, video, &[0], 256);
    assert_eq!(
        times(&requests),
        vec![0, 0],
        "another size is another thumbnail"
    );
}

#[test]
fn answers_for_keys_never_asked_for_are_ignored() {
    let (mut engine, _, video, _) = setup();
    let stray = ThumbnailKey {
        media: MediaId(video),
        time: Time(0),
        max_side: 128,
    };
    assert!(engine.thumbnail_ready(stray, Ok("/a.jpg".into())).is_none());
}

#[test]
fn bad_requests_fail() {
    let (mut engine, _, video, _) = setup();
    assert!(failed(&ask(&mut engine, 999, &[0], 128)), "unknown media");
    assert!(failed(&ask(&mut engine, video, &[0], 16)), "too small");
    assert!(failed(&ask(&mut engine, video, &[0], 1024)), "too big");
    let many: Vec<i64> = (0..65).collect();
    assert!(
        failed(&ask(&mut engine, video, &many, 128)),
        "too many times"
    );
    let mut no_host = Engine::default();
    assert!(failed(&ask(&mut no_host, video, &[0], 128)), "no platform");
}

#[test]
fn timeline_reports_the_thumbnail_step() {
    let (mut engine, _, _, _) = setup();
    let t: TimelineChanged =
        match run(&mut engine, command::Kind::GetTimeline(Default::default())).kind {
            Some(event::Kind::TimelineChanged(t)) => t,
            other => panic!("{other:?}"),
        };
    assert_eq!(t.thumbnail_step, SECOND);
}
