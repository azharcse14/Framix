use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackFlags, TrackId, TrackKind,
};

fn place(start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(5),
        start: Time(start),
        duration: Time(duration),
    }
}

/// (id, start) of each clip on `t`.
fn starts(tl: &Timeline, t: TrackId) -> Vec<(ClipId, i64)> {
    tl.track(t)
        .unwrap()
        .clips()
        .iter()
        .map(|c| (c.id, c.start.0))
        .collect()
}

#[test]
fn moving_within_a_track_keeps_order_sorted() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(t, place(0, 10)).unwrap();
    let b = tl.insert_clip(t, place(20, 10)).unwrap();
    tl.move_clip(a, t, Time(40)).unwrap();
    assert_eq!(starts(&tl, t), [(b, 20), (a, 40)]);
    let moved = tl.track(t).unwrap().clips()[1];
    assert_eq!(
        (moved.source_start.0, moved.duration.0),
        (5, 10),
        "content unchanged"
    );
    // Sliding a clip so it overlaps only its old position is fine.
    tl.move_clip(a, t, Time(35)).unwrap();
    assert_eq!(starts(&tl, t), [(b, 20), (a, 35)]);
}

#[test]
fn moving_to_another_track_of_the_same_kind() {
    let mut tl = Timeline::default();
    let v1 = tl.add_track(TrackKind::Video);
    let v2 = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(v1, place(0, 10)).unwrap();
    tl.move_clip(a, v2, Time(100)).unwrap();
    assert!(starts(&tl, v1).is_empty());
    assert_eq!(starts(&tl, v2), [(a, 100)]);
}

#[test]
fn bad_moves_are_refused_and_change_nothing() {
    let mut tl = Timeline::default();
    let v1 = tl.add_track(TrackKind::Video);
    let v2 = tl.add_track(TrackKind::Video);
    let audio = tl.add_track(TrackKind::Audio);
    let a = tl.insert_clip(v1, place(0, 10)).unwrap();
    let b = tl.insert_clip(v1, place(20, 10)).unwrap();
    let before = tl.clone();

    assert_eq!(
        tl.move_clip(a, v1, Time(15)),
        Err(TimelineError::Overlap(b))
    );
    assert_eq!(
        tl.move_clip(a, audio, Time(0)),
        Err(TimelineError::WrongTrackKind(audio))
    );
    assert_eq!(
        tl.move_clip(a, v1, Time(-1)),
        Err(TimelineError::NegativeTime)
    );
    assert_eq!(
        tl.move_clip(a, v1, Time(i64::MAX - 5)),
        Err(TimelineError::TimeOverflow)
    );
    assert_eq!(
        tl.move_clip(ClipId(999), v1, Time(0)),
        Err(TimelineError::UnknownClip(ClipId(999)))
    );
    assert_eq!(
        tl.move_clip(a, TrackId(999), Time(0)),
        Err(TimelineError::UnknownTrack(TrackId(999)))
    );

    let locked = TrackFlags {
        locked: true,
        ..TrackFlags::default()
    };
    tl.set_track_flags(v2, locked).unwrap();
    assert_eq!(
        tl.move_clip(a, v2, Time(50)),
        Err(TimelineError::TrackLocked(v2))
    );
    tl.set_track_flags(v2, TrackFlags::default()).unwrap();
    tl.set_track_flags(v1, locked).unwrap();
    assert_eq!(
        tl.move_clip(a, v2, Time(50)),
        Err(TimelineError::TrackLocked(v1))
    );
    tl.set_track_flags(v1, TrackFlags::default()).unwrap();

    assert_eq!(tl, before);
}
