//! Undo/redo for timeline edits.

use std::collections::BTreeSet;

use framix_core::timeline::{MediaId, Timeline};

/// Owns the timeline; every edit goes through [`History::apply`] so it can be undone.
///
/// Each step stores the timeline as it was before the step (a snapshot), so undo can't
/// drift the way a hand-written inverse can.
// ponytail: full snapshots capped by count (GOT-051); a byte budget or structural sharing
// (Arc'd tracks) comes in if timelines get large.
#[derive(Clone, Debug, Default)]
pub struct History {
    current: Timeline,
    undo: Vec<Timeline>,
    redo: Vec<Timeline>,
    /// Gesture key of the last undo step, while edits may still merge into it.
    merging: Option<u64>,
}

impl History {
    /// The most undo steps kept; past it the oldest go first (GOT-051).
    pub const MAX_UNDO_STEPS: usize = 100;

    /// Starts a history at `timeline` with nothing to undo.
    pub fn new(timeline: Timeline) -> Self {
        Self {
            current: timeline,
            undo: Vec::new(),
            redo: Vec::new(),
            merging: None,
        }
    }

    /// The current timeline.
    pub fn timeline(&self) -> &Timeline {
        &self.current
    }

    /// Runs `edit` as one undoable step; an edit that changes nothing adds no step and keeps
    /// redo. On `Err` the timeline and history are unchanged, even if `edit` mutated before
    /// failing.
    pub fn apply<T, E>(
        &mut self,
        edit: impl FnOnce(&mut Timeline) -> Result<T, E>,
    ) -> Result<T, E> {
        self.apply_step(edit).map(|(value, _)| value)
    }

    /// [`History::apply`], also telling whether the edit made a step.
    fn apply_step<T, E>(
        &mut self,
        edit: impl FnOnce(&mut Timeline) -> Result<T, E>,
    ) -> Result<(T, bool), E> {
        self.merging = None;
        let mut next = self.current.clone();
        let value = edit(&mut next)?;
        // An edit that changed nothing (same trim, same ratio) is not a step: keep redo.
        if next == self.current {
            // Content is equal, but ids it handed out must still never be reissued.
            self.current.keep_ids_newer_than(&next);
            return Ok((value, false));
        }
        self.undo.push(std::mem::replace(&mut self.current, next));
        // Redo only fills from undo, so capping undo here caps the whole history.
        let over = self.undo.len().saturating_sub(Self::MAX_UNDO_STEPS);
        if over > 0 || !self.redo.is_empty() {
            self.undo.drain(..over);
            self.redo.clear();
            self.forget_unused_media();
        }
        Ok((value, true))
    }

    /// Like [`History::apply`], but consecutive calls with the same `key` make one undo step
    /// (one gesture); any other apply, undo or redo ends the run.
    pub fn apply_merged<T, E>(
        &mut self,
        key: u64,
        edit: impl FnOnce(&mut Timeline) -> Result<T, E>,
    ) -> Result<T, E> {
        if self.merging != Some(key) {
            let (value, stepped) = self.apply_step(edit)?;
            // Only a step this gesture made may take later edits (undo length can't tell: the
            // cap may have dropped the oldest step).
            if stepped {
                self.merging = Some(key);
            }
            return Ok(value);
        }
        // Part of the same gesture: change the current state, keep the gesture's one step.
        let mut next = self.current.clone();
        let value = edit(&mut next)?;
        // Ids only go forward.
        next.keep_ids_newer_than(&self.current);
        self.current = next;
        Ok(value)
    }

    /// Whether [`History::undo`] would do anything.
    pub fn can_undo(&self) -> bool {
        !self.undo.is_empty()
    }

    /// The current timeline, then every undo and redo snapshot.
    pub fn timelines(&self) -> impl Iterator<Item = &Timeline> {
        std::iter::once(&self.current)
            .chain(&self.undo)
            .chain(&self.redo)
    }

    /// Whether [`History::redo`] would do anything.
    pub fn can_redo(&self) -> bool {
        !self.redo.is_empty()
    }

    /// Reverts the last applied step. Returns `false` when there is nothing to undo.
    pub fn undo(&mut self) -> bool {
        self.merging = None;
        Self::step(&mut self.current, &mut self.undo, &mut self.redo)
    }

    /// Re-applies the last undone step. Returns `false` when there is nothing to redo.
    pub fn redo(&mut self) -> bool {
        self.merging = None;
        Self::step(&mut self.current, &mut self.redo, &mut self.undo)
    }

    /// Unregisters, from every state left, the media no clip of any state left uses (ENG-055).
    /// Call it whenever states leave the history. Each state's clips keep their media, so undo
    /// and redo still find it; ids only go forward, so a forgotten id is never reissued.
    // ponytail: scans every snapshot, on every edit once the cap is full; fine for metadata
    // snapshots, track media use per state if large timelines make edits slow.
    fn forget_unused_media(&mut self) {
        let used: BTreeSet<MediaId> = self.timelines().flat_map(Timeline::used_media).collect();
        for timeline in std::iter::once(&mut self.current)
            .chain(&mut self.undo)
            .chain(&mut self.redo)
        {
            timeline.forget_media_except(&used);
        }
    }

    /// Moves `current` onto `to` and pops `from` into `current`.
    fn step(current: &mut Timeline, from: &mut Vec<Timeline>, to: &mut Vec<Timeline>) -> bool {
        let Some(previous) = from.pop() else {
            return false;
        };
        let replaced = std::mem::replace(current, previous);
        // Ids only go forward, even when the content goes back (P1-043).
        current.keep_ids_newer_than(&replaced);
        to.push(replaced);
        true
    }
}
