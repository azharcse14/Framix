# P1-024: multi-select clips (move, delete, copy together)

Proto change: three new commands, protocol 43 -> 44.

## Model (core, `Timeline`)
- `remove_clips(&[ClipId])`, `move_clips(&[ClipId], by: Time)`, `duplicate_clips(&[ClipId])
  -> Vec<ClipId>`. Each loops the one-clip op it extends, so the rules (locked track, overlap,
  negative start) stay in one place. Refused when the list is empty or names a clip twice.
- `move_clips` shifts every clip on its own track by `by` (no track change). Clips are moved
  in the shift's direction order (right: last first; left: first first), so a clip never
  collides with a selected clip's old spot.
- `duplicate_clips` copies the selection as a block right after it: each copy starts at
  `start + (selection end - selection start)` on its own track. Overlap with another clip
  is refused (no ripple, like `duplicate_clip`).
- The app runs each through `History::apply`: one undo step, all-or-nothing.

## Proto / engine (app)
- `RemoveClips { repeated uint64 clip_ids = 1; }` = 41, `MoveClips { repeated uint64
  clip_ids = 1; int64 by = 2; }` = 42, `DuplicateClips { repeated uint64 clip_ids = 1; }` = 43.
- Cap the list at the clip count it can name (a list longer than the timeline's clips is
  refused before work).

## UI (Dart)
- `ClipSelectionCubit` holds a set of ids plus a "select more" mode. Tap: select one (or
  toggle it in select-more mode). The clip actions row gets a "Select more" toggle.
- With 2+ selected the row shows Delete and Duplicate for the set (and a count);
  trim handles show only for a single selection. Long-press drag of a selected clip in a 2+
  selection sends MoveClips with the horizontal offset (tracks stay); otherwise SnapMove as
  today.

## Out of scope
- Moving a multi-selection to another track, and snapping it (follow-up if asked).
- Copy/paste at the playhead (clipboard); "copy" here is duplicate.
