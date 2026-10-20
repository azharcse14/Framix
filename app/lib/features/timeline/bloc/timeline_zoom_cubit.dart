import 'package:flutter_bloc/flutter_bloc.dart';

/// Timeline zoom in pixels per second: view state only, never sent to the engine.
class TimelineZoomCubit extends Cubit<double> {
  TimelineZoomCubit() : super(initial);

  /// Pixels per second on a fresh timeline.
  static const initial = 100.0;

  void zoomIn() {}

  void zoomOut() {}
}
