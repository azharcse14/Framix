import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';

/// Thumbnail files the engine reported, by (media id, snapped time, max side).
typedef ThumbnailKey = ({int media, int time, int maxSide});

/// Mirrors ThumbnailReady events; asks the engine for missing thumbnails.
class ThumbnailCubit extends Cubit<Map<ThumbnailKey, String>> {
  ThumbnailCubit(this._engine) : super(const {});

  // ignore: unused_field, stub until P1-021 sends requests.
  final FramixEngine _engine;

  /// Asks for thumbnails of [media] at the snapped [times], each side at most [maxSide].
  void request(int media, List<int> times, int maxSide) {}
}
