import '../engine/proto/framix/v1/engine.pb.dart';
import 'media_importer.dart';

/// [MediaImporter] over the `framix/media` method channel (app/ios/Runner/MediaPicker.swift,
/// app/android/.../MediaPicker.kt).
class ChannelMediaImporter implements MediaImporter {
  const ChannelMediaImporter();

  @override
  Future<List<MediaItem>> pickFromGallery() async => const [];

  @override
  Future<List<MediaItem>> pickFromFiles() async => const [];
}
