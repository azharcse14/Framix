use framix_core::time::Time;
use framix_core::timeline::{
    ClipPlacement, MediaId, Timeline, TimelineError, TrackFlags, TrackKind,
};

fn place(start: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(10),
    }
}

const LOCKED: TrackFlags = TrackFlags {
    muted: false,
    hidden: false,
    locked: true,
};

#[test]
fn flags_start_off_and_can_be_set() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    assert_eq!(tl.track(t).unwrap().flags(), TrackFlags::default());
    let all = TrackFlags {
        muted: true,
        hidden: true,
        locked: true,
    };
    tl.set_track_flags(t, all).unwrap();
    assert_eq!(tl.track(t).unwrap().flags(), all);
    let before = tl.clone();
    tl.set_track_flags(t, TrackFlags::default()).unwrap();
    assert_ne!(tl, before, "flags are part of timeline equality (undo)");
}

#[test]
fn a_locked_track_refuses_every_clip_edit() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(t, place(0)).unwrap();
    let b = tl.insert_clip(t, place(20)).unwrap();
    tl.set_track_flags(t, LOCKED).unwrap();
    let locked = Err(TimelineError::TrackLocked(t));
    assert_eq!(tl.insert_clip(t, place(40)).map(drop), locked);
    assert_eq!(tl.remove_clip(a), locked);
    assert_eq!(tl.split_clip(a, Time(5)).map(drop), locked);
    assert_eq!(tl.merge_clips(a, b), locked);
    assert_eq!(tl.trim_clip(a, Time(0), Time(5)), locked);
    assert_eq!(tl.duplicate_clip(b).map(drop), locked);
    assert_eq!(tl.track(t).unwrap().clips().len(), 2);
    tl.set_track_flags(t, TrackFlags::default()).unwrap();
    tl.remove_clip(a).unwrap();
}

#[test]
fn audio_tracks_cannot_be_hidden_and_unknown_tracks_fail() {
    let mut tl = Timeline::default();
    let audio = tl.add_track(TrackKind::Audio);
    let hidden = TrackFlags {
        hidden: true,
        ..TrackFlags::default()
    };
    assert_eq!(
        tl.set_track_flags(audio, hidden),
        Err(TimelineError::NotVisual(audio))
    );
    let muted = TrackFlags {
        muted: true,
        ..TrackFlags::default()
    };
    tl.set_track_flags(audio, muted).unwrap();
    let other = framix_core::timeline::TrackId(999);
    assert_eq!(
        tl.set_track_flags(other, muted),
        Err(TimelineError::UnknownTrack(other))
    );
}
