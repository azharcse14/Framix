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
        .listen((e) => emit(e.timelineChanged..freeze()));
  }

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;

  void addTrack(TrackKind kind) =>
      _engine.send(Command(addTrack: AddTrack(kind: kind)));

  void undo() => _engine.send(Command(undo: Undo()));

  void redo() => _engine.send(Command(redo: Redo()));

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
