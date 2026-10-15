import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/proto/framix/v1/engine.pb.dart';
import 'media_importer.dart';

/// [MediaImporter] over the `framix/media` method channel (app/ios/Runner/MediaPicker.swift,
/// app/android/.../MediaPicker.kt). Missing fields stay at their defaults, so the engine
/// refuses them instead of Dart guessing.
class ChannelMediaImporter implements MediaImporter {
  const ChannelMediaImporter();

  static const _channel = MethodChannel('framix/media');

  @override
  Future<List<MediaItem>> pickFromGallery() => _pick('pickGallery');

  @override
  Future<List<MediaItem>> pickFromFiles() => _pick('pickFiles');

  Future<List<MediaItem>> _pick(String method) async {
    try {
      final picked =
          await _channel.invokeListMethod<Map<Object?, Object?>>(method) ??
          const [];
      return [for (final m in picked) ?_item(m)];
    } on PlatformException catch (e) {
      // The code only (busy, ...); never the file names.
      debugPrint('media pick failed: ${e.code}');
      return const [];
    }
  }

  /// The item, or null (logged, never with its uri) when a value can't be a proto field
  /// (e.g. a -1 size from an unreadable file); the engine checks everything else.
  static MediaItem? _item(Map<Object?, Object?> m) {
    try {
      return _fields(m);
    } on ArgumentError {
      debugPrint('media pick: skipped an item with an invalid value');
      return null;
    }
  }

  static MediaItem _fields(Map<Object?, Object?> m) => MediaItem(
    uri: m['uri'] as String? ?? '',
    kind: switch (m['kind']) {
      'video' => MediaKind.MEDIA_KIND_VIDEO,
      'image' => MediaKind.MEDIA_KIND_IMAGE,
      _ => MediaKind.MEDIA_KIND_UNSPECIFIED,
    },
    durationValue: Int64(m['durationValue'] as int? ?? 0),
    durationTimescale: m['durationTimescale'] as int? ?? 0,
    width: m['width'] as int? ?? 0,
    height: m['height'] as int? ?? 0,
    rotation: m['rotation'] as int? ?? 0,
    codec: m['codec'] as String? ?? '',
  );
}
