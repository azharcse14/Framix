# 0002. Undo stores timeline snapshots, not inverse commands
Status: proposed
Date: 2026-10-15
Task: P1-023

## Context
docs/architecture.md gave `core` "undo commands": every edit would need a hand-written inverse. An inverse that misses one field silently corrupts the project after undo, and each new edit type adds another chance for that. A timeline is small (clip metadata, not media).

## Decision
- `app::history::History` owns the timeline. Every edit is one command, a closure run through `History::apply`.
- An undo step is the timeline as it was before the edit. Undo and redo swap snapshots; an edit that fails leaves no step and no change.
- `core` has no undo code; it only needs `Timeline: Clone + PartialEq`, where `==` compares content only.

## Consequences
- Undo cannot drift from the edit, and new edit types need no undo code.
- Memory grows with history length times timeline size. The cap is GOT-051; structural sharing (Arc'd tracks) comes in if timelines get large.
- The id counter lives inside the snapshot, so every swap raises it to the larger of the two (`Timeline::keep_ids_newer_than`, P1-043); ids are never reissued after undo or redo.
- Merging a drag gesture into one step is still to be done when drag commands arrive.
