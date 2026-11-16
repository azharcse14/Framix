//! GOT-051: the undo history keeps at most `History::MAX_UNDO_STEPS` steps; the oldest go first
//! and media only they used leaves the registry (ENG-055).

use std::collections::BTreeSet;

use framix_app::history::History;
use framix_core::aspect::AspectRatio;
use framix_core::media::Media;
use framix_core::timeline::{ClipId, MediaId, Timeline, TimelineError, TrackKind};
use proptest::prelude::*;

const MAX: usize = History::MAX_UNDO_STEPS;

fn add_track(h: &mut History) {
    h.apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Video)))
        .unwrap();
}

fn import(h: &mut History, color: u32) -> ClipId {
    h.apply(|tl| tl.import(vec![Media::solid(color)])).unwrap()[0]
}

fn undo_all(h: &mut History) -> usize {
    let mut n = 0;
    while h.undo() {
        n += 1;
    }
    n
}

/// Undo steps and redo steps (the current state is not one).
fn steps(h: &History) -> usize {
    h.timelines().count() - 1
}

#[test]
fn edits_past_the_cap_drop_the_oldest_steps() {
    let mut h = History::new(Timeline::default());
    for _ in 0..MAX + 5 {
        add_track(&mut h);
    }
    assert_eq!(steps(&h), MAX);
    assert_eq!(undo_all(&mut h), MAX);
    // The oldest kept state is the one after the first 5 edits.
    assert_eq!(h.timeline().tracks().len(), 5);
    assert_eq!(steps(&h), MAX);
    let mut redone = 0;
    while h.redo() {
        redone += 1;
    }
    assert_eq!(redone, MAX);
    assert_eq!(h.timeline().tracks().len(), MAX + 5);
}

#[test]
fn media_only_dropped_steps_used_leaves_every_state() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let media = h.timeline().clip(clip).unwrap().media;
    h.apply(|tl| tl.remove_clip(clip)).unwrap();
    for _ in 0..MAX {
        add_track(&mut h);
    }
    for tl in h.timelines() {
        assert_eq!(tl.media(media), None);
    }
}

#[test]
fn media_a_kept_step_uses_stays() {
    let mut h = History::new(Timeline::default());
    let clip = import(&mut h, 1);
    let media = h.timeline().clip(clip).unwrap().media;
    for _ in 0..MAX {
        add_track(&mut h);
    }
    h.apply(|tl| tl.remove_clip(clip)).unwrap();
    undo_all(&mut h);
    assert_eq!(h.timeline().clip(clip).unwrap().media, media);
    assert!(h.timeline().media(media).is_some());
}

#[test]
fn a_gesture_at_the_cap_stays_one_step() {
    let mut h = History::new(Timeline::default());
    for _ in 0..MAX {
        add_track(&mut h);
    }
    for (w, ht) in [(1, 1), (4, 5), (16, 9)] {
        let aspect = AspectRatio::new(w, ht).unwrap();
        h.apply_merged(7, |tl| {
            tl.set_aspect(aspect);
            Ok::<_, ()>(())
        })
        .unwrap();
    }
    assert_eq!(steps(&h), MAX);
    let before = h.timeline().aspect();
    assert!(h.undo());
    assert_ne!(h.timeline().aspect(), before);
    assert_eq!(h.timeline().tracks().len(), MAX);
}

#[test]
fn undoing_a_gesture_at_the_cap_restores_the_state_before_it() {
    let mut h = History::new(Timeline::default());
    for _ in 0..MAX {
        add_track(&mut h);
    }
    let start = h.timeline().aspect();
    for (w, ht) in [(1, 1), (4, 5), (16, 9)] {
        let aspect = AspectRatio::new(w, ht).unwrap();
        h.apply_merged(7, |tl| {
            tl.set_aspect(aspect);
            Ok::<_, ()>(())
        })
        .unwrap();
    }
    assert!(h.undo());
    assert_eq!(h.timeline().aspect(), start);
    assert_eq!(h.timeline().tracks().len(), MAX);
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
        4 => (0u32..8).prop_map(Op::Import),
        3 => (0usize..8).prop_map(Op::Delete),
        3 => (0usize..8, 0u32..8).prop_map(|(i, c)| Op::Replace(i, c)),
        1 => Just(Op::Undo),
        1 => Just(Op::Redo),
    ]
}

/// What a state looks like: its clips and the media each one uses.
fn fingerprint(tl: &Timeline) -> Vec<(ClipId, MediaId)> {
    tl.tracks()
        .iter()
        .flat_map(|t| t.clips())
        .map(|c| (c.id, c.media))
        .collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(24))]
    #[test]
    fn history_stays_capped_and_consistent(
        ops in proptest::collection::vec(op(), MAX..MAX * 2)
    ) {
        let mut h = History::new(Timeline::default());
        // Reference model: fingerprints of the undo and redo states.
        let mut past: Vec<Vec<(ClipId, MediaId)>> = Vec::new();
        let mut future: Vec<Vec<(ClipId, MediaId)>> = Vec::new();
        for op in ops {
            let before = fingerprint(h.timeline());
            let clips: Vec<ClipId> = before.iter().map(|&(c, _)| c).collect();
            let pick = |i: usize| (!clips.is_empty()).then(|| clips[i % clips.len()]);
            let edited = match op {
                Op::Import(c) => {
                    import(&mut h, c);
                    true
                }
                Op::Delete(i) => pick(i)
                    .map(|clip| h.apply(|tl| tl.remove_clip(clip)).unwrap())
                    .is_some(),
                Op::Replace(i, c) => pick(i)
                    .map(|clip| h.apply(|tl| tl.replace_clip(clip, Media::solid(c))).unwrap())
                    .is_some(),
                Op::Undo => {
                    let moved = h.undo();
                    prop_assert_eq!(moved, !past.is_empty());
                    if let Some(state) = past.pop() {
                        future.push(before.clone());
                        prop_assert_eq!(fingerprint(h.timeline()), state);
                    }
                    false
                }
                Op::Redo => {
                    let moved = h.redo();
                    prop_assert_eq!(moved, !future.is_empty());
                    if let Some(state) = future.pop() {
                        past.push(before.clone());
                        prop_assert_eq!(fingerprint(h.timeline()), state);
                    }
                    false
                }
            };
            if edited {
                past.push(before);
                if past.len() > MAX {
                    past.remove(0);
                }
                future.clear();
            }
            prop_assert!(steps(&h) <= MAX);
            prop_assert_eq!(h.can_undo(), !past.is_empty());
            prop_assert_eq!(h.can_redo(), !future.is_empty());
            for tl in h.timelines() {
                let used: BTreeSet<MediaId> = tl.used_media().collect();
                for media in used {
                    prop_assert!(tl.media(media).is_some());
                }
            }
        }
        // Undo stops at the oldest kept state, and redo brings everything back.
        let current = fingerprint(h.timeline());
        let oldest = past.first().cloned().unwrap_or_else(|| current.clone());
        let newest = future.first().cloned().unwrap_or(current);
        prop_assert_eq!(undo_all(&mut h), past.len());
        prop_assert_eq!(fingerprint(h.timeline()), oldest);
        while h.redo() {}
        prop_assert_eq!(fingerprint(h.timeline()), newest);
    }
}
