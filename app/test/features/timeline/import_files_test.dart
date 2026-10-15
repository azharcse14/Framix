import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'timeline_page_test.dart' show pumpUntil;

class _FilesOnly implements MediaImporter {
  @override
  Future<List<MediaItem>> pickFromGallery() async => const [];

  @override
  Future<List<MediaItem>> pickFromFiles() async => [
    MediaItem(
      uri: 'media/f.mov',
      kind: MediaKind.MEDIA_KIND_VIDEO,
      durationValue: Int64(1000),
      durationTimescale: 1000,
      width: 640,
      height: 480,
    ),
  ];
}

void main() {
  testWidgets('the Files button imports through the engine', (tester) async {
    final engine = FramixEngine.create();
    addTearDown(engine.dispose);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: _FilesOnly(),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromFiles));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
  });
}
