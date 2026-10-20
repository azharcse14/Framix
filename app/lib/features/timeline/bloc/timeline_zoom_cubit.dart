import 'package:flutter_bloc/flutter_bloc.dart';

/// Timeline zoom in pixels per second: view state only, never sent to the engine.
class TimelineZoomCubit extends Cubit<double> {
  TimelineZoomCubit() : super(initial);

  /// Pixels per second on a fresh timeline.
  static const initial = 100.0;
  static const _min = 20.0;
  static const _max = 2000.0;
  static const _step = 1.5;

  void zoomIn() => emit((state * _step).clamp(_min, _max));

  void zoomOut() => emit((state / _step).clamp(_min, _max));
}
