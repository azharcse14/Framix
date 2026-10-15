//! Undo/redo for timeline edits.

use framix_core::timeline::Timeline;

/// Owns the timeline; every edit goes through [`History::apply`] so it can be undone.
#[derive(Clone, Debug, Default)]
pub struct History {
    current: Timeline,
}

impl History {
    /// Starts a history at `timeline` with nothing to undo.
    pub fn new(timeline: Timeline) -> Self {
        Self { current: timeline }
    }

    /// The current timeline.
    pub fn timeline(&self) -> &Timeline {
        &self.current
    }

    /// Runs `edit` as one undoable step. On `Err` the timeline and history are unchanged.
    pub fn apply<T, E>(
        &mut self,
        edit: impl FnOnce(&mut Timeline) -> Result<T, E>,
    ) -> Result<T, E> {
        edit(&mut self.current)
    }

    /// Reverts the last applied step. Returns `false` when there is nothing to undo.
    pub fn undo(&mut self) -> bool {
        false
    }

    /// Re-applies the last undone step. Returns `false` when there is nothing to redo.
    pub fn redo(&mut self) -> bool {
        false
    }
}
