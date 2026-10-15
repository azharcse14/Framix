import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's timeline. Holds the latest [TimelineChanged]; sends commands only.
class TimelineCubit extends Cubit<TimelineChanged> {
  TimelineCubit(FramixEngine engine) : super(TimelineChanged());

  void addTrack(TrackKind kind) {}

  void undo() {}

  void redo() {}
}
