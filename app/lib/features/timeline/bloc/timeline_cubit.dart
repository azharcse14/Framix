import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's timeline. Holds the latest [TimelineChanged]; sends commands only.
class TimelineCubit extends Cubit<TimelineChanged> {
  TimelineCubit(this._engine) : super(TimelineChanged()..freeze()) {
    // CommandFailed needs no UI yet: buttons are enabled from can_undo/can_redo, and
    // add-track cannot fail. Failure messages arrive with a code enum later.
    _events = _engine.events
        .where((e) => e.hasTimelineChanged())
        .map((e) => e.timelineChanged..freeze())
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

  /// Sends the track's full switch set; the engine validates it (e.g. audio can't hide).
  void setTrackFlags(Track track, {bool? muted, bool? hidden, bool? locked}) =>
      _engine.send(
        Command(
          setTrackFlags: SetTrackFlags(
            trackId: track.id,
            muted: muted ?? track.muted,
            hidden: hidden ?? track.hidden,
            locked: locked ?? track.locked,
          ),
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
