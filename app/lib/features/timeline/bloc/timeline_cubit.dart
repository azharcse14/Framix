import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's timeline. Holds the latest [TimelineChanged]; sends commands only.
class TimelineCubit extends Cubit<TimelineChanged> {
  TimelineCubit(this._engine) : super(TimelineChanged()..freeze()) {
    // A refused command (import: too many items, bad metadata) shows the generic message
    // from CommandFailureMessages.
    _events = _engine.events
        // A playhead event only matters when it changes the active clip.
        .where(
          (e) =>
              e.hasTimelineChanged() ||
              (e.hasPlayheadChanged() &&
                  e.playheadChanged.activeClip != state.activeClip),
        )
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
  int _gestures = 0;

  /// A fresh gesture id: edits sent with it are one undo step.
  int nextGesture() => ++_gestures;

  void _sendPlacing() {
    final placing = _placing;
    _placing = null;
    if (placing != null && !isClosed) {
      _engine.send(Command(setClipTransform: placing));
    }
  }

  /// Splits [clip] at timeline time [at]; the engine refuses a time outside it.
  void splitClip(Clip clip, int at) => _engine.send(
    Command(
      splitClip: SplitClip(clipId: clip.id, at: Int64(at)),
    ),
  );

  /// Moves [clip]'s edges to [start, end) in timeline ticks; the engine checks the result.
  void trimClip(Clip clip, int start, int end) => _engine.send(
    Command(
      trimClip: TrimClip(clipId: clip.id, start: Int64(start), end: Int64(end)),
    ),
  );

  /// Waits for [pick] and puts its first item under [clip]; a cancelled pick sends nothing.
  Future<void> replaceClip(
    Clip clip,
    Future<List<MediaItem>> Function() pick,
  ) async {
    final items = await pick();
    if (items.isEmpty || isClosed) return;
    _engine.send(
      Command(
        replaceClip: ReplaceClip(clipId: clip.id, media: items.first),
      ),
    );
  }

  /// Moves [clip] to [start] ticks on track [trackId]; the engine refuses a taken spot, a
  /// locked track or another kind of track.
  void moveClip(Clip clip, Int64 trackId, int start) => _engine.send(
    Command(
      moveClip: MoveClip(
        clipId: clip.id,
        trackId: trackId,
        start: Int64(start),
      ),
    ),
  );

  void removeClip(Clip clip) =>
      _engine.send(Command(removeClip: RemoveClip(clipId: clip.id)));

  /// Copies [clip] to right after itself; the engine refuses it if that space is taken.
  void duplicateClip(Clip clip) =>
      _engine.send(Command(duplicateClip: DuplicateClip(clipId: clip.id)));

  /// Joins [right] into [left]; the engine checks they can be joined.
  void mergeClips(Clip left, Clip right) => _engine.send(
    Command(
      mergeClips: MergeClips(leftId: left.id, rightId: right.id),
    ),
  );

  void undo() => _engine.send(Command(undo: Undo()));

  void redo() => _engine.send(Command(redo: Redo()));

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
