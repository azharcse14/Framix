// SPIKE (P1-034): with --dart-define=FRAMIX_SPIKE_EXPORT=true, adds a photo to an empty
// project, exports it once to the app's temp folder, and logs the result. Proves the
// encoder path before the export screen (P1-064) exists. Off in every normal build.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'framix_engine.dart';
import 'proto/framix/v1/engine.pb.dart';

const _enabled = bool.fromEnvironment('FRAMIX_SPIKE_EXPORT');

/// Starts the spike if the build asked for it.
void startSpikeExport(FramixEngine engine) {
  if (!_enabled) return;
  late final StreamSubscription<Event> events;
  var sent = false;
  var imported = false;
  final path = '${Directory.systemTemp.path}/framix_export.mp4';
  events = engine.events.listen((event) {
    final hasClip =
        event.hasTimelineChanged() &&
        event.timelineChanged.tracks.any((t) => t.clips.isNotEmpty);
    // An empty project gets one photo item (no file needed: the renderer draws the test
    // pattern until the Decoder port exists).
    if (!imported && event.hasTimelineChanged() && !hasClip) {
      imported = true;
      engine.send(
        Command(
          importMedia: ImportMedia(
            items: [
              MediaItem(
                uri: 'media/spike.png',
                kind: MediaKind.MEDIA_KIND_IMAGE,
                width: 1080,
                height: 1920,
              ),
            ],
          ),
        ),
      );
    }
    if (!sent && hasClip) {
      sent = true;
      debugPrint('framix spike export: start');
      engine.send(Command(exportProject: ExportProject(path: path)));
    }
    if (event.hasExportFinished()) {
      final f = event.exportFinished;
      debugPrint('framix spike export: ok=${f.ok} ${f.reason} -> $path');
      unawaited(events.cancel());
    }
  });
}
