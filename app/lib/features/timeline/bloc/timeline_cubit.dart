import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's timeline. Holds the latest [TimelineChanged]; sends commands only.
class TimelineCubit extends Cubit<TimelineChanged> {
  TimelineCubit(this._engine) : super(TimelineChanged()..freeze()) {
    // CommandFailed has no UI yet (import can fail: too many items, bad metadata); a
    // generic failure message is filed as its own task.
    _events = _engine.events
        .where((e) => e.hasTimelineChanged() || e.hasPlayheadChanged())
        .map(
          (e) => e.hasTimelineChanged()
              ? (e.timelineChanged..freeze())
              // The playhead moved: only the active clip changes.
              : (state.rebuild(
                  (t) => t.activeClip = e.playheadChanged.activeClip,
                )..freeze()),
        )
        // Cubit always lets the first emit through, even if equal; skip no-op replies.
        .where((t) => t != state)
        .listen(emit);
    // The engine may already hold edits; ask for them instead of trusting the empty start.
    _engine.send(Command(getTimeline: GetTimeline()));
  }

  final FramixEngine _engine;
  late final StreamSubscription<TimelineChanged> _events;

  void addTrack(TrackKind kind) =>
      _engine.send(Command(addTrack: AddTrack(kind: kind)));

  void setAspectRatio(int width, int height) => _engine.send(
    Command(
      setAspectRatio: SetAspectRatio(width: width, height: height),
    ),
  );

  /// Changes only the given switches; the engine keeps the rest and validates the result
  /// (e.g. audio can't hide), so quick taps on different switches don't undo each other.
  void setTrackFlags(Track track, {bool? muted, bool? hidden, bool? locked}) =>
      _engine.send(
        Command(
          setTrackFlags: SetTrackFlags(
            trackId: track.id,
            muted: muted,
            hidden: hidden,
            locked: locked,
          ),
        ),
      );

  /// Waits for [pick] and sends what came back; a cancelled pick sends nothing.
  Future<void> importMedia(Future<List<MediaItem>> Function() pick) async {
    final items = await pick();
    if (items.isEmpty || isClosed) return;
    _engine.send(Command(importMedia: ImportMedia(items: items)));
  }

  /// Moves and scales [clip] on the canvas (x/y in 1/10000 of the canvas, scale in 1/1000 of
  /// fit), keeping its crop, turns and flips. Edits with the same [gesture] are one undo step.
  void placeClip(
    Clip clip, {
    required int x,
    required int y,
    required int scale,
    required int gesture,
  }) {
    final scheduled = _placing != null;
    _placing = SetClipTransform(
      clipId: clip.id,
      rotation: clip.rotation,
      flipH: clip.flipH,
      flipV: clip.flipV,
      cropLeft: clip.cropLeft,
      cropTop: clip.cropTop,
      cropRight: clip.cropRight,
      cropBottom: clip.cropBottom,
      x: x,
      y: y,
      scale: scale,
      gesture: Int64(gesture),
    );
    // One send per event-loop turn of gesture updates, always the latest.
    if (!scheduled) scheduleMicrotask(_sendPlacing);
  }

  SetClipTransform? _placing;

  void _sendPlacing() {
    final placing = _placing;
    _placing = null;
    if (placing != null && !isClosed) {
      _engine.send(Command(setClipTransform: placing));
    }
  }

  void undo() => _engine.send(Command(undo: Undo()));

  void redo() => _engine.send(Command(redo: Redo()));

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
