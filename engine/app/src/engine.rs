//! Turns UI commands into timeline edits and reports the result as an event.

use crate::history::History;
use crate::proto::{Command, Event};

/// Engine state behind the FFI boundary: one project's timeline and its undo history.
#[derive(Debug, Default)]
pub struct Engine {
    history: History,
}

impl Engine {
    /// Applies `command` and returns the single event describing the outcome.
    pub fn handle(&mut self, command: Command) -> Event {
        let _ = (command, &mut self.history);
        Event::default()
    }
}
