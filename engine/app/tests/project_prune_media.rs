//! ENG-054: a save lists only the media some clip uses, so media left behind by deleted
//! clips neither grows the file nor hits the media cap; the undo history keeps them in memory.
use framix_app::history::History;
use framix_app::project::{MAX_CLIPS, decode, encode_for_save};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::timeline::{MediaId, Timeline};

fn photo(uri: &str) -> Media {
    Media::validate(RawMedia {
        uri: uri.into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 4,
        height: 3,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

fn saved_media(tl: &Timeline) -> Vec<MediaId> {
    let bytes = encode_for_save(tl).unwrap();
    decode(&bytes)
        .unwrap()
        .all_media()
        .map(|(id, _)| id)
        .collect()
}

#[test]
fn media_without_clips_are_not_saved() {
    let mut tl = Timeline::default();
    let clips = tl
        .import(vec![photo("media/a.jpg"), photo("media/b.jpg")])
        .unwrap();
    let kept = tl.clip(clips[1]).unwrap().media;
    tl.remove_clip(clips[0]).unwrap();
    assert_eq!(saved_media(&tl), vec![kept]);
}

#[test]
fn more_unused_media_than_the_cap_still_save() {
    let mut tl = Timeline::default();
    for id in 1..=MAX_CLIPS as u64 + 1 {
        tl.restore_media(MediaId(id), photo("media/p.jpg"));
    }
    let clips = tl.import(vec![photo("media/q.jpg")]).unwrap();
    tl.remove_clip(clips[0]).unwrap();
    assert_eq!(saved_media(&tl), Vec::new());
}

#[test]
fn undo_after_a_pruned_save_brings_the_clip_and_its_media_back() {
    let mut h = History::new(Timeline::default());
    let clips = h.apply(|tl| tl.import(vec![photo("media/a.jpg")])).unwrap();
    let media = h.timeline().clip(clips[0]).unwrap().media;
    h.apply(|tl| tl.remove_clip(clips[0])).unwrap();
    assert_eq!(saved_media(h.timeline()), Vec::new());
    assert!(h.undo());
    assert_eq!(h.timeline().clip(clips[0]).unwrap().media, media);
    assert_eq!(saved_media(h.timeline()), vec![media]);
    let reopened = decode(&encode_for_save(h.timeline()).unwrap()).unwrap();
    assert_eq!(reopened.tracks()[0].clips().len(), 1);
}
