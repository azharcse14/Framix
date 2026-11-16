//! ENG-055: when states leave the history, media no remaining state's clips use is
//! unregistered everywhere; undo and redo still find every clip's media.

use std::collections::BTreeSet;

use framix_app::history::History;
use framix_core::media::Media;
use framix_core::timeline::{ClipId, MediaId, Timeline, TimelineError, TrackKind};
use proptest::prelude::*;

fn registered(tl: &Timeline) -> BTreeSet<MediaId> {
    tl.all_media().map(|(id, _)| id).collect()
}

fn used(tl: &Timeline) -> BTreeSet<MediaId> {
    tl.tracks()
        .iter()
        .flat_map(|t| t.clips())
        .map(|c| c.media)
        .collect()
}

fn clips(tl: &Timeline) -> Vec<ClipId> {
    tl.tracks()
        .iter()
        .flat_map(|t| t.clips())
        .map(|c| c.id)
        .collect()
}

fn import(h: &mut History, color: u32) -> ClipId {
    h.apply(|tl| tl.import(vec![Media::solid(color)])).unwrap()[0]
}

fn add_track(h: &mut History) {
    h.apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Video)))
        .unwrap();
}

/// A history whose start registers media 5 without any clip on it.
fn with_unused_media() -> History {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(5), Media::solid(5));
    History::new(tl)
}

#[test]
fn dropping_redo_unregisters_media_no_remaining_state_uses() {
    let mut h = with_unused_media();
    add_track(&mut h);
    assert!(h.undo());
    add_track(&mut h);
    for tl in h.timelines() {
        assert_eq!(tl.media(MediaId(5)), None);
    }
}

#[test]
fn media_a_remaining_state_uses_stays_registered() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let media = h.timeline().clip(clip).unwrap().media;
    h.apply(|tl| tl.remove_clip(clip)).unwrap();
    assert!(h.undo());
    assert!(h.undo());
    assert!(h.redo());
    // Drops the delete; the import state still uses the media.
    add_track(&mut h);
    assert!(h.timeline().media(media).is_some());
    assert!(h.undo());
    assert_eq!(h.timeline().clip(clip).unwrap().media, media);
}

#[test]
fn forgotten_media_ids_are_never_reissued() {
    let mut h = with_unused_media();
    add_track(&mut h);
    assert!(h.undo());
    add_track(&mut h);
    let clip = import(&mut h, 2);
    assert!(h.timeline().clip(clip).unwrap().media.0 > 5);
}

#[derive(Clone, Debug)]
enum Op {
    Import(u32),
    Delete(usize),
    Replace(usize, u32),
    Undo,
    Redo,
}

fn op() -> impl Strategy<Value = Op> {
    prop_oneof![
        (0u32..8).prop_map(Op::Import),
        (0usize..8).prop_map(Op::Delete),
        (0usize..8, 0u32..8).prop_map(|(i, c)| Op::Replace(i, c)),
        Just(Op::Undo),
        Just(Op::Redo),
    ]
}

proptest! {
    #[test]
    fn snapshots_find_their_media_and_dropped_media_is_gone(
        ops in proptest::collection::vec(op(), 0..40)
    ) {
        let mut h = with_unused_media();
        let mut dropped = false;
        for op in ops {
            let current = clips(h.timeline());
            let pick = |i: usize| (!current.is_empty()).then(|| current[i % current.len()]);
            let had_redo = h.can_redo();
            match op {
                Op::Import(c) => {
                    import(&mut h, c);
                }
                Op::Delete(i) => {
                    if let Some(clip) = pick(i) {
                        h.apply(|tl| tl.remove_clip(clip)).unwrap();
                    }
                }
                Op::Replace(i, c) => {
                    if let Some(clip) = pick(i) {
                        h.apply(|tl| tl.replace_clip(clip, Media::solid(c))).unwrap();
                    }
                }
                Op::Undo => {
                    h.undo();
                }
                Op::Redo => {
                    h.redo();
                }
            }
            let edit = matches!(op, Op::Import(_) | Op::Delete(_) | Op::Replace(..));
            dropped |= edit && had_redo && !h.can_redo();
            for tl in h.timelines() {
                prop_assert!(used(tl).is_subset(&registered(tl)));
            }
            if dropped {
                let all_used: BTreeSet<_> = h.timelines().flat_map(used).collect();
                let all_registered: BTreeSet<_> = h.timelines().flat_map(registered).collect();
                prop_assert_eq!(all_registered, all_used);
            }
        }
    }
}
