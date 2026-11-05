import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';

/// Whether the engine is playing (P1-061). The engine owns playback; this mirrors it.
class PlaybackCubit extends Cubit<bool> {
  PlaybackCubit(this._engine) : super(false);

  // ignore: unused_field
  final FramixEngine _engine;

  /// Asks the engine to play from the playhead.
  void play() {}

  /// Asks the engine to stop where it is.
  void pause() {}
}
