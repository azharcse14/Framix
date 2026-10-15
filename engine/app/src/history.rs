//! Undo/redo for timeline edits.

use framix_core::timeline::Timeline;

/// Owns the timeline; every edit goes through [`History::apply`] so it can be undone.
///
/// Each step stores the timeline as it was before the step (a snapshot), so undo can't
/// drift the way a hand-written inverse can.
// ponytail: unbounded full snapshots; the memory cap is GOT-051, and structural sharing
// (Arc'd tracks) comes in if timelines get large.
#[derive(Clone, Debug, Default)]
pub struct History {
    current: Timeline,
    undo: Vec<Timeline>,
    redo: Vec<Timeline>,
}

impl History {
    /// Starts a history at `timeline` with nothing to undo.
    pub fn new(timeline: Timeline) -> Self {
        Self {
            current: timeline,
            undo: Vec::new(),
            redo: Vec::new(),
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
        let mut next = self.current.clone();
        let value = edit(&mut next)?;
        // An edit that changed nothing (same trim, same ratio) is not a step: keep redo.
        if next == self.current {
            // Content is equal, but ids it handed out must still never be reissued.
            self.current.keep_ids_newer_than(&next);
            return Ok(value);
        }
        self.undo.push(std::mem::replace(&mut self.current, next));
        self.redo.clear();
        Ok(value)
    }

    /// Whether [`History::undo`] would do anything.
    pub fn can_undo(&self) -> bool {
        !self.undo.is_empty()
    }

    /// Whether [`History::redo`] would do anything.
    pub fn can_redo(&self) -> bool {
        !self.redo.is_empty()
    }

    /// Reverts the last applied step. Returns `false` when there is nothing to undo.
    pub fn undo(&mut self) -> bool {
        Self::step(&mut self.current, &mut self.undo, &mut self.redo)
    }

    /// Re-applies the last undone step. Returns `false` when there is nothing to redo.
    pub fn redo(&mut self) -> bool {
        Self::step(&mut self.current, &mut self.redo, &mut self.undo)
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
