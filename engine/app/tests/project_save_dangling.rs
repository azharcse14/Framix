//! P1-011 review: the engine must not save a format-2 file that open would refuse.
use framix_app::project::{ProjectError, encode_for_save};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TrackKind};

#[test]
fn clips_with_unregistered_media_cannot_be_saved() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let clip = ClipPlacement {
        media: MediaId(42),
        source_start: Time(0),
        start: Time(0),
        duration: Time(10),
    };
    tl.insert_clip(t, clip).unwrap();
    assert!(matches!(
        encode_for_save(&tl),
        Err(ProjectError::UnknownMedia(42))
    ));
}
