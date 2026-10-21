import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Thumbnail files the engine reported, by (media id, snapped time, max side).
typedef ThumbnailKey = ({int media, int time, int maxSide});

/// Mirrors ThumbnailReady events; asks the engine for missing thumbnails. The engine snaps,
/// dedups and schedules; this only avoids sending the same ask twice.
class ThumbnailCubit extends Cubit<Map<ThumbnailKey, String>> {
  ThumbnailCubit(this._engine) : super(const {}) {
    _events = _engine.events.where((e) => e.hasThumbnailReady()).listen((e) {
      final r = e.thumbnailReady;
      final key = (
        media: r.mediaId.toInt(),
        time: r.time.toInt(),
        maxSide: r.maxSide,
      );
      emit({...state, key: r.path});
    });
  }

  /// Most times in one RequestThumbnails (the engine's limit).
  static const _perCommand = 64;

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;
  final _asked = <ThumbnailKey>{};

  /// Waiting to go out, per (media, max side); sent together at the end of this turn.
  final _batch = <({int media, int maxSide}), List<int>>{};

  /// Asks for thumbnails of [media] at the snapped [times], each side at most [maxSide].
  void request(int media, List<int> times, int maxSide) {
    final fresh = times
        .where((t) => _asked.add((media: media, time: t, maxSide: maxSide)))
        .toList();
    if (fresh.isEmpty) return;
    final scheduled = _batch.isNotEmpty;
    _batch
        .putIfAbsent((media: media, maxSide: maxSide), () => [])
        .addAll(fresh);
    if (!scheduled) scheduleMicrotask(_send);
  }

  void _send() {
    final batch = Map.of(_batch);
    _batch.clear();
    if (isClosed) return;
    for (final MapEntry(key: target, value: times) in batch.entries) {
      for (var i = 0; i < times.length; i += _perCommand) {
        final chunk = times.sublist(
          i,
          (i + _perCommand).clamp(0, times.length),
        );
        _engine.send(
          Command(
            requestThumbnails: RequestThumbnails(
              mediaId: Int64(target.media),
              times: chunk.map(Int64.new),
              maxSide: target.maxSide,
            ),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
