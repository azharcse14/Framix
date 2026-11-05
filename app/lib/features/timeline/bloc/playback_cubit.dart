import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Whether the engine is playing (P1-061). The engine owns playback; this mirrors it.
class PlaybackCubit extends Cubit<bool> {
  PlaybackCubit(this._engine) : super(false) {
    _events = _engine.events.listen((e) {
      if (e.hasPlayheadChanged()) {
        emit(e.playheadChanged.playing);
      } else if (e.hasTimelineChanged()) {
        emit(e.timelineChanged.playing);
      }
    });
  }

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;

  /// Asks the engine to play from the playhead.
  void play() => _engine.send(Command(play: Play()));

  /// Asks the engine to stop where it is.
  void pause() => _engine.send(Command(pause: Pause()));

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
