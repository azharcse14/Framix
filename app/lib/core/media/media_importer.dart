import '../engine/proto/framix/v1/engine.pb.dart';

/// Picks media through the platform and returns engine-ready items: an opaque reference plus
/// the platform's metadata. The engine validates everything; an empty list means cancelled.
abstract interface class MediaImporter {
  /// Photos and videos from the gallery, in pick order.
  Future<List<MediaItem>> pickFromGallery();

  /// Photos and videos from Files (iCloud Drive, Google Drive, local storage).
  Future<List<MediaItem>> pickFromFiles();
}
