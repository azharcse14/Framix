//! P1-011 review: the engine must not save a format-2 file that open would refuse. Since
//! ENG-059 the timeline itself refuses a clip on unregistered media, so one can never be saved.
use framix_app::project::{decode, encode_for_save};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};

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
    assert_eq!(
        tl.insert_clip(t, clip),
        Err(TimelineError::UnknownMedia(MediaId(42)))
    );
    let bytes = encode_for_save(&tl).unwrap();
    assert_eq!(decode(&bytes).unwrap(), tl);
}
