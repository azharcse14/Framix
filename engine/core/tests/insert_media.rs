//! ENG-059: the timeline itself refuses a clip on media it has not registered, so no caller
//! (engine command, project load, test) can build a project that saves as UnknownMedia.
use framix_core::media::Media;
use framix_core::time::Time;
use framix_core::timeline::{
    ClipPlacement, ClipTransform, MediaId, Timeline, TimelineError, TrackKind,
};

fn place(media: u64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(media),
        source_start: Time(0),
        start: Time(0),
        duration: Time(10),
    }
}

#[test]
fn a_clip_on_unregistered_media_is_refused_and_nothing_changes() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let before = tl.clone();
    assert_eq!(
        tl.insert_clip(t, place(42)),
        Err(TimelineError::UnknownMedia(MediaId(42)))
    );
    assert_eq!(
        tl.insert_clip_with(t, place(42), ClipTransform::default()),
        Err(TimelineError::UnknownMedia(MediaId(42)))
    );
    assert_eq!(tl, before);
}

#[test]
fn a_clip_on_registered_media_is_placed() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    tl.restore_media(MediaId(42), Media::missing(Time(10)).unwrap());
    let clip = tl.insert_clip(t, place(42)).unwrap();
    assert_eq!(tl.clip(clip).map(|c| c.media), Some(MediaId(42)));
}
