import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';

/// Mirrors the engine's playhead in ticks. Sends Seek; the engine clamps it.
class PlayheadCubit extends Cubit<int> {
  PlayheadCubit(this._engine) : super(0);

  // ignore: unused_field, stub until P1-020 implements seek.
  final FramixEngine _engine;

  /// Asks the engine to move the playhead to [ticks].
  void seek(int ticks) {}
}
