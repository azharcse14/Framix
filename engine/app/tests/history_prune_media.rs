//! ENG-055: each history state registers only the media its own clips use, so the live
//! registry stops growing, and undo/redo still find every clip's media.

use std::collections::BTreeSet;

use framix_app::history::History;
use framix_core::media::Media;
use framix_core::timeline::{ClipId, MediaId, Timeline};
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

#[test]
fn deleting_the_last_clip_of_a_media_unregisters_it_and_undo_brings_both_back() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let media = h.timeline().clip(clip).unwrap().media;
    h.apply(|tl| tl.remove_clip(clip)).unwrap();
    assert_eq!(h.timeline().media(media), None);

    assert!(h.undo());
    assert!(h.timeline().media(media).is_some());
    assert_eq!(h.timeline().clip(clip).unwrap().media, media);
    assert!(h.redo());
    assert_eq!(h.timeline().media(media), None);
}

#[test]
fn replacing_a_clip_unregisters_the_old_media() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let old = h.timeline().clip(clip).unwrap().media;
    let new = h
        .apply(|tl| tl.replace_clip(clip, Media::solid(2)))
        .unwrap();
    assert_eq!(registered(h.timeline()), BTreeSet::from([new]));
    assert!(h.undo());
    assert_eq!(registered(h.timeline()), BTreeSet::from([old]));
}

#[test]
fn pruned_media_ids_are_never_reissued() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let pruned = h.timeline().clip(clip).unwrap().media;
    h.apply(|tl| tl.remove_clip(clip)).unwrap();
    let next = import(&mut h, 2);
    assert!(h.timeline().clip(next).unwrap().media.0 > pruned.0);
    // Back past the import and the delete, then a new edit: still a fresh id.
    assert!(h.undo());
    assert!(h.undo());
    let again = import(&mut h, 3);
    assert!(h.timeline().clip(again).unwrap().media.0 > pruned.0);
}

#[test]
fn a_failed_edit_keeps_the_registry() {
    let mut h = History::new(Timeline::default());
    import(&mut h, 1);
    let before = registered(h.timeline());
    assert!(h.apply(|tl| tl.remove_clip(ClipId(999))).is_err());
    assert_eq!(registered(h.timeline()), before);
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
    fn every_state_registers_exactly_the_media_its_clips_use(
        ops in proptest::collection::vec(op(), 0..40)
    ) {
        let mut h = History::new(Timeline::default());
        for op in ops {
            let current = clips(h.timeline());
            let pick = |i: usize| (!current.is_empty()).then(|| current[i % current.len()]);
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
            // Every snapshot finds its clips' media, and keeps none that no clip of it uses.
            for tl in h.timelines() {
                prop_assert_eq!(registered(tl), used(tl));
            }
        }
    }
}
