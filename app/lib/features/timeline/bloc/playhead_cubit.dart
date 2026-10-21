import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's playhead in ticks. Sends Seek; the engine clamps it and owns the value.
class PlayheadCubit extends Cubit<int> {
  PlayheadCubit(this._engine) : super(0) {
    _events = _engine.events.listen((e) {
      if (e.hasPlayheadChanged()) {
        final snapped = e.playheadChanged.snapped;
        // One tick when a snap begins, not again while it stays on the same point.
        if (snapped && !(_snapped && e.playheadChanged.time.toInt() == state)) {
          HapticFeedback.selectionClick();
        }
        _snapped = snapped;
        emit(e.playheadChanged.time.toInt());
      } else if (e.hasTimelineChanged()) {
        emit(e.timelineChanged.playhead.toInt());
      }
    });
  }

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;
  int? _wanted;
  int _snapWithin = 0;
  bool _snapped = false;

  /// Asks the engine to move the playhead to [ticks]. Seeks made in the same event-loop turn
  /// (one batch of drag updates) become one Seek to the last position.
  void seek(int ticks, {int snapWithin = 0}) {
    final scheduled = _wanted != null;
    _wanted = ticks;
    _snapWithin = snapWithin;
    if (!scheduled) scheduleMicrotask(_send);
  }

  void _send() {
    final ticks = _wanted;
    _wanted = null;
    if (ticks == null || isClosed) return;
    _engine.send(
      Command(
        seek: Seek(time: Int64(ticks), snapWithin: Int64(_snapWithin)),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
